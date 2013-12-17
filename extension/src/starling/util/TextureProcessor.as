/**
 * User: booster
 * Date: 09/12/13
 * Time: 15:05
 */
package starling.util {
import com.barliesque.agal.EasyBase;

import flash.display.BlendMode;
import flash.display3D.Context3D;
import flash.display3D.Context3DProgramType;
import flash.display3D.Context3DVertexBufferFormat;
import flash.display3D.IndexBuffer3D;
import flash.display3D.VertexBuffer3D;
import flash.geom.Matrix;
import flash.geom.Matrix3D;
import flash.geom.Rectangle;
import flash.geom.Rectangle;

import starling.core.RenderSupport;
import starling.core.Starling;
import starling.errors.MissingContextError;
import starling.textures.Texture;
import starling.utils.VertexData;

public class TextureProcessor {
    // helper objects (to avoid temporary objects)
    //private static var sRenderAlpha:Vector.<Number>  = new <Number>[1.0, 1.0, 1.0, 1.0];
    private static var _clipRect:Rectangle      = new Rectangle();
    private static var _helperMatrix:Matrix3D   = new Matrix3D();

    private var _input:Texture;
    private var _output:Texture;
    private var _shader:ITextureShader;

    // vertex data
    private var mVertexData:VertexData;
    private var mVertexBuffer:VertexBuffer3D;

    // index data
    private var mIndexData:Vector.<uint>;
    private var mIndexBuffer:IndexBuffer3D;

    private var _renderSupport:RenderSupport = new RenderSupport();

    public function TextureProcessor() {
    }

    public function get input():Texture { return _input; }
    public function set input(value:Texture):void {
        _input = value;

        createVertices(value);
        createBuffers();
    }

    public function get output():Texture { return _output; }
    public function set output(value:Texture):void {
        _output = value;
    }

    public function get shader():ITextureShader { return _shader; }
    public function set shader(value:ITextureShader):void {
        if(_shader == value)
            return;

        _shader = value;
    }

    public function swap():void {
        var tmp:Texture = input;
        input           = output;
        output          = tmp;
    }

    public function process(clearOutput:Boolean = true, matrix:Matrix = null, clipRect:Rectangle = null, blendMode:String = BlendMode.NORMAL):void {
        if(_output == null)
            throw new UninitializedError("output texture must be set");

        if(_input.root == _output.root)
            throw new UninitializedError("input cannot be used as output");

        var context:Context3D = Starling.context;

        if(context == null)
            throw new MissingContextError();

        var pma:Boolean = mVertexData.premultipliedAlpha;

        //sRenderAlpha[0] = sRenderAlpha[1] = sRenderAlpha[2] = pma ? alpha : 1.0;
        //sRenderAlpha[3] = alpha;

        var rootWidth:Number  = _output.root.width;
        var rootHeight:Number = _output.root.height;

        if(clipRect == null)    _clipRect.setTo(0, 0, _output.width, _output.height);
        else                    _clipRect.setTo(clipRect.x, clipRect.y, clipRect.width, clipRect.height);

        // render to output texture
        _renderSupport.renderTarget = _output;

        if(clearOutput)
            _renderSupport.clear();

        // setup ouuput regions for rendering
        _renderSupport.loadIdentity();
        _renderSupport.setOrthographicProjection(0, 0, rootWidth, rootHeight);
        _renderSupport.pushClipRect(_clipRect);

        // set blend mode
        _renderSupport.blendMode = blendMode;
        _renderSupport.applyBlendMode(pma);

        // transform input
        if(matrix != null)
            _renderSupport.prependMatrix(matrix);

        // activate program (shader) and set the required buffers, constants, texture
        context.setProgram(_shader.upload(context));

        context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, _renderSupport.mvpMatrix3D, true); //vc0
        //context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 4, sRenderAlpha, 1);

        context.setTextureAt(0, _input.base); // fs0

        context.setVertexBufferAt(0, mVertexBuffer, VertexData.POSITION_OFFSET, Context3DVertexBufferFormat.FLOAT_2); // va0
        context.setVertexBufferAt(1, mVertexBuffer, VertexData.TEXCOORD_OFFSET, Context3DVertexBufferFormat.FLOAT_2); // va1

        // render
        _shader.activate(context);
        context.drawTriangles(mIndexBuffer, 0, 2);
        _shader.deactivate(context);

        // reset buffers
        context.setTextureAt(0, null);
        context.setVertexBufferAt(0, null);
        context.setVertexBufferAt(1, null);

        _renderSupport.renderTarget = null;
        _renderSupport.popClipRect();
    }

    /** Creates new vertex- and index-data matching the input texture's size. */
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
