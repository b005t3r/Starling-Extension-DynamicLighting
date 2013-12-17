/**
 * User: booster
 * Date: 10/12/13
 * Time: 12:50
 */
package starling.util {
import com.barliesque.agal.EasierAGAL;
import com.barliesque.agal.TextureFlag;

import flash.display3D.Context3D;

public class RenderTextureShader extends EasierAGAL implements ITextureShader {
    public function RenderTextureShader(debug:Boolean = true, assemblyDebug:Boolean = false) {
        super(debug, assemblyDebug);
    }

    public function activate(context:Context3D):void { }

    public function deactivate(context:Context3D):void { }

    override protected function _vertexShader():void {
        comment("Apply a 4x4 matrix to transform vertices to clip-space");
        multiply4x4(OUTPUT, ATTRIBUTE[0], CONST[0]);

        comment("Pass uv coordinates to fragment shader");
        move(VARYING[0], ATTRIBUTE[1]);
    }

    override protected function _fragmentShader():void {
        comment("Use UV coordinates passed from vertex shader to sample the texture");
        sampleTexture(TEMP[1], VARYING[0], SAMPLER[0], [TextureFlag.TYPE_2D, TextureFlag.MODE_CLAMP, TextureFlag.FILTER_NEAREST, TextureFlag.MIP_NO]);
        move(OUTPUT, TEMP[1]);
    }
}
}
