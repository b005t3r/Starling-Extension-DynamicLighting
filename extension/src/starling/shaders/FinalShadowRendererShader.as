/**
 * User: booster
 * Date: 08/01/14
 * Time: 9:32
 */
package starling.shaders {
import com.barliesque.agal.EasierAGAL;
import com.barliesque.agal.IComponent;
import com.barliesque.agal.IField;
import com.barliesque.agal.IRegister;
import com.barliesque.agal.TextureFlag;
import com.barliesque.shaders.macro.Utils;

import flash.display3D.Context3D;
import flash.display3D.Context3DProgramType;

public class FinalShadowRendererShader extends EasierAGAL implements ITextureShader {
    private static var _shaderConstants:Vector.<Number> = new <Number>[0, 1, 2, 0];

    private var _useVertexUVRange:Boolean;

    private var _uv:Vector.<Number> = new <Number>[0, 1, 0, 1];

    // shader constants
    protected var zero:IComponent   = CONST[0].x;
    protected var one:IComponent    = CONST[0].y;
    protected var two:IComponent    = CONST[0].z;
    protected var uMin:IComponent   = CONST[1].x;
    protected var uMax:IComponent   = CONST[1].y;
    protected var vMin:IComponent   = CONST[1].z;
    protected var vMax:IComponent   = CONST[1].w;

    public function FinalShadowRendererShader(useVertexUVRange:Boolean = true) {
        _useVertexUVRange = useVertexUVRange;

        if(_useVertexUVRange) {
            uMin = VARYING[1].x;
            uMax = VARYING[1].y;
            vMin = VARYING[1].z;
            vMax = VARYING[1].w;
        }
    }

    public function get minU():Number { return _uv[0]; }
    public function set minU(value:Number):void { _uv[0] = value; }

    public function get maxU():Number { return _uv[1]; }
    public function set maxU(value:Number):void { _uv[1] = value; }

    public function get minV():Number { return _uv[2]; }
    public function set minV(value:Number):void { _uv[2] = value; }

    public function get maxV():Number { return _uv[3]; }
    public function set maxV(value:Number):void { _uv[3] = value; }

    public function activate(context:Context3D):void {
        context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _shaderConstants);

        if(_useVertexUVRange)
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, _uv);
    }

    public function deactivate(context:Context3D):void { }

    override protected function _vertexShader():void {
        comment("Apply a 4x4 matrix to transform vertices to clip-space");
        multiply4x4(OUTPUT, ATTRIBUTE[0], CONST[0]);

        comment("Pass uv coordinates to fragment shader");
        move(VARYING[0], ATTRIBUTE[1]);

        if(_useVertexUVRange) {
            comment("Pass minU, maxU, minV, maxV to fragment shader");
            move(VARYING[1], ATTRIBUTE[2]);
        }
    }

    override protected function _fragmentShader():void {
        var uv:IRegister            = TEMP[0];
        var outputColor:IRegister   = TEMP[1];
        var distance:IComponent     = TEMP[2].x;
        var temp:IRegister          = TEMP[7];

        move(uv, VARYING[0]);

        comment("Use UV coordinates passed from vertex shader to sample the texture");
        sampleTexture(outputColor, uv, SAMPLER[0], [TextureFlag.TYPE_2D, TextureFlag.MODE_CLAMP, TextureFlag.FILTER_NEAREST, TextureFlag.MIP_NO]);

        comment("Convert UV to cartesian space and calculate distance from the center, clamp the distance to [0, 1]");
        ShaderUtil.uvToCartesian(uv.x, uv.y, uMin, uMax, vMin, vMax, temp.x, one, two);
        ShaderUtil.distance(distance, uv.x, uv.y, temp.x, temp.y);
        Utils.clamp(distance, distance, zero, one);

        comment("light attenuation = 1 - distance");
        subtract(distance, one, distance);

        multiply(outputColor.rgb, outputColor.rgb, distance);
        move(OUTPUT, outputColor);
    }
}
}
