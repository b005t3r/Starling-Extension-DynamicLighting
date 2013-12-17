/**
 * User: booster
 * Date: 11/12/13
 * Time: 14:26
 */
package starling.util {
import flash.display3D.Context3D;
import flash.display3D.Program3D;

public interface ITextureShader {
    function activate(context:Context3D):void
    function upload(context:Context3D):Program3D
    function deactivate(context:Context3D):void
}
}
