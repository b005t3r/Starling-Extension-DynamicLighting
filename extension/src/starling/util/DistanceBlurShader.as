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

import flash.display3D.Context3D;
import flash.display3D.Context3DProgramType;

public class DistanceBlurShader extends EasierAGAL implements ITextureShader {
    public static const HORIZONTAL:String   = "horizontal";
    public static const VERTICAL:String     = "vertical";

    private static const MAX_SIGMA:Number   = 2.0;

    private static var sTmpWeights:Vector.<Number> = new <Number>[0, 0, 0, 0];

    private var _type:String                = HORIZONTAL;
    private var _strength:Number            = 1.0;
    private var paramsDirty:Boolean         = true;
    private var _pixelWidth:Number;
    private var _pixelHeight:Number;

    private var mOffsets:Vector.<Number> = new <Number>[0, 0, 0, 0];
    private var mWeights:Vector.<Number> = new <Number>[0, 0, 0, 0];

    public function get type():String { return _type; }
    public function set type(value:String):void {
        if(value == _type)
            return;

        _type = value;
        paramsDirty = true;
    }

    public function get strength():Number { return _strength; }
    public function set strength(value:Number):void {
        if(value == _strength)
            return;

        _strength = value;
        paramsDirty = true;
    }

    public function get pixelWidth():Number { return _pixelWidth; }
    public function set pixelWidth(value:Number):void {
        if(value == _pixelWidth)
            return;

        _pixelWidth = value;
        paramsDirty = true;
    }

    public function get pixelHeight():Number { return _pixelHeight; }
    public function set pixelHeight(value:Number):void {
        if(value == _pixelHeight)
            return;

        _pixelHeight = value;
        paramsDirty = true;
    }

    public function activate(context:Context3D):void {
        if(paramsDirty)
            updateParameters();

        context.setProgramConstantsFromVector(Context3DProgramType.VERTEX,   4, mOffsets);
        context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, mWeights);
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
        var weightCenter:IComponent = CONST[0].x;
        var weightOne:IComponent    = CONST[0].y;
        var weightTwo:IComponent    = CONST[0].z;
        var colorCenter:IRegister   = TEMP[0];
        var colorMinusTwo:IRegister = TEMP[1];
        var colorMinusOne:IRegister = TEMP[2];
        var colorPlusOne:IRegister  = TEMP[3];
        var colorPlusTwo:IRegister  = TEMP[4];
        var outputColor:IRegister   = TEMP[5];
        var textureFlags:Array      = [TextureFlag.TYPE_2D, TextureFlag.MODE_CLAMP, TextureFlag.FILTER_LINEAR, TextureFlag.MIP_NO];

        sampleTexture(colorCenter, uvCenter, SAMPLER[0], textureFlags);
        multiply(outputColor, colorCenter, weightCenter);

        sampleTexture(colorMinusTwo, uvMinusTwo, SAMPLER[0], textureFlags);
        multiply(colorMinusTwo, colorMinusTwo, weightTwo);
        add(outputColor, outputColor, colorMinusTwo);

        sampleTexture(colorMinusOne, uvMinusOne, SAMPLER[0], textureFlags);
        multiply(colorMinusOne, colorMinusOne, weightOne);
        add(outputColor, outputColor, colorMinusOne);

        sampleTexture(colorPlusOne, uvPlusOne, SAMPLER[0], textureFlags);
        multiply(colorPlusOne, colorPlusOne, weightOne);
        add(outputColor, outputColor, colorPlusOne);

        sampleTexture(colorPlusTwo, uvPlusTwo, SAMPLER[0], textureFlags);
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


        var sigma:Number        = Math.min(1.0, _strength) * MAX_SIGMA;
        var horizontal:Boolean  = (type == HORIZONTAL);
        var pixelSize:Number    = horizontal ? _pixelWidth : _pixelHeight;

        if(horizontal) {
            mOffsets[0] = pixelSize;
            mOffsets[1] = 0;
            mOffsets[2] = pixelSize * 2;
            mOffsets[3] = 0;
        }
        else {
            mOffsets[0] = 0;
            mOffsets[1] = pixelSize;
            mOffsets[2] = 0;
            mOffsets[3] = pixelSize * 2;
        }

        mWeights = new <Number>[0.5, 0.2, 0.05, 0.0];
    }
/*
        var sigma:Number        = Math.min(1.0, _strength) * MAX_SIGMA;
        var horizontal:Boolean  = (type == HORIZONTAL);
        var pixelSize:Number    = horizontal ? _pixelWidth : _pixelHeight;

        const twoSigmaSq:Number = 2 * sigma * sigma;
        const multiplier:Number = 1.0 / Math.sqrt(twoSigmaSq * Math.PI);

        // get weights on the exact pixels (sTmpWeights) and calculate sums (mWeights)

        for (var i:int=0; i<5; ++i)
            sTmpWeights[i] = multiplier * Math.exp(-i*i / twoSigmaSq);

        mWeights[0] = sTmpWeights[0];
        mWeights[1] = sTmpWeights[1] + sTmpWeights[2];
        mWeights[2] = sTmpWeights[3] + sTmpWeights[4];

        // normalize weights so that sum equals "1.0"

        var weightSum:Number = mWeights[0] + 2*mWeights[1] + 2*mWeights[2];
        var invWeightSum:Number = 1.0 / weightSum;

        mWeights[0] *= invWeightSum;
        mWeights[1] *= invWeightSum;
        mWeights[2] *= invWeightSum;

        // calculate intermediate offsets

        var offset1:Number = (  pixelSize * sTmpWeights[1] + 2*pixelSize * sTmpWeights[2]) / mWeights[1];
        var offset2:Number = (3*pixelSize * sTmpWeights[3] + 4*pixelSize * sTmpWeights[4]) / mWeights[2];

        // depending on pass, we move in x- or y-direction

        if (horizontal)
        {
            mOffsets[0] = offset1;
            mOffsets[1] = 0;
            mOffsets[2] = offset2;
            mOffsets[3] = 0;
        }
        else
        {
            mOffsets[0] = 0;
            mOffsets[1] = offset1;
            mOffsets[2] = 0;
            mOffsets[3] = offset2;
        }
    }
*/

}
}
