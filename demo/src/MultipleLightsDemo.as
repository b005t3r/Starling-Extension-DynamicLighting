/**
 * User: booster
 * Date: 08/01/14
 * Time: 10:43
 */
package {
import flash.geom.Point;

import starling.display.BlendMode;
import starling.display.Image;
import starling.display.Quad;
import starling.display.Sprite;
import starling.events.Event;
import starling.events.KeyboardEvent;
import starling.lighting.Light;
import starling.lighting.LightResolver;

public class MultipleLightsDemo extends Sprite {
    private var _resolver:LightResolver;
    private var _shadowImage:Image;
    private var _caster:Quad;
    private var _offset:Point = new Point();

    public function MultipleLightsDemo() {
        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
    }

    private function onAddedToStage(event:Event):void {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);

        _resolver = new LightResolver();

        const xMin:Number = 100, xMax:Number = 700, yMin:Number = 100, yMax:Number = 500, rMin:Number = 30, rMax:Number = 250;

        for(var i:int = 0; i < 10; ++i) {
            var x:Number = Math.random() * (xMax - xMin) + xMin;
            var y:Number = Math.random() * (yMax - yMin) + yMin;
            var radius:Number = Math.random() * (rMax - rMin) + rMin;
            var r:int = 191 + Math.random() * 64;
            var g:int = 191 + Math.random() * 64;
            var b:int = 191 + Math.random() * 64;
            var color:int = (r << 16) | (g << 8) | b;

            var quad:Quad = createLightQuad(x, y, color);
            var light:Light = createLight(quad, radius);

            addChild(quad);
            _resolver.addLight(light);
        }

        _shadowImage = new Image(_resolver.shadowsTexture);
        _shadowImage.blendMode = BlendMode.MULTIPLY;
        addChild(_shadowImage);

        _caster = new Quad(10, 10, 0xff0000);
        _caster.alignPivot();
        _caster.x = 400; _caster.y = 300;

        addChild(_caster);
        _resolver.addShadowCaster(_caster);

        addEventListener(Event.ENTER_FRAME, onEnterFrame);
        addEventListener(KeyboardEvent.KEY_DOWN, onKeyPressed);
        addEventListener(KeyboardEvent.KEY_UP, onKeyReleased);
    }

    private function onKeyPressed(event:KeyboardEvent):void {
        if('w'.charCodeAt() == event.charCode)
            _offset.y = -1;

        if('s'.charCodeAt() == event.charCode)
            _offset.y = 1;

        if('a'.charCodeAt() == event.charCode)
            _offset.x = -1;

        if('d'.charCodeAt() == event.charCode)
            _offset.x = 1;
    }

    private function onKeyReleased(event:KeyboardEvent):void {
        if('w'.charCodeAt() == event.charCode)
            _offset.y = 0;

        if('s'.charCodeAt() == event.charCode)
            _offset.y = 0;

        if('a'.charCodeAt() == event.charCode)
            _offset.x = 0;

        if('d'.charCodeAt() == event.charCode)
            _offset.x = 0;
    }

    private function onEnterFrame(event:Event):void {
        _caster.x += _offset.x;
        _caster.y += _offset.y;

        _resolver.resolve();
    }

    private function createLightQuad(x:Number, y:Number, color:int):Quad {
        var q:Quad = new Quad(5, 5, color);

        q.alignPivot();
        q.x = x;q.y = y;

        return q;
    }

    private function createLight(quad:Quad, radius:Number):Light {
        var l:Light = new Light(0, 0, radius, quad);

        l.color         = quad.color;
        l.edgeBlur      = 5;
        l.centerBlur    = 2;

        return l;
    }
}
}
