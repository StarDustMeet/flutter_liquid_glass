// Scene composition over the shape-data uniform.
//
// These functions read `uShapeData` directly rather than taking it as a
// parameter, and that is deliberate. GLSL passes array parameters by value, so
// spirv-cross lowers `sceneSDF(p, n, uShapeData, blend)` into
//
//     float param_2[96] = uShapeData;
//
// an array initializer. SkSL rejects that outright — "initializers are not
// permitted on arrays (or structs containing arrays)" — so every build
// targeting the Skia path failed to compile this shader and shipped without it.
// Reading the uniform directly also avoids copying 96 floats per call, and
// sceneSDF calls into it up to four times per pixel on the unrolled path.
//
// Include this AFTER the `uShapeData` uniform declaration. sdf.glsl carries the
// primitives and MAX_SHAPES and can still be included at the top.

/**
 * One shape from the uniform array, by LITERAL index.
 *
 * A macro rather than a function because SkSL requires every array index to
 * be a constant expression, and a function parameter is not one — even
 * getShapeSDFFromArray(0, p) computed `index * 6` at runtime inside the
 * callee and was rejected. Flutter builds an SkSL variant for the Skia
 * fallback on Android, so the whole build failed on it (StarDust: STA-463).
 *
 * Expand this only with a literal, never with a loop variable.
 */
#define LG_SHAPE_SDF(i, p) getShapeSDF(                       \
    uShapeData[(i) * 6],                                      \
    (p),                                                      \
    vec2(uShapeData[(i) * 6 + 1], uShapeData[(i) * 6 + 2]),   \
    vec2(uShapeData[(i) * 6 + 3], uShapeData[(i) * 6 + 4]),   \
    uShapeData[(i) * 6 + 5])

/**
 * Union of every active shape.
 *
 * Fully unrolled to MAX_SHAPES. The old version unrolled 1-4 and used a
 * dynamic loop beyond that; SkSL rejected the loop on three separate counts —
 * a non-constant bound, min(int, int), and the dynamic array index above.
 * Unrolling costs a comparison per unused slot and nothing else: the shape
 * evaluation itself stays behind the guard.
 */
float sceneSDF(vec2 p, int numShapes, float blend) {
    if (numShapes == 0) {
        return 1e9;
    }

    float result = LG_SHAPE_SDF(0, p);
    if (numShapes >= 2) { result = smoothUnion(result, LG_SHAPE_SDF(1, p), blend); }
    if (numShapes >= 3) { result = smoothUnion(result, LG_SHAPE_SDF(2, p), blend); }
    if (numShapes >= 4) { result = smoothUnion(result, LG_SHAPE_SDF(3, p), blend); }
    if (numShapes >= 5) { result = smoothUnion(result, LG_SHAPE_SDF(4, p), blend); }
    if (numShapes >= 6) { result = smoothUnion(result, LG_SHAPE_SDF(5, p), blend); }
    if (numShapes >= 7) { result = smoothUnion(result, LG_SHAPE_SDF(6, p), blend); }
    if (numShapes >= 8) { result = smoothUnion(result, LG_SHAPE_SDF(7, p), blend); }
    if (numShapes >= 9) { result = smoothUnion(result, LG_SHAPE_SDF(8, p), blend); }
    if (numShapes >= 10) { result = smoothUnion(result, LG_SHAPE_SDF(9, p), blend); }
    if (numShapes >= 11) { result = smoothUnion(result, LG_SHAPE_SDF(10, p), blend); }
    if (numShapes >= 12) { result = smoothUnion(result, LG_SHAPE_SDF(11, p), blend); }
    if (numShapes >= 13) { result = smoothUnion(result, LG_SHAPE_SDF(12, p), blend); }
    if (numShapes >= 14) { result = smoothUnion(result, LG_SHAPE_SDF(13, p), blend); }
    if (numShapes >= 15) { result = smoothUnion(result, LG_SHAPE_SDF(14, p), blend); }
    if (numShapes >= 16) { result = smoothUnion(result, LG_SHAPE_SDF(15, p), blend); }

    return result;
}

/**
 * Screen-space gradient of the scene SDF.
 *
 * Flutter compiles this shader for four targets. Metal, Vulkan and GLES all
 * accept dFdx/dFdy, but Android also builds an SkSL variant for the Skia
 * fallback, and that compiler rejects them outright — "no match for
 * dFdx(float)". The whole Android build failed on it (StarDust: STA-463).
 *
 * So the derivative stays where it is supported, and the fallback
 * reconstructs the same quantity with central differences on the SDF itself.
 *
 * Epsilon is one pixel: fragCoord is in pixels, and dividing the two-pixel
 * span by 2.0 * EPS yields SDF units per pixel — the same scale a hardware
 * derivative returns. Without that division the gradient would come out
 * roughly twice as long, and it is fed straight into normalize() alongside a
 * z term, so the lighting angle would shift.
 */
vec2 sceneGradient(vec2 p, float sd, int numShapes, float blend) {
#if defined(IMPELLER_TARGET_METAL) || defined(IMPELLER_TARGET_VULKAN) || defined(IMPELLER_TARGET_OPENGLES)
    return vec2(dFdx(sd), dFdy(sd));
#else
    const float EPS = 1.0;
    float px = sceneSDF(p + vec2(EPS, 0.0), numShapes, blend)
             - sceneSDF(p - vec2(EPS, 0.0), numShapes, blend);
    float py = sceneSDF(p + vec2(0.0, EPS), numShapes, blend)
             - sceneSDF(p - vec2(0.0, EPS), numShapes, blend);
    return vec2(px, py) / (2.0 * EPS);
#endif
}
