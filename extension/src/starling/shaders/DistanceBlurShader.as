/**
 * User: booster
 * Date: 18/12/13
 * Time: 11:29
 */
package starling.shaders {
import com.barliesque.agal.IComponent;
import com.barliesque.agal.IField;
import com.barliesque.agal.IRegister;
import com.barliesque.shaders.macro.Utils;

import flash.display3D.Context3D;
import flash.display3D.Context3DProgramType;

public class DistanceBlurShader extends FastGaussianBlurShader {
    private var _minRatio:Number            = 0;
    private var _maxRatio:Number            = 1;
    private var _distances:Vector.<Number>  = new <Number>[];
    private var _distancesDirty:Boolean     = true;

    private var _shaderDistances:Vector.<Number>  = new <Number>[0, 0, 0, 0];
    private var _shaderConstants:Vector.<Number>  = new <Number>[0, 1, 2, 0];

    // shader constants
    protected var minDistance:IComponent    = CONST[3].x;
    protected var maxDistance:IComponent    = CONST[3].y;
    protected var zero:IComponent           = CONST[4].x;
    protected var one:IComponent            = CONST[4].y;
    protected var two:IComponent            = CONST[4].z;

    public function get minRatio():Number { return _minRatio; }
    public function set minRatio(value:Number):void {
        if(_minRatio == value)
            return;

        _minRatio = value > 1.0 ? 1.0 : value < 0.0 ? 0.0 : value;
        _distancesDirty = true;
    }

    public function get maxRatio():Number { return _maxRatio; }
    public function set maxRatio(value:Number):void {
        if(_maxRatio == value)
            return;

        _maxRatio = value > 1.0 ? 1.0 : value < 0.0 ? 0.0 : value;
        _distancesDirty = true;
    }

    override public function set strength(value:Number):void {
        super.strength = value;

        _distancesDirty = true;
    }

    override public function activate(context:Context3D):void {
        super.activate(context);

        if(_distancesDirty)
            updateDistances();

        // set min and max distance for current strength
        _shaderDistances[0] = _distances[pass + 1];
        _shaderDistances[1] = _distances[pass];

        context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 3, _shaderDistances);
        context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 4, _shaderConstants);
    }

    override protected function _fragmentShader():void {
        var tempColor:IRegister     = TEMP[0];
        var outputColor:IRegister   = TEMP[1];
        var uv:IRegister            = TEMP[2];
        var newOffsetOne:IField     = TEMP[3].xy;
        var newOffsetTwo:IField     = TEMP[3].zw;
        var distance:IComponent     = TEMP[4].x;
        var temp:IRegister          = TEMP[7];

        comment("calculate current distance from the center of texture");
        move(uv, uvCenter);
        ShaderUtil.uvToCartesian(uv.x, uv.y, uMin, uMax, vMin, vMax, temp.x, one, two);
        ShaderUtil.distance(distance, uv.x, uv.y, temp.x, temp.y);

        comment("clamp distance between min and max distance");
        Utils.clamp(distance, distance, minDistance, maxDistance);

        comment("normalize distance to be in [0, 1] between min and max distance");
        ShaderUtil.normalize(distance, minDistance, maxDistance, temp.x);

        sampleColor(outputColor, uvCenter, weightCenter);

        multiply(newOffsetOne, offsetOne, distance);
        multiply(newOffsetTwo, offsetTwo, distance);

        subtract(uv, uvCenter, newOffsetTwo);
        sampleColor(tempColor, uv, weightTwo, uMin, uMax, vMin, vMax, halfPixelWidth, halfPixelHeight, temp);
        add(outputColor, outputColor, tempColor);

        add(uv, uvCenter, newOffsetTwo);
        sampleColor(tempColor, uv, weightTwo, uMin, uMax, vMin, vMax, halfPixelWidth, halfPixelHeight, temp);
        add(outputColor, outputColor, tempColor);

        subtract(uv, uvCenter, newOffsetOne);
        sampleColor(tempColor, uv, weightOne, uMin, uMax, vMin, vMax, halfPixelWidth, halfPixelHeight, temp);
        add(outputColor, outputColor, tempColor);

        add(uv, uvCenter, newOffsetOne);
        sampleColor(tempColor, uv, weightOne, uMin, uMax, vMin, vMax, halfPixelWidth, halfPixelHeight, temp);
        add(outputColor, outputColor, tempColor);

        move(OUTPUT, outputColor);
    }

    /**
     * Calculates distance ranges to apply each blur strength.
     * This distances represent region where each strength value is applied after being linearly interpolated.
     * I.e. if a value of 5 is applied to region 0.8 - 1.0, this means means pixels furthest from the center (100%)
     * will be blurred with strength 5, while pixels at 80% distance will not be blurred using this strength.
     * And if a value of 3 is applied to region 0.6 - 0.8, pixels at 80% distance and further will be blurred with
     * strength 3, at 60% and closer won't be blurred with this strength and the ones in the middle will be blurred
     * with strength between 0 and 3.
     * By combining different strength values applied to complementary regions, we can achieve a smooth blur with
     * strength increasing from the center.
     */
    private function updateDistances():void {
        _distancesDirty = false;

        var minStrength:Number  = strength * minRatio;
        var maxStrength:Number  = strength * maxRatio;
        var diff:Number         = maxStrength - minStrength;

        _distances.length   = 0;
        _distances[0]       = 1;

        if(strength > 0) {
            var count:int = _strengths.length - 1;
            for(var i:int = 0; i < count; i++) {
                // max distance for strength i-1, min for strength i
                var str:Number      = _strengths[i];
                _distances[i + 1]   = str / diff;
            }
        }

        _distances[_distances.length] = 0;
    }
}
}
