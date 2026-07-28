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

float getShapeSDFFromArray(int index, vec2 p) {
    int baseIndex = index * 6;
    float type = uShapeData[baseIndex];
    vec2 center = vec2(uShapeData[baseIndex + 1], uShapeData[baseIndex + 2]);
    vec2 size = vec2(uShapeData[baseIndex + 3], uShapeData[baseIndex + 4]);
    float cornerRadius = uShapeData[baseIndex + 5];

    return getShapeSDF(type, p, center, size, cornerRadius);
}

float sceneSDF(vec2 p, int numShapes, float blend) {
    if (numShapes == 0) {
        return 1e9;
    }

    float result = getShapeSDFFromArray(0, p);

    // Optimized: unroll for common cases (1-4 shapes), use loop for 5+ shapes
    if (numShapes <= 4) {
        // Fully unrolled for 1-4 shapes (covers 90%+ of use cases)
        if (numShapes >= 2) {
            float shapeSDF = getShapeSDFFromArray(1, p);
            result = smoothUnion(result, shapeSDF, blend);
        }
        if (numShapes >= 3) {
            float shapeSDF = getShapeSDFFromArray(2, p);
            result = smoothUnion(result, shapeSDF, blend);
        }
        if (numShapes >= 4) {
            float shapeSDF = getShapeSDFFromArray(3, p);
            result = smoothUnion(result, shapeSDF, blend);
        }
    } else {
        // Dynamic loop for 5+ shapes (uncommon cases)
        for (int i = 1; i < min(numShapes, MAX_SHAPES); i++) {
            float shapeSDF = getShapeSDFFromArray(i, p);
            result = smoothUnion(result, shapeSDF, blend);
        }
    }

    return result;
}
