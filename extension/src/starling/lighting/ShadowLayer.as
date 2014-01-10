/**
 * User: booster
 * Date: 08/12/13
 * Time: 12:05
 */
package starling.lighting {
import flash.display3D.Context3D;
import flash.display3D.Context3DProgramType;
import flash.display3D.Context3DVertexBufferFormat;
import flash.display3D.IndexBuffer3D;
import flash.display3D.VertexBuffer3D;
import flash.geom.Matrix;
import flash.geom.Rectangle;

import starling.core.RenderSupport;

import starling.core.Starling;
import starling.display.BlendMode;

import starling.display.DisplayObject;
import starling.errors.MissingContextError;
import starling.shaders.OverlayShader;
import starling.textures.RenderTexture;
import starling.textures.Texture;
import starling.utils.VertexData;

public class ShadowLayer extends DisplayObject {
    private static var sHelperMatrix:Matrix = new Matrix();

    private var _bottomLayer:DisplayObject;
    private var _bottomTexture:RenderTexture;
    private var _resolver:LightResolver;

    private var mVertexData:VertexData;
    private var mVertexBuffer:VertexBuffer3D;

    private var mIndexData:Vector.<uint>;
    private var mIndexBuffer:IndexBuffer3D;

    private var _overlayShader:OverlayShader = new OverlayShader();

    public function ShadowLayer(bottomLayer:DisplayObject, resolver:LightResolver) {
        _bottomLayer    = bottomLayer;
        _bottomTexture  = new RenderTexture(2048, 2048, false); // TODO: adjust for screen size

        _resolver       = resolver;

        createVertices(_bottomTexture);
        createBuffers();

        _overlayShader.topTexture = resolver.shadowsTexture;
        _overlayShader.upload(Starling.context);

        blendMode = BlendMode.NONE;
    }

    public override function dispose():void {
        if(mVertexBuffer) mVertexBuffer.dispose();
        if(mIndexBuffer)  mIndexBuffer.dispose();

        super.dispose();
    }

    public override function getBounds(targetSpace:DisplayObject, resultRect:Rectangle = null):Rectangle {
        if (resultRect == null) resultRect = new Rectangle();

        var transformationMatrix:Matrix = targetSpace == this
            ? null
            : getTransformationMatrix(targetSpace, sHelperMatrix)
        ;

        return mVertexData.getBounds(transformationMatrix, 0, -1, resultRect);
    }

    override public function render(support:RenderSupport, parentAlpha:Number):void {
        support.finishQuadBatch();
        support.raiseDrawCount();

        // draw bottom and top layers - this has to be done each frame
        _bottomTexture.draw(_bottomLayer);
        _resolver.resolve();

        var context:Context3D = Starling.context;
        if (context == null) throw new MissingContextError();

        // apply the current blendmode
        support.applyBlendMode(false);

        // activate program (shader) and set the required buffers / constants
        context.setProgram(_overlayShader.program);

        context.setVertexBufferAt(0, mVertexBuffer, VertexData.POSITION_OFFSET, Context3DVertexBufferFormat.FLOAT_2); // va0
        context.setVertexBufferAt(1, mVertexBuffer, VertexData.TEXCOORD_OFFSET, Context3DVertexBufferFormat.FLOAT_2); // va1

        context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, support.mvpMatrix3D, true);

        context.setTextureAt(0, _bottomTexture.base); // fs0

        // render
        _overlayShader.activate(context);
        context.drawTriangles(mIndexBuffer, 0, 2);
        _overlayShader.deactivate(context);

        // reset buffers
        context.setTextureAt(0, null);
        context.setVertexBufferAt(0, null);
        context.setVertexBufferAt(1, null);
    }

    private function createVertices(texture:Texture):void {
        var i:int;

        // create vertices
        if(mVertexData == null)
            mVertexData = new VertexData(4, texture.premultipliedAlpha);
        else
            mVertexData.setPremultipliedAlpha(texture.premultipliedAlpha);

        var w:Number = texture.width, h:Number = texture.height;

        mVertexData.setPosition(0, 0, 0);
        mVertexData.setPosition(1, w, 0);
        mVertexData.setPosition(2, 0, h);
        mVertexData.setPosition(3, w, h);

        mVertexData.setTexCoords(0, 0, 0);
        mVertexData.setTexCoords(1, 1, 0);
        mVertexData.setTexCoords(2, 0, 1);
        mVertexData.setTexCoords(3, 1, 1);

        texture.adjustVertexData(mVertexData, 0, 4);

        if(mIndexData != null)
            return;

        mIndexData = new <uint>[
            0, 1, 2,    // <-- 1st triangle
            1, 3, 2     // <-- 2nd triangle
        ];
    }

    /** Creates new vertex- and index-buffers and uploads our vertex- and index-data to those buffers. */
    private function createBuffers():void {
        var context:Context3D = Starling.context;
        if (context == null) throw new MissingContextError();

        if (mVertexBuffer) mVertexBuffer.dispose();
        if (mIndexBuffer)  mIndexBuffer.dispose();

        mVertexBuffer = context.createVertexBuffer(mVertexData.numVertices, VertexData.ELEMENTS_PER_VERTEX);
        mVertexBuffer.uploadFromVector(mVertexData.rawData, 0, mVertexData.numVertices);

        mIndexBuffer = context.createIndexBuffer(mIndexData.length);
        mIndexBuffer.uploadFromVector(mIndexData, 0, mIndexData.length);
    }
}
}
