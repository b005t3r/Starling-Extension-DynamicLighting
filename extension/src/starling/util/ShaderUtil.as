/**
 * User: booster
 * Date: 17/12/13
 * Time: 10:28
 */
package starling.util {
import com.barliesque.agal.EasierAGAL;
import com.barliesque.agal.IComponent;
import com.barliesque.agal.IRegister;
import com.barliesque.shaders.macro.Utils;

public class ShaderUtil extends EasierAGAL {
    /** Bring given UV (in xy components) to [-1, 1] range. */
    public static function uvToCartesian(u:IComponent, v:IComponent, minU:IComponent, maxU:IComponent, minV:IComponent, maxV:IComponent, temp:IComponent, one:IComponent, two:IComponent):void {
        comment("u = (u - minU) / (maxU - minU); // v -> [0, 1]");
        subtract(u, u, minU);
        move(temp, maxU);
        subtract(temp, temp, minU);
        divide(u, u, temp);

        comment("u = 2 * u - 1; // u -> [-1, 1]");
        multiply(u, u, two);
        subtract(u, u, one);

        comment("v = (v - minV) / (maxV - minV); // v -> [0, 1]");
        subtract(v, v, minV);
        move(temp, maxV);
        subtract(temp, temp, minV);
        divide(v, v, temp);

        comment("v = 2 * v - 1; // v -> [-1, 1]");
        multiply(v, v, two);
        subtract(v, v, one);
    }

    /** Bring given UV (in xy components) to [-1, 1] range. */
    public static function cartesianToUV(u:IComponent, v:IComponent, minU:IComponent, maxU:IComponent, minV:IComponent, maxV:IComponent, temp:IComponent, one:IComponent, two:IComponent):void {
        comment("u = (u + 1) / 2; // u -> [0, 1]");
        add(u, u, one);
        divide(u, u, two);

        comment("u = u * (maxU - minU) + minU; // u -> [minU, maxU]");
        move(temp, maxU);
        subtract(temp, temp, minU);
        multiply(temp, temp, u);
        add(u, temp, minU);

        comment("v = (v + 1) / 2; // v -> [0, 1]");
        add(v, v, one);
        divide(v, v, two);

        comment("v = v * (maxV - minV) + minV; // v -> [minV, maxV]");
        move(temp, maxV);
        subtract(temp, temp, minV);
        multiply(temp, temp, v);
        add(v, temp, minV);
    }

    /** Calculates distance from [0, 0]. Both x and y must be in [-1, 1]. */
    public static function distance(value:IComponent, x:IComponent, y:IComponent, tempX:IComponent, tempY:IComponent, zero:IComponent, one:IComponent, half:IComponent):void {
        multiply(tempX, x, x);
        multiply(tempY, y, y);

        add(tempX, tempX, tempY);
        squareRoot(tempX, tempX);

        Utils.clamp(tempX, tempX, zero, one);
        subtract(tempX, one, tempX);

        multiply(tempX, half, tempX);
        add(value, half, tempX);
    }

    /** Encodes distance from [0, 0] in cartesian space in by multiplying value from [0.5, 1], depending on its distance from the texture's center. */
    public static function encodeDistance(value:IComponent, x:IComponent, y:IComponent, tempX:IComponent, tempY:IComponent, zero:IComponent, half:IComponent, one:IComponent):void {
        multiply(tempX, x, x);
        multiply(tempY, y, y);

        add(tempX, tempX, tempY);
        squareRoot(tempX, tempX);

        Utils.clamp(tempX, tempX, zero, one);
        subtract(tempX, one, tempX);

        multiply(tempX, half, tempX);
        add(tempX, half, tempX);

        multiply(value, value, tempX);
    }

    /** Normalize value in [min,max] to [0, 1]. */
    public static function normalize(value:IComponent, min:IComponent, max:IComponent, temp:IComponent):void {
        move(temp, max);
        subtract(temp, temp, min);
        subtract(value, value, min);
        divide(value, value, temp);
    }

    /** Scale value in [0, 1] to [min, max]. */
    public static function scale(value:IComponent, min:IComponent, max:IComponent, temp:IComponent):void {
        move(temp, max);
        subtract(temp, temp, min);
        multiply(value, value, temp);
        add(value, value, min);
    }
}
}
