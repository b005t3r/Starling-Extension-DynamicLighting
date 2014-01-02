/**
 * User: booster
 * Date: 11/12/13
 * Time: 15:24
 */
package starling.shaders {
import com.barliesque.agal.EasierAGAL;
import com.barliesque.agal.IComponent;
import com.barliesque.agal.IRegister;
import com.barliesque.agal.TextureFlag;
import com.barliesque.shaders.macro.Utils;

import flash.display3D.Context3D;
import flash.display3D.Context3DProgramType;

import starling.shaders.ITextureShader;

import starling.shaders.LightingShaderUtil;

public class RayGeneratorShader extends EasierAGAL implements ITextureShader {
    private var _constants:Vector.<Number>  = new <Number>[0.0, 0.5, 1.0, 2.0];
    private var _uv:Vector.<Number>      = new <Number>[0.0, 0.0, 0.0, 0.0];

    public function get minU():Number { return _uv[0]; }
    public function set minU(value:Number):void { _uv[0] = value; }

    public function get maxU():Number { return _uv[1]; }
    public function set maxU(value:Number):void { _uv[1] = value; }

    public function get minV():Number { return _uv[2]; }
    public function set minV(value:Number):void { _uv[2] = value; }

    public function get maxV():Number { return _uv[3]; }
    public function set maxV(value:Number):void { _uv[3] = value; }

    public function activate(context:Context3D):void {
        context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _constants);
        context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, _uv);
    }

    public function deactivate(context:Context3D):void { }

    override protected function _vertexShader():void {
        comment("Apply a 4x4 matrix to transform vertices to clip-space");
        multiply4x4(OUTPUT, ATTRIBUTE[0], CONST[0]);

        comment("Pass uv coordinates to fragment shader");
        move(VARYING[0], ATTRIBUTE[1]);
    }

    override protected function _fragmentShader():void {
        move(TEMP[0], VARYING[0]);

        ShaderUtil.uvToCartesian(TEMP[0].x, TEMP[0].y, CONST[1].x, CONST[1].y, CONST[1].z, CONST[1].w, TEMP[3].x, CONST[0].z, CONST[0].w);

        comment("[x,y] <- cartesian coords, [z,w] <- abs(x,y)");
        abs(TEMP[0].z, TEMP[0].x);
        abs(TEMP[0].w, TEMP[0].y);

        comment("v = v * abs(u); // as u approaches 0 (the center), v should also approach 0 (in " + TEMP[0].z + ")");
        multiply(TEMP[0].y, TEMP[0].y, TEMP[0].z);

        move(TEMP[1], TEMP[0]);
        move(TEMP[3], TEMP[0]);
        ShaderUtil.cartesianToUV(TEMP[1].x, TEMP[1].y, CONST[1].x, CONST[1].y, CONST[1].z, CONST[1].w, TEMP[0].w, CONST[0].z, CONST[0].w);

        move(TEMP[2], TEMP[0]);
        move(TEMP[4], TEMP[0]);
        ShaderUtil.cartesianToUV(TEMP[2].y, TEMP[2].x, CONST[1].x, CONST[1].y, CONST[1].z, CONST[1].w, TEMP[0].w, CONST[0].z, CONST[0].w);

        comment("Use UV coordinates passed from vertex shader to sample the texture");
        sampleTexture(TEMP[1], TEMP[1], SAMPLER[0], [TextureFlag.TYPE_2D, TextureFlag.MODE_CLAMP, TextureFlag.FILTER_NEAREST, TextureFlag.MIP_NO]);
        sampleTexture(TEMP[2], TEMP[2]._("yx"), SAMPLER[0], [TextureFlag.TYPE_2D, TextureFlag.MODE_CLAMP, TextureFlag.FILTER_NEAREST, TextureFlag.MIP_NO]);

        comment("r = sampleOneAlpha, g = sampleTwoAlpha, b = 1, a = 1");
        move(TEMP[0].r, TEMP[1].a);
        move(TEMP[0].g, TEMP[2].a);
        move(TEMP[0].b, CONST[0].z);
        move(TEMP[0].a, CONST[0].z);

        comment("r = r * distanceFromCenter, g = g * distanceFromCenter");
        encodeDistance(TEMP[0].r, TEMP[3].x, TEMP[3].y, TEMP[3].z, TEMP[3].w, CONST[0].x, CONST[0].y, CONST[0].z);
        encodeDistance(TEMP[0].g, TEMP[4].y, TEMP[4].x, TEMP[4].w, TEMP[4].z, CONST[0].x, CONST[0].y, CONST[0].z);

        move(OUTPUT, TEMP[0]);
    }

    /** Encodes distance from [0, 0] in cartesian space by multiplying by value from [0.5, 1], depending on its distance from the texture's center. */
    private static function encodeDistance(value:IComponent, x:IComponent, y:IComponent, tempX:IComponent, tempY:IComponent, zero:IComponent, half:IComponent, one:IComponent):void {
        multiply(tempX, x, x);
        multiply(tempY, y, y);

        add(tempX, tempX, tempY);
        squareRoot(tempX, tempX);

        Utils.clamp(tempX, tempX, zero, one);
        subtract(tempX, one, tempX);

        multiply(tempX, half, tempX);
        add(tempX, half, tempX);

        multiply(value, value, tempX);
    }
}
}
