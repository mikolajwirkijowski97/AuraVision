//
//  JFADistance.ci.metal
//  LiveCameraSwiftUI
//
//  Jump Flood Algorithm (JFA) distance map for a binary mask.
//  Assumptions:
//   - Any mask pixel with max(R,G,B) > threshold is considered "occupied" (seed).
//   - Produces an unsigned distance field (absolute value of SDF) as a grayscale image.
//   - Use with multiple passes: initSeeds -> repeat jfaStep for powers of two -> jfaDistance finalize.
//
//  Notes:
//   - Core Image Metal kernels: use destination.coord() to get pixel-space coords.
//   - Sampler coordinates are in pixel space in CI Metal.
//   - No destCoord() in MSL; destination is used instead.
//
//  Created by Mikołaj Wirkijowski
//

#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

constant float INF_SEED = 1.0e9f;

// Helper: checks whether a seed coordinate is valid.
inline bool is_valid_seed(float2 s) {
    return all(s < float2(INF_SEED * 0.5f));
}

// Kernel 1: Initialize seed coordinates from a thresholded mask.
// Input:  mask (sampler)
// Params: threshold - values with max(rgb) > threshold are seeds
// Output: RG = seed coordinate (x,y) for nearest occupied pixel, or INF if none.
//         BA = unused (0,1)
extern "C" float4 jfaInitSeeds(coreimage::sampler mask,
                               float threshold,
                               coreimage::destination dest)
{
    float2 p = dest.coord();
    float4 m = mask.sample(p);

    float maxRGB = max(m.r, max(m.g, m.b));
    bool occupied = maxRGB > threshold;

    float2 seed = occupied ? p : float2(INF_SEED, INF_SEED);
    return float4(seed, 0.0f, 1.0f);
}

// Kernel 2: One Jump Flood step with bounds checking.
// Input:  seeds (sampler) from previous pass storing RG = nearest seed coord
// Params: step - jump distance for this pass
//         imgSize - image size in pixels to clamp neighbor sampling
// Output: updated seed coords in RG for current pixel
extern "C" float4 jfaStep(coreimage::sampler seeds,
                          float step,
                          float2 imgSize,
                          coreimage::destination dest)
{
    float2 p = dest.coord();

    // Current best
    float2 best = seeds.sample(p).rg;
    float bestDist = is_valid_seed(best) ? length(p - best) : INFINITY;

    // Examine 8-neighborhood at the given jump distance
    for (int dy = -1; dy <= 1; ++dy) {
        for (int dx = -1; dx <= 1; ++dx) {
            if (dx == 0 && dy == 0) continue;

            float2 nCoord = p + float2((float)dx, (float)dy) * step;

            // Bounds check to avoid sampling outside and getting invalid zeros
            if (nCoord.x < 0.0f || nCoord.y < 0.0f ||
                nCoord.x >= imgSize.x || nCoord.y >= imgSize.y) {
                continue;
            }

            float2 cand = seeds.sample(nCoord).rg;

            if (is_valid_seed(cand)) {
                float d = length(p - cand);
                if (d < bestDist) {
                    bestDist = d;
                    best = cand;
                }
            }
        }
    }

    if (!is_valid_seed(best)) {
        best = float2(INF_SEED, INF_SEED);
    }

    return float4(best, 0.0f, 1.0f);
}

// Kernel 3: Finalize to grayscale distance map (unsigned/absolute).
// Input:  seeds (sampler) with RG = nearest seed coord from last step
// Params: maxDistance - normalization factor (e.g., image diagonal)
// Output: grayscale value where 0 = on seed, 1 = farthest away
extern "C" float4 jfaDistance(coreimage::sampler seeds,
                              float maxDistance,
                              coreimage::destination dest)
{
    float2 p = dest.coord();
    float2 seed = seeds.sample(p).rg;

    float d = is_valid_seed(seed) ? length(p - seed) : maxDistance;
    float v = clamp(d / maxDistance, 0.0f, 1.0f);

    return float4(v, v, v, 1.0f);
}