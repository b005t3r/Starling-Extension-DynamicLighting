/**
 * User: booster
 * Date: 13/12/13
 * Time: 12:05
 */
package starling.util {
import com.barliesque.agal.EasierAGAL;
import com.barliesque.agal.IComponent;
import com.barliesque.agal.IComponent;
import com.barliesque.agal.IComponent;
import com.barliesque.agal.IRegister;
import com.barliesque.agal.TextureFlag;
import com.barliesque.shaders.macro.Utils;

import flash.display3D.Context3D;
import flash.display3D.Context3DProgramType;

import starling.shaders.ITextureShader;

public class RayReductorShader extends EasierAGAL implements ITextureShader {
    private var _constants:Vector.<Number>  = new <Number>[0.0, 4.0, 0.0, 2.0];
    private var _uv:Vector.<Number>         = new <Number>[0.0, 0.0, 0.0, 0.0];

    public function get pixelWidth():Number { return _constants[0]; }
    public function set pixelWidth(value:Number):void { _constants[0] = value; }

    public function get numReads():Number { return _constants[1]; }
    public function set numReads(value:Number):void {
        if(value == _constants[1])
            return;

        _constants[1] = value;

        // reset program on change
        setProgram(null);
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
        var pixelWidth:IComponent       = CONST[0].x;
        var readCount:IComponent        = CONST[0].y;
        var zero:IComponent             = CONST[0].z;
        var two:IComponent              = CONST[0].w;
        var minU:IComponent             = CONST[1].x;
        var maxU:IComponent             = CONST[1].y;
        var uv:IRegister                = TEMP[0];
        var halfPixelWidth:IComponent   = TEMP[1].x;
        var outputColor:IRegister       = TEMP[7];

        move(uv, VARYING[0]);

        comment("uv is set to the middle of first pixel, move it to its left edge first");
        move(halfPixelWidth, pixelWidth);
        divide(halfPixelWidth, halfPixelWidth, two);
        subtract(uv.x, uv.x, halfPixelWidth);

        comment("c = (x - minU) / pixelWidth -> c = x / pixelWidth 0 minU / pixelWidth");
        move(TEMP[2].x, minU);
        divide(TEMP[2].x, TEMP[2].x, pixelWidth);
        divide(TEMP[2].y, uv.x, pixelWidth);
        subtract(TEMP[2].y, TEMP[2].y, TEMP[2].x);

        comment("c' = c * readCount");
        multiply(TEMP[2].y, TEMP[2].y, readCount);

        comment("c' = (x' - minU) / pixelWidth -> x' = c' * pixelWidth + minU");
        multiply(uv.x, TEMP[2].y, pixelWidth);
        add(uv.x, uv.x, minU);

        comment("set uv back to the middle of first pixel to process");
        add(uv.x, uv.x, halfPixelWidth);

        killIfOutsideRange(uv.x, maxU, zero, TEMP[2].x, TEMP[3]);

        comment("set output color to 0x00000000");
        move(outputColor, zero);

        comment("read all samples and set each channel's max as the output color");
        var i:int = 0;
        while(true) {
            sampleInput(outputColor, uv, TEMP[2]);

            ++i;

            if(i == numReads)
                break;

            add(uv.x, uv.x, pixelWidth);
        }

        comment("send max to the output")
        move(OUTPUT, outputColor);
    }

    private function killIfOutsideRange(value:IComponent, max:IComponent, zero:IComponent, temp:IComponent, temp2:IRegister):void {
        Utils.setByComparison(temp, value, Utils.GREATER_THAN, max, zero, max, temp2);  // temp is either max or 0
        subtract(temp, temp, max);          // temp is either -max or 0
        killFragment(temp);                 // kill is temp < 0
    }

    private function sampleInput(out:IRegister, uv:IRegister, temp:IRegister):void {
        sampleTexture(temp, uv, SAMPLER[0], [TextureFlag.TYPE_2D, TextureFlag.MODE_CLAMP, TextureFlag.FILTER_NEAREST, TextureFlag.MIP_NO]);
        max(out, out, temp);
    }
}
}
