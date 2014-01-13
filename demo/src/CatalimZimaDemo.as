/**
 * User: booster
 * Date: 09/01/14
 * Time: 16:00
 */
package {
import flash.geom.Point;
import flash.geom.Rectangle;

import starling.animation.Tween;

import starling.core.Starling;
import starling.display.BlendMode;

import starling.display.Image;
import starling.display.MovieClip;
import starling.display.Quad;

import starling.display.Sprite;
import starling.events.Event;
import starling.events.TouchEvent;
import starling.events.TouchPhase;
import starling.lighting.Light;
import starling.lighting.LightResolver;
import starling.lighting.ShadowLayer;
import starling.textures.SubTexture;
import starling.textures.Texture;

public class CatalimZimaDemo extends Sprite {
    [Embed(source="/tile.jpg")]
    public static const Tile:Class;

    [Embed(source="/cat4.png")]
    public static const Cat:Class;

    [Embed(source="/catWalk.png")]
    public static const CatWalk:Class;

    private var tileTexture:Texture;
    private var catTexture:Texture;
    private var catWalkTexture:Texture;

    private var _resolver:LightResolver;

    private var _overlayBottomLayer:Sprite;

    public function CatalimZimaDemo() {
        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
    }

    private function onAddedToStage(event:Event):void {
        tileTexture     = Texture.fromBitmap(new Tile(), false);
        catTexture      = Texture.fromBitmap(new Cat(), false);
        catWalkTexture  = Texture.fromBitmap(new CatWalk(), false);

        var catWalkAnim:Vector.<Texture> = new <Texture>[];

        var frameWidth:int = catWalkTexture.width / 14;
        var count:int = 14;
        for(var i:int = 0; i < count; i++) {
            var frameTex:SubTexture = new SubTexture(
                catWalkTexture,
                new Rectangle(i * frameWidth, 0, frameWidth, catWalkTexture.height)
            );

            catWalkAnim.push(frameTex);
        }

        _resolver                   = new LightResolver();
        var background:Image        = new Image(tileTexture);
        _overlayBottomLayer         = new Sprite();
        var shadow:ShadowLayer      = new ShadowLayer(_overlayBottomLayer, _resolver);
        var cat:Image               = new Image(catTexture);
        var catWalk:MovieClip       = new MovieClip(catWalkAnim, 23);
        var redLightQuad:Quad       = createLightQuad(276, 276, 0xff0000);
        var blueLightQuad:Quad      = createLightQuad(560, 156, 0x0000ff);
        var redLight:Light          = createLight(redLightQuad, 256);
        var blueLight:Light         = createLight(blueLightQuad, 256);

        tileTexture.repeat  = true;
        background.width    = 800;
        background.height   = 600;
        background.setTexCoords(1, new Point(800 / tileTexture.width, 0));
        background.setTexCoords(2, new Point(0, 600 / tileTexture.height));
        background.setTexCoords(3, new Point(800 / tileTexture.width, 600 / tileTexture.height));

        cat.alignPivot();
        cat.x = cat.width / 2; cat.y = cat.height / 2;

        catWalk.x = 538;
        catWalk.y = 172;

        _overlayBottomLayer.addChild(background);

        addChild(shadow);
        addChild(cat);
        addChild(catWalk);
        addChild(redLightQuad);
        addChild(blueLightQuad);

        _resolver.addShadowCaster(cat);
        _resolver.addShadowCaster(catWalk);

        _resolver.addLight(redLight);
        _resolver.addLight(blueLight);

        Starling.juggler.add(catWalk);

        addEventListener(TouchEvent.TOUCH, function(e:TouchEvent):void {
            if(e.getTouch(cat, TouchPhase.ENDED)) {
                var tweenCat:Tween = new Tween(cat, 7.5);
                tweenCat.animate("scaleX", 1.1);
                tweenCat.animate("scaleY", 1.1);
                tweenCat.animate("rotation", Math.PI * 2);
                tweenCat.repeatCount = 2;
                tweenCat.reverse = true;
                Starling.juggler.add(tweenCat);

                var tweenRed:Tween = new Tween(redLight, 0);
                tweenRed.animate("color", 0xffffff);
                tweenRed.reverse = true;
                tweenRed.repeatCount = 15 / 0.2 + 1;
                tweenRed.repeatDelay = 0.2;
                Starling.juggler.add(tweenRed);

                var tweenRedQuad:Tween = new Tween(redLightQuad, 0);
                tweenRedQuad.animate("color", 0xffffff);
                tweenRedQuad.reverse = true;
                tweenRedQuad.repeatCount = 15 / 0.2 + 1;
                tweenRedQuad.repeatDelay = 0.2;
                Starling.juggler.add(tweenRedQuad);
            }

            if(e.getTouch(catWalk, TouchPhase.ENDED)) {
                var tweenCatWalk:Tween = new Tween(catWalk, 10);
                var oldX:int = catWalk.x;
                var oldY:int = catWalk.y;
                tweenCatWalk.animate("x", -600);
                tweenCatWalk.animate("y", oldY + 400);
                tweenCatWalk.onComplete = function():void { catWalk.x = oldX; catWalk.y = oldY; };
                Starling.juggler.add(tweenCatWalk);

                var tweenBlue:Tween = new Tween(blueLight, 0);
                tweenBlue.animate("color", 0x00ff00);
                tweenBlue.reverse = true;
                tweenBlue.repeatCount = 10 / 0.2;
                tweenBlue.repeatDelay = 0.2;
                Starling.juggler.add(tweenBlue);

                var tweenBlueQuad:Tween = new Tween(blueLightQuad, 0);
                tweenBlueQuad.animate("color", 0x00ff00);
                tweenBlueQuad.reverse = true;
                tweenBlueQuad.repeatCount = 10 / 0.2;
                tweenBlueQuad.repeatDelay = 0.2;
                Starling.juggler.add(tweenBlueQuad);
            }
        });
    }

    private function createLightQuad(x:Number, y:Number, color:int):Quad {
        var q:Quad = new Quad(5, 5, color);

        q.alignPivot();
        q.x = x; q.y = y;

        return q;
    }

    private function createLight(quad:Quad, radius:Number):Light {
        var l:Light = new Light(quad.width / 2, quad.height / 2, radius, quad);

        l.color         = quad.color;
        l.edgeBlur      = 0;
        l.centerBlur    = 0;

        return l;
    }
}
}
