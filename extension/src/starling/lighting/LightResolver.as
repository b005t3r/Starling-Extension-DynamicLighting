/**
 * User: booster
 * Date: 08/12/13
 * Time: 12:09
 */
package starling.lighting {
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;

import starling.display.DisplayObject;
import starling.textures.RenderTexture;
import starling.textures.Texture;
import starling.util.RayGeneratorShader;
import starling.util.RayReductorShader;
import starling.util.RenderTextureShader;
import starling.util.ShadowRendererShader;
import starling.util.TextureProcessor;
import starling.utils.getNextPowerOfTwo;

public class LightResolver {
    private static var _helperPoint:Point                       = new Point();
    private static var _helperRect:Rectangle                    = new Rectangle();
    private static var _lightRect:Rectangle                     = new Rectangle();
    private static var _helperMatrix:Matrix                     = new Matrix();

    private var _shadowLayer:ShadowLayer                        = null;
    private var _lights:Vector.<Light>                          = new <Light>[];
    private var _shadowCasters:Vector.<DisplayObject>           = new <DisplayObject>[];

    private var _raysFirstTexture:RenderTexture;
    private var _raysSecondTexture:RenderTexture;
    private var _castersTexture:RenderTexture;

    private var _textureProcessor:TextureProcessor              = new TextureProcessor();
    private var _raysShader:RayGeneratorShader                  = new RayGeneratorShader();
    private var _reductionShaders:Vector.<RayReductorShader>    = new <RayReductorShader>[];
    private var _shadowShader:ShadowRendererShader              = new ShadowRendererShader();

    /** The shadow layer this resolver renders lights to. */
    public function get shadowLayer():ShadowLayer { return _shadowLayer; }
    public function set shadowLayer(value:ShadowLayer):void { _shadowLayer = value; }

    public function LightResolver() {
        _raysFirstTexture   = new RenderTexture(512, 512, false);
        _raysSecondTexture  = new RenderTexture(512, 512, false);
        _castersTexture     = new RenderTexture(2048, 2048, false);

        for(var i:int = 2; i <= 32; i *= 2) {
            var shader:RayReductorShader = new RayReductorShader();
            shader.numReads = i;

            _reductionShaders.push(shader);
        }
    }

    public function get castersTexture():Texture { return _castersTexture; }
    public function get raysFirstTexture():Texture { return _raysFirstTexture; } // TODO: remove
    public function get raysSecondTexture():Texture { return _raysSecondTexture; } // TODO: remove

    /** Adds a new light to be resolved. */
    public function addLight(light:Light):void {
        var i:int = _lights.indexOf(light);

        if(i < 0)
            _lights.push(light);
    }

    /** Removes a previously added light. */
    public function removeLight(light:Light):void {
        var i:int = _lights.indexOf(light);

        if(i >= 0)
            _lights.splice(i, 1);
    }

    /** Adds a new shadow caster to be resolved. */
    public function addShadowCaster(caster:DisplayObject):void {
        var i:int = _shadowCasters.indexOf(caster);

        if(i < 0)
            _shadowCasters.push(caster);
    }

    /** Removes a previously added light. */
    public function removeShadowCaster(caster:DisplayObject):void {
        var i:int = _shadowCasters.indexOf(caster);

        if(i >= 0)
            _shadowCasters.splice(i, 1);
    }

    public function resolve():void {
        renderCasters(_shadowCasters, _castersTexture);

        var lightCount:int = _lights.length;
        for(var i:int = 0; i < lightCount; i++) {
            var light:Light = _lights[i];

            setLightRect(light, _lightRect);
            renderRays(_lightRect, _raysFirstTexture, castersTexture);

            var shadowMap:Texture = renderShadowMap(_lightRect, _raysFirstTexture, _raysSecondTexture, 32);

            renderShadow(
                _lightRect,
                shadowMap == _raysFirstTexture ? _raysSecondTexture : _raysFirstTexture,
                shadowMap == _raysFirstTexture ? _raysFirstTexture : _raysSecondTexture
            );
        }
    }

    private function renderCasters(casters:Vector.<DisplayObject>, target:RenderTexture):void {
        target.drawBundled(function():void {
            var count:int = casters.length;
            for(var i:int = 0; i < count; i++) {
                var caster:DisplayObject = casters[i];

                caster.getTransformationMatrix(caster.base, _helperMatrix);

                target.draw(caster, _helperMatrix);
            }
        });
    }

    private function setLightRect(light:Light, output:Rectangle):void {
        var r:Number = light.radius;

        // get light's bounds in stage space
        output.setTo(light.x - r, light.y - r, 2 * r, 2 * r);
        output.topLeft     = light.parent.localToGlobal(output.topLeft, _helperPoint);
        output.bottomRight = light.parent.localToGlobal(output.bottomRight, _helperPoint);

        var w:int           = getNextPowerOfTwo(Math.round(output.width));
        var h:int           = getNextPowerOfTwo(Math.round(output.height));
        var hOffset:Number  = w - output.width;
        var vOffset:Number  = h - output.height;

        output.left    -= hOffset / 2;
        output.right   += hOffset / 2;
        output.top     -= vOffset / 2;
        output.bottom  += vOffset / 2;
    }

    /** Creates a texture with each ray drawn horizontally, so it can later be used for rendering a shadow map. */
    private function renderRays(lightRect:Rectangle, raysTexture:Texture, castersTexture:Texture):void {
        _helperMatrix.identity();
        _helperMatrix.translate(-lightRect.x, -lightRect.y);

        // prepare to rendering rays
        _textureProcessor.input     = castersTexture;
        _textureProcessor.output    = raysTexture;
        _textureProcessor.shader    = _raysShader;

        // set UV range - only this part of input will be processed
        _raysShader.minU = lightRect.left / _textureProcessor.input.root.width;
        _raysShader.maxU = lightRect.right / _textureProcessor.input.root.width;
        _raysShader.minV = lightRect.top / _textureProcessor.input.root.height;
        _raysShader.maxV = lightRect.bottom / _textureProcessor.input.root.height;

        // clipping is done in output space - start at [0, 0]
        _helperRect.setTo(0, 0, lightRect.width, lightRect.height);

        _textureProcessor.process(true, _helperMatrix, _helperRect);
    }

    /** Reduces a ray texture into a shadow map (2-pixel width texture). */
    private function renderShadowMap(lightRect:Rectangle, raysTexture:Texture, tmpTexture:Texture, textureFetches:int = 4):Texture {
        // prepare to rays reduction
        _textureProcessor.input     = raysTexture;
        _textureProcessor.output    = tmpTexture;

        _helperRect.setTo(0, 0, lightRect.width, lightRect.height);

        while(true) {
            var reductionShader:RayReductorShader = getReductionShader(_helperRect.width);

            reductionShader.pixelWidth = 1 / raysTexture.root.width;

            // set UV range - only this part of input will be processed
            reductionShader.minU = _helperRect.left / _textureProcessor.input.root.width;
            reductionShader.maxU = _helperRect.right / _textureProcessor.input.root.width;
            reductionShader.minV = _helperRect.top / _textureProcessor.input.root.height;
            reductionShader.maxV = _helperRect.bottom / _textureProcessor.input.root.height;

            _textureProcessor.shader = reductionShader;
            _textureProcessor.process(true, null, _helperRect);

            _helperRect.width /= reductionShader.numReads;

            if(_helperRect.width == 2)
                break;

            _textureProcessor.swap();
        }

        return _textureProcessor.output;
    }

    private function renderShadow(lightRect:Rectangle, output:Texture, shadowMap:Texture):void {
        _helperRect.setTo(0, 0, 2, lightRect.height);

        _textureProcessor.input     = shadowMap;
        _textureProcessor.output    = output;
        _textureProcessor.shader    = _shadowShader;
        //_textureProcessor.shader    = new RenderTextureShader();

        _shadowShader.minU = _helperRect.left / _textureProcessor.input.root.width;
        _shadowShader.maxU = _helperRect.right / _textureProcessor.input.root.width;
        _shadowShader.minV = _helperRect.top / _textureProcessor.input.root.height;
        _shadowShader.maxV = _helperRect.bottom / _textureProcessor.input.root.height;

        _helperRect.setTo(0, 0, lightRect.width, lightRect.height);

        _helperMatrix.identity();
        _helperMatrix.scale(_helperRect.width / 2, 1);

        _textureProcessor.process(true, _helperMatrix, _helperRect);
    }

    private function getReductionShader(width:int):RayReductorShader {
        if(width > 32)
            return _reductionShaders[4];
        else if(width == 32)
            return _reductionShaders[3];
        else if(width == 16)
            return _reductionShaders[2];
        else if(width == 8)
            return _reductionShaders[1];
        else if(width == 4)
            return _reductionShaders[0];
        else
            throw new ArgumentError("invalid width: " + width);
    }
}
}
