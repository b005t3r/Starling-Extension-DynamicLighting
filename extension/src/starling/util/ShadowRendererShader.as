/**
 * User: booster
 * Date: 17/12/13
 * Time: 9:48
 */
package starling.util {
import com.barliesque.agal.EasierAGAL;
import com.barliesque.agal.IComponent;
import com.barliesque.agal.IComponent;
import com.barliesque.agal.IRegister;
import com.barliesque.agal.TextureFlag;
import com.barliesque.shaders.macro.Utils;

import flash.display3D.Context3D;
import flash.display3D.Context3DProgramType;

public class ShadowRendererShader extends EasierAGAL implements ITextureShader{
    private var _constants:Vector.<Number>  = new <Number>[0.0, 0.5, 1.0, 2.0];
    private var _uv:Vector.<Number>         = new <Number>[0.0, 0.0, 0.0, 0.0];

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
        var zero:IComponent             = CONST[0].x;
        var half:IComponent             = CONST[0].y;
        var one:IComponent              = CONST[0].z;
        var two:IComponent              = CONST[0].w;
        var minU:IComponent             = CONST[1].x;
        var maxU:IComponent             = CONST[1].y;
        var minV:IComponent             = CONST[1].z;
        var maxV:IComponent             = CONST[1].w;
        var uvInput:IRegister           = TEMP[0];
        var uvHorizontal:IRegister      = TEMP[1];
        var uvVertical:IRegister        = TEMP[2];
        var uv:IRegister                = TEMP[3];
        var inputColor:IRegister        = TEMP[6];
        var outputColor:IRegister       = TEMP[7];

        move(uvInput, VARYING[0]);

        ShaderUtil.normalize(uvInput.x, minU, maxU, TEMP[4].x);
        ShaderUtil.normalize(uvInput.y, minV, maxV, TEMP[4].x);

        move(uvHorizontal, uvInput);
        normalizedToHorizontalUV(uvHorizontal, TEMP[4], half, one, two);
        ShaderUtil.scale(uvHorizontal.x, minU, maxU, TEMP[4].x);
        ShaderUtil.scale(uvHorizontal.y, minV, maxV, TEMP[4].x);

        move(uvVertical, uvInput);
        normalizedToVerticalUV(uvVertical, TEMP[4], half, one, two);
        ShaderUtil.scale(uvVertical.x, minU, maxU, TEMP[4].x);
        ShaderUtil.scale(uvVertical.y, minV, maxV, TEMP[4].x);

        move(TEMP[4].y, zero);
        subtract(TEMP[4].y, TEMP[4].y, one);

        ShaderUtil.scale(uvInput.x, TEMP[4].y, one, TEMP[4].x);
        ShaderUtil.scale(uvInput.y, TEMP[4].y, one, TEMP[4].x);
        abs(uvInput.z, uvInput.x);
        abs(uvInput.w, uvInput.y);

        Utils.setByComparison(uv, uvInput.z, Utils.GREATER_OR_EQUAL, uvInput.w, uvHorizontal, uvVertical, TEMP[4]);

        sampleTexture(inputColor, uv, SAMPLER[0], [TextureFlag.TYPE_2D, TextureFlag.MODE_CLAMP, TextureFlag.FILTER_NEAREST, TextureFlag.MIP_NO]);

        Utils.setByComparison(TEMP[5].x, uvInput.z, Utils.GREATER_OR_EQUAL, uvInput.w, inputColor.r, inputColor.g, TEMP[4]);
        ShaderUtil.distance(TEMP[5].y, uvInput.x, uvInput.y, TEMP[4].z, TEMP[4].w, zero, one, half);

        Utils.setByComparison(outputColor.rgb, TEMP[5].x, Utils.GREATER_THAN, TEMP[5].y, zero, one, TEMP[4]);

        subtract(TEMP[5].y, TEMP[5].y, half);
        multiply(TEMP[5].y, TEMP[5].y, two);
        multiply(outputColor.rgb, outputColor.rgb, TEMP[5].y);

        //move(outputColor, uv);
        //move(outputColor.b, zero);
        move(outputColor.a, one);

        move(OUTPUT, outputColor);
    }

    private function normalizedToHorizontalUV(uv:IRegister, temp:IRegister, half:IComponent, one:IComponent, two:IComponent):void {
        move(temp, uv);

        var u:IComponent = temp.x;
        var v:IComponent = temp.y;

        subtract(u, u, half);
        abs(u, u);
        multiply(u, u, two);

        multiply(v, v, two);
        subtract(v, v, one);
        divide(v, v, u);
        add(v, v, one);
        divide(v, v, two);

        move(uv.y, v);
    }

    private function normalizedToVerticalUV(uv:IRegister, temp:IRegister, half:IComponent, one:IComponent, two:IComponent):void {
        move(temp, uv);

        var u:IComponent = temp.y;
        var v:IComponent = temp.x;

        subtract(u, u, half);
        abs(u, u);
        multiply(u, u, two);

        multiply(v, v, two);
        subtract(v, v, one);
        divide(v, v, u);
        add(v, v, one);
        divide(v, v, two);

        move(uv.x, uv.y);
        move(uv.y, v);
    }
}
}
