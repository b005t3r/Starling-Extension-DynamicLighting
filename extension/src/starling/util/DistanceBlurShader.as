/**
 * User: booster
 * Date: 18/12/13
 * Time: 11:29
 */
package starling.util {
import com.barliesque.agal.EasierAGAL;
import com.barliesque.agal.IComponent;
import com.barliesque.agal.IRegister;
import com.barliesque.agal.TextureFlag;
import com.barliesque.shaders.macro.Utils;

import flash.display3D.Context3D;
import flash.display3D.Context3DProgramType;

public class DistanceBlurShader extends EasierAGAL implements ITextureShader {
    public static const HORIZONTAL:String   = "horizontal";
    public static const VERTICAL:String     = "vertical";

    private static const MAX_STRENGTH_PER_PASS:Number       = 1.25;
    private static const MAX_STRENGTH_PER_PASS_RATIO:Number = 1.5;

    private static var _verticalOffsets:Vector.<Number>     = new <Number>[0.0, 1.3846153846, 0.0, 3.2307692308];
    private static var _horizontalOffsets:Vector.<Number>   = new <Number>[1.3846153846, 0.0, 3.2307692308, 0.0];

    private var _type:String                = HORIZONTAL;
    private var _pass:int                   = 0;
    private var _strength                   = Number.NaN;
    private var _pixelWidth                 = 0;
    private var _pixelHeight                = 0;
    private var _paramsDirty:Boolean        = true;

    private var _strengths:Vector.<Number>  = new Vector.<Number>(10);
    private var _offsets:Vector.<Number>    = new <Number>[0, 0, 0, 0];
    private var _uv:Vector.<Number>         = new <Number>[0, 1, 0, 1];
    private var _weights:Vector.<Number>    = new <Number>[0.2270270270, 0.3162162162, 0.0702702703, 0];

    public function get type():String { return _type; }
    public function set type(value:String):void {
        if(value == _type)
            return;

        _type = value;
        _paramsDirty = true;
    }

    public function get strength():Number { return _strength; }
    public function set strength(value:Number):void {
        if(value == _strength)
            return;

        _strength = value;
        _paramsDirty = true;

        // calculate new strengths to use for each pass
        _strengths.length   = 0;
        var str:Number      = Math.min(MAX_STRENGTH_PER_PASS, _strength);
        var sum:Number      = 0;

        for(var i:int = 0; _strength > sum; ++i) {
            _strengths[i]   = str;
            str            *= MAX_STRENGTH_PER_PASS_RATIO;
            sum            += str;
        }

        _strengths[_strengths.length] = Math.abs(_strength - sum);
        _strengths.sort(function(a:Number, b:Number):Number { return a - b; });

        trace("strengths: [" + _strengths + "]");
    }

    public function get pass():int { return _pass; }
    public function set pass(value:int):void {
        if(value == _pass)
            return;

        _pass = value;
        _paramsDirty = true;
    }

    public function get pixelWidth():Number { return _pixelWidth; }
    public function set pixelWidth(value:Number):void {
        if(value == _pixelWidth)
            return;

        _pixelWidth = value;
        _paramsDirty = true;
    }

    public function get pixelHeight():Number { return _pixelHeight; }
    public function set pixelHeight(value:Number):void {
        if(value == _pixelHeight)
            return;

        _pixelHeight = value;
        _paramsDirty = true;
    }

    public function get passesNeeded():int {
        return _strengths.length;
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
        if(_paramsDirty)
            updateParameters();

        context.setProgramConstantsFromVector(Context3DProgramType.VERTEX,   4, _offsets);
        context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _weights);
        context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT,   1, _uv);
    }

    public function deactivate(context:Context3D):void {
    }

    override protected function _vertexShader():void {
        comment("Apply a 4x4 matrix to transform vertices to clip-space");
        multiply4x4(OUTPUT, ATTRIBUTE[0], CONST[0]);

        comment("Pass uv coordinates to fragment shader");
        move(VARYING[0], ATTRIBUTE[1]);

        comment("pass 4 additional UVs for sampling neighbours, in order: -2, -1, +1, +2 pixels away");
        subtract(VARYING[1], ATTRIBUTE[1], CONST[4].zw);
        subtract(VARYING[2], ATTRIBUTE[1], CONST[4].xy);
        add(VARYING[3], ATTRIBUTE[1], CONST[4].xy);
        add(VARYING[4], ATTRIBUTE[1], CONST[4].zw);
    }

    override protected function _fragmentShader():void {
        var uvCenter:IRegister      = VARYING[0];
        var uvMinusTwo:IRegister    = VARYING[1];
        var uvMinusOne:IRegister    = VARYING[2];
        var uvPlusOne:IRegister     = VARYING[3];
        var uvPlusTwo:IRegister     = VARYING[4];
        var uv:IRegister            = TEMP[7];
        var weightCenter:IComponent = CONST[0].x;
        var weightOne:IComponent    = CONST[0].y;
        var weightTwo:IComponent    = CONST[0].z;
        var minU:IComponent         = CONST[1].x;
        var maxU:IComponent         = CONST[1].y;
        var minV:IComponent         = CONST[1].z;
        var maxV:IComponent         = CONST[1].w;
        var colorCenter:IRegister   = TEMP[0];
        var colorMinusTwo:IRegister = TEMP[1];
        var colorMinusOne:IRegister = TEMP[2];
        var colorPlusOne:IRegister  = TEMP[3];
        var colorPlusTwo:IRegister  = TEMP[4];
        var outputColor:IRegister   = TEMP[5];
        var textureFlags:Array      = [TextureFlag.TYPE_2D, TextureFlag.MODE_CLAMP, TextureFlag.FILTER_LINEAR, TextureFlag.MIP_NO];

        sampleTexture(colorCenter, uvCenter, SAMPLER[0], textureFlags);
        multiply(outputColor, colorCenter, weightCenter);

        move(uv, uvMinusTwo);
        Utils.clamp(uv.x, uv.x, minU, maxU);
        Utils.clamp(uv.y, uv.y, minV, maxV);
        sampleTexture(colorMinusTwo, uv, SAMPLER[0], textureFlags);
        multiply(colorMinusTwo, colorMinusTwo, weightTwo);
        add(outputColor, outputColor, colorMinusTwo);

        move(uv, uvMinusOne);
        Utils.clamp(uv.x, uv.x, minU, maxU);
        Utils.clamp(uv.y, uv.y, minV, maxV);
        sampleTexture(colorMinusOne, uv, SAMPLER[0], textureFlags);
        multiply(colorMinusOne, colorMinusOne, weightOne);
        add(outputColor, outputColor, colorMinusOne);

        move(uv, uvPlusOne);
        Utils.clamp(uv.x, uv.x, minU, maxU);
        Utils.clamp(uv.y, uv.y, minV, maxV);
        sampleTexture(colorPlusOne, uv, SAMPLER[0], textureFlags);
        multiply(colorPlusOne, colorPlusOne, weightOne);
        add(outputColor, outputColor, colorPlusOne);

        move(uv, uvPlusTwo);
        Utils.clamp(uv.x, uv.x, minU, maxU);
        Utils.clamp(uv.y, uv.y, minV, maxV);
        sampleTexture(colorPlusTwo, uv, SAMPLER[0], textureFlags);
        multiply(colorPlusTwo, colorPlusTwo, weightTwo);
        add(outputColor, outputColor, colorPlusTwo);

        move(OUTPUT, outputColor);
    }

    private function updateParameters():void
    {
        // algorithm described here:
        // http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
        //
        // To run in constrained mode, we can only make 5 texture lookups in the fragment
        // shader. By making use of linear texture sampling, we can produce similar output
        // to what would be 9 lookups.

        _paramsDirty = false;

        // we can try to push this to the limits and create a stronger blur with one pass, value about 1.25 is enough
        var multiplier:Number;
        var str:Number = _strengths[_pass];

        var i:int, count:int = 4;

        trace("strength: " + str);

        if(type == HORIZONTAL) {
            multiplier = _pixelWidth * str;

            for(i = 0; i < count; i++)
                _offsets[i] = _horizontalOffsets[i] * multiplier;
        }
        else {
            multiplier = _pixelHeight * str;

            for(i = 0; i < count; i++)
                _offsets[i] = _verticalOffsets[i] * multiplier;
        }

    }
}
}
