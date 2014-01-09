/**
 * User: booster
 * Date: 08/12/13
 * Time: 12:09
 */
package starling.lighting {
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.utils.getTimer;

import starling.display.BlendMode;

import starling.display.DisplayObject;
import starling.display.Quad;
import starling.shaders.FastGaussianBlurShader;
import starling.shaders.FinalShadowRendererShader;
import starling.textures.RenderTexture;
import starling.textures.Texture;
import starling.textures.TextureProcessor;
import starling.shaders.DistanceBlurShader;
import starling.shaders.RayGeneratorShader;
import starling.shaders.RayReductorShader;
import starling.shaders.ShadowRendererShader;
import starling.utils.getNextPowerOfTwo;

public class LightResolver {
    private static var _helperPoint:Point                       = new Point();
    private static var _helperRect:Rectangle                    = new Rectangle();
    private static var _lightRect:Rectangle                     = new Rectangle();
    private static var _helperMatrix:Matrix                     = new Matrix();

    private var _shadowLayer:ShadowLayer                        = null;
    private var _lights:Vector.<Light>                          = new <Light>[];
    private var _shadowCasters:Vector.<DisplayObject>           = new <DisplayObject>[];

    private var _tempTextureA:RenderTexture;
    private var _tempTextureB:RenderTexture;
    private var _castersTexture:RenderTexture;
    private var _shadowsTexture:RenderTexture;

    private var _textureProcessor:TextureProcessor              = new TextureProcessor();
    private var _raysShader:RayGeneratorShader                  = new RayGeneratorShader();
    private var _reductionShaders:Vector.<RayReductorShader>    = new <RayReductorShader>[];
    private var _shadowShader:ShadowRendererShader              = new ShadowRendererShader();
    private var _blurShader:DistanceBlurShader                  = new DistanceBlurShader();
    private var _finalShadowShader:FinalShadowRendererShader    = new FinalShadowRendererShader();

    /** The shadow layer this resolver renders lights to. */
    public function get shadowLayer():ShadowLayer { return _shadowLayer; }
    public function set shadowLayer(value:ShadowLayer):void { _shadowLayer = value; }

    public function LightResolver() {
        _tempTextureA   = new RenderTexture(512, 512, false);
        _tempTextureB   = new RenderTexture(512, 512, false);
        _castersTexture = new RenderTexture(2048, 2048, false);
        _shadowsTexture = new RenderTexture(2048, 2048, false);

        for(var i:int = 2; i <= 32; i *= 2) {
            var shader:RayReductorShader = new RayReductorShader();
            shader.numReads = i;

            _reductionShaders.push(shader);
        }
    }

    public function get castersTexture():Texture { return _castersTexture; }
    public function get shadowsTexture():Texture { return _shadowsTexture; }
    public function get tempTextureA():Texture { return _tempTextureA; } // TODO: remove
    public function get tempTextureB():Texture { return _tempTextureB; } // TODO: remove

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

        _shadowsTexture.clear(0x000000, 1);
        _tempTextureA.clear();
        _tempTextureB.clear();

        var lightCount:int = _lights.length;
        for(var i:int = 0; i < lightCount; i++) {
            var light:Light = _lights[i];

            setLightRect(light, _lightRect);

            renderRays(_lightRect, _tempTextureA, castersTexture);

            var shadowMap:Texture = renderShadowMap(_lightRect, _tempTextureA, _tempTextureB, 32);
            var output:Texture = shadowMap == _tempTextureA ? _tempTextureB : _tempTextureA;

            renderShadow(light, _lightRect, output, shadowMap);

            var shadow:Texture = renderBlur(light, _lightRect, output, shadowMap);

            renderFinalShadow(light, _lightRect, shadow, _shadowsTexture);
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
        var hOffset:Number  = (w - output.width) / 2;
        var vOffset:Number  = (h - output.height) / 2;

        output.left    = Math.round(output.left - hOffset);
        output.right   = Math.round(output.right + hOffset);
        output.top     = Math.round(output.top - vOffset);
        output.bottom  = Math.round(output.bottom + vOffset);
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

        _textureProcessor.process(false, _helperMatrix, _helperRect, BlendMode.NONE);
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
            _textureProcessor.process(false, null, _helperRect, BlendMode.NONE);

            _helperRect.width /= reductionShader.numReads;

            if(_helperRect.width == 2)
                break;

            _textureProcessor.swap();
        }

        return _textureProcessor.output;
    }

    private function renderShadow(light:Light, lightRect:Rectangle, output:Texture, shadowMap:Texture):void {
        _helperRect.setTo(0, 0, 2, lightRect.height);

        _textureProcessor.input     = shadowMap;
        _textureProcessor.output    = output;
        _textureProcessor.shader    = _shadowShader;
        //_textureProcessor.shader    = new RenderTextureShader();

        _shadowShader.minU = _helperRect.left / _textureProcessor.input.root.width;
        _shadowShader.maxU = _helperRect.right / _textureProcessor.input.root.width;
        _shadowShader.minV = _helperRect.top / _textureProcessor.input.root.height;
        _shadowShader.maxV = _helperRect.bottom / _textureProcessor.input.root.height;

        _shadowShader.pixelWidth = 1 / _textureProcessor.input.root.width;
        _shadowShader.pixelHeight = 1 / _textureProcessor.input.root.height;

        _shadowShader.color = light.color;

        var r:Number = light.radius;
        _helperRect.setTo(lightRect.width / 2 - r, lightRect.height / 2 - r, 2 * r, 2 * r);

        _helperMatrix.identity();
        _helperMatrix.scale(_lightRect.width / 2, 1);

        _textureProcessor.process(false, _helperMatrix, _helperRect, BlendMode.NONE);
    }

    private function renderBlur(light:Light, lightRect:Rectangle, shadowTexture:Texture, tmpTexture:Texture):Texture {
        if(light.edgeBlur == 0 && light.centerBlur == 0)
            return shadowTexture;

        var r:Number = light.radius;
        _helperRect.setTo(lightRect.width / 2 - r, lightRect.height / 2 - r, 2 * r, 2 * r);

        _textureProcessor.input = shadowTexture;
        _textureProcessor.output = tmpTexture;
        _textureProcessor.shader = _blurShader;

        _blurShader.minU = _helperRect.left / _textureProcessor.input.root.width;
        _blurShader.maxU = _helperRect.right / _textureProcessor.input.root.width;
        _blurShader.minV = _helperRect.top / _textureProcessor.input.root.height;
        _blurShader.maxV = _helperRect.bottom / _textureProcessor.input.root.height;

        _blurShader.edgeStrength    = light.edgeBlur;
        _blurShader.centerStrength  = light.centerBlur;
        _blurShader.pixelWidth      = 1 / _textureProcessor.input.root.width;
        _blurShader.pixelHeight     = 1 / _textureProcessor.input.root.height;

        var numPasses:int = _blurShader.passesNeeded;

        for(var pass:int = 0; pass < numPasses; ++pass) {
            _blurShader.pass = pass;

            _blurShader.type = FastGaussianBlurShader.HORIZONTAL;

            _textureProcessor.process(false, null, _helperRect, BlendMode.NONE);
            _textureProcessor.swap();

            _blurShader.type = FastGaussianBlurShader.VERTICAL;

            _textureProcessor.process(false, null, _helperRect, BlendMode.NONE);
            _textureProcessor.swap();
        }

        return _textureProcessor.input; // input is swapped with output, so return input
    }

    private function renderFinalShadow(light:Light, lightRect:Rectangle, shadowTexture:Texture, outputTexture:Texture):void {
        var r:Number = light.radius;
        _helperRect.setTo(lightRect.width / 2 - r, lightRect.height / 2 - r, 2 * r, 2 * r);

        _textureProcessor.input = shadowTexture;
        _textureProcessor.output = outputTexture;
        _textureProcessor.shader = _finalShadowShader;

        _finalShadowShader.minU = _helperRect.left / _textureProcessor.input.root.width;
        _finalShadowShader.maxU = _helperRect.right / _textureProcessor.input.root.width;
        _finalShadowShader.minV = _helperRect.top / _textureProcessor.input.root.height;
        _finalShadowShader.maxV = _helperRect.bottom / _textureProcessor.input.root.height;

        _helperMatrix.identity();
        _helperMatrix.translate(lightRect.x, lightRect.y);

        _textureProcessor.process(false, _helperMatrix, null, BlendMode.SCREEN);
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
