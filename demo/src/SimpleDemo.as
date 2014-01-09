/**
 * User: booster
 * Date: 09/12/13
 * Time: 9:45
 */
package {
import flash.geom.Point;
import flash.geom.Rectangle;

import starling.animation.Juggler;
import starling.animation.Tween;

import starling.core.Starling;
import starling.display.BlendMode;
import starling.display.Image;
import starling.display.Quad;
import starling.display.Sprite;
import starling.events.Event;
import starling.events.Touch;
import starling.events.TouchEvent;
import starling.events.TouchPhase;
import starling.lighting.Light;
import starling.lighting.LightResolver;
import starling.textures.SubTexture;

public class SimpleDemo extends Sprite {
    private var _resolver:LightResolver;
    private var _shadowImage:Image;
    private var _raysAImage:Image;
    private var _raysBImage:Image;

    private var _castersParent:Sprite;

    public function SimpleDemo() {
        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
    }

    private function onAddedToStage(event:Event):void {
        this.width = 800;
        this.height = 600;

        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);

        _resolver = new LightResolver();

        _shadowImage        = new Image(new SubTexture(_resolver.shadowsTexture, new Rectangle(0, 0, 800, 600), true));
        _shadowImage.x      = 0;
        _shadowImage.y      = 0;
        _shadowImage.blendMode = BlendMode.MULTIPLY;

        _raysAImage         = new Image(_resolver.tempTextureA);
        _raysAImage.x       = 500;
        _raysAImage.y       = 20;

        _raysBImage         = new Image(_resolver.tempTextureB);
        //_raysBImage.x       = 500;
        //_raysBImage.y       = 20 + 256 + 20;
        _raysBImage.x       = 400 - 256/ 2;
        _raysBImage.y       = 300 - 256/ 2;
        _raysBImage.blendMode = BlendMode.MULTIPLY;
        //_raysBImage.width   *= 4;

        _castersParent      = new Sprite();
        _castersParent.x    = 400;
        _castersParent.y    = 300;

        createQuads(_castersParent, _resolver);

        var lightQuad:Quad  = new Quad(10, 10, 0xFFFF00);
        lightQuad.x         = 395;
        lightQuad.y         = 40; //295;

        addChild(lightQuad);

        var light1:Light    = new Light(5, 5, 100, lightQuad);
        //light1.attenuation  = 0;
        //light1.color        = 0xdeda12;
        light1.edgeBlur       = 2;
        light1.centerBlur     = 0;
        _resolver.addLight(light1);

        addChild(_shadowImage);
        //addChild(_raysAImage);
        //addChild(_raysBImage);

        addChild(_castersParent);

//        var tween:Tween = new Tween(light1, 5);
//        tween.animate("radius", 250);
//        tween.repeatCount = 0;
//        tween.reverse = true;
//        tween.repeatDelay = 0.5;
//        Starling.juggler.add(tween);

        addEventListener(Event.ENTER_FRAME, onEnterFrame);
        addEventListener(TouchEvent.TOUCH, onTouchEvent);

        this.touchable = true;
    }

    private function onTouchEvent(event:TouchEvent):void {
        var touch:Touch = event.getTouch(this, TouchPhase.MOVED);

        if(touch == null)
            return;

        _castersParent.x = touch.getLocation(this).x;
        _castersParent.y = touch.getLocation(this).y;
    }

    private function onEnterFrame(event:Event):void {
        _resolver.resolve();
    }

    private function createQuads(parent:Sprite, resolver:LightResolver):void {
/*
        var quad1:Quad  = new Quad(20, 20, 0xFF0000);
        quad1.x         = 10;
        quad1.y         = 20;

        var quad2:Quad  = new Quad(40, 20, 0x00FF00);
        quad2.x         = 300;
        quad2.y         = 180;

        var quad3:Quad  = new Quad(10, 50, 0x0000FF);
        quad3.x         = 220;
        quad3.y         = 240;

        parent.addChild(quad1);
        parent.addChild(quad2);
        parent.addChild(quad3);

        resolver.addShadowCaster(quad1);
        resolver.addShadowCaster(quad2);
        resolver.addShadowCaster(quad3);
*/

        var center:Point        = new Point(parent.width / 2, parent.height / 2);
        const distance:Number   = 80;
        const quads:int         = 9;
        const width:Number      = 20;
        const height:Number     = 20;

        for(var i:int = 0; i < quads; ++i) {
            var quad:Quad = new Quad(20, 20, 0xFF0000);
            var quadCenter:Point = Point.polar(distance, 1.7 * Math.PI / quads * i);
            quadCenter.offset(center.x, center.y);

            quad.x = quadCenter.x - width / 2;
            quad.y = quadCenter.y - height/ 2;

            parent.addChild(quad);
            resolver.addShadowCaster(quad);
        }
    }
}
}
