/**
 * User: booster
 * Date: 09/01/14
 * Time: 16:00
 */
package {
import flash.geom.Point;
import flash.geom.Rectangle;

import starling.core.Starling;
import starling.display.BlendMode;

import starling.display.Image;
import starling.display.MovieClip;
import starling.display.Quad;

import starling.display.Sprite;
import starling.events.Event;
import starling.lighting.Light;
import starling.lighting.LightResolver;
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
        var shadow:Image            = new Image(_resolver.shadowsTexture);
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

        catWalk.x = 538;
        catWalk.y = 172;

        addChild(background);
        addChild(shadow);
        addChild(cat);
        addChild(catWalk);
        addChild(redLightQuad);
        addChild(blueLightQuad);

        shadow.blendMode = BlendMode.MULTIPLY;

        _resolver.addShadowCaster(cat);
        _resolver.addShadowCaster(catWalk);

        _resolver.addLight(redLight);
        _resolver.addLight(blueLight);

        Starling.juggler.add(catWalk);

        addEventListener(Event.ENTER_FRAME, onEnterFrame);
    }

    private function onEnterFrame(event:Event):void {
        _resolver.resolve();
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
        l.edgeBlur      = 6;
        l.centerBlur    = 1;

        return l;
    }
}
}
