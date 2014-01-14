Starling-Extension-DynamicLighting
==================================

This is a Stage3D/Starling port of Catalin Zima's approach to rendering dynamic, pixel perfect shadows. This is entirely fragment shader based, which means you don't need to create any geometry for your shadow casters and any DisplayObject can be a shadow caster.

If you're interested in a detailed description of this method, go visit Catalin's website: http://www.catalinzima.com/2010/07/my-technique-for-the-shader-based-dynamic-2d-shadows/

A more efficient (and simpler) approach to this method (made using libGDX) can befound here (you should probably go with this method if you plan to use this technique in your game): https://github.com/mattdesl/lwjgl-basics/wiki/2D-Pixel-Perfect-Shadows

For a live demo, visit this page: http://b005t3r.github.io/Starling-Extension-DynamicLighting/
