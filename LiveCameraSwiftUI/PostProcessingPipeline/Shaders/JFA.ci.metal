#include <metal_stdlib>
#include <CoreImage/CoreImage.h>

using namespace metal;

// --- Constants & Helpers ---

constant float c_maxSteps = 10.0;

// Encodes coordinate and color data into a float4.
float4 EncodeData(float2 coord, float seedFlag) {
    // Store coord in RG, seed flag in B, keep alpha = 1.0 to avoid premultiplication issues.
    return float4(coord, seedFlag, 1.0);
}

// Decodes the packed data from a float4.
void DecodeData(float4 data, thread float2 &coord, thread float &seedFlag) {
    coord = data.xy;
    seedFlag = data.z;
}

// --- Kernels ---

extern "C" {
 
    // Prepares the initial seed map from a grayscale mask.
    // Accepts an imageSize so we can store normalized coordinates in [0,1]
    float4 jfaSeedKernel(sampler mask, float2 imageSize, destination dest) {
        float2 currentCoordinate = dest.coord();
        float4 maskPixel = mask.sample(currentCoordinate);

        if (maskPixel.r > 0.3) {
            float2 normalizedCoord = currentCoordinate / imageSize;
            return EncodeData(normalizedCoord, 1.0);
        } else {
            // Non-seed: keep alpha = 1.0 to avoid premultiplication affecting stored channels.
            return EncodeData(float2(0.0), 0.0);
        }
    }
    // Performs a jfa step
    // Now accepts the imageSize (in pixels) so distances are computed correctly
    float4 jfaStepKernel(sampler src, float jfaLevel, float2 imageSize, destination dest) {
        float2 fragCoord = dest.coord();
        float level = clamp(jfaLevel, 0.0, c_maxSteps);
        float stepwidth = floor(exp2(c_maxSteps - level) + 0.5);

        float bestDistance = 9999.0;
        float2 bestCoord = float2(0.0);
        float bestFlag = 0.0;

        for (int y = -1; y <= 1; ++y) {
            for (int x = -1; x <= 1; ++x) {
                float2 sampleCoord = fragCoord + float2(x, y) * stepwidth;
                float4 data = src.sample(sampleCoord);

                float2 seedCoord;   // normalized in [0,1]
                float seedFlag;
                DecodeData(data, seedCoord, seedFlag);

                if (seedFlag > 0.5) {
                    // Convert normalized seedCoord to pixel space for accurate distance
                    float2 seedPixelCoord = seedCoord * imageSize;
                    float dist = length(seedPixelCoord - fragCoord);

                    if (dist < bestDistance) {
                        bestDistance = dist;
                        bestCoord = seedCoord; // keep normalized coord packed
                        bestFlag = seedFlag;    // propagate flag
                    }
                }
            }
        }
        return EncodeData(bestCoord, bestFlag);
    }
    // Convert result to a normalised b/w image
    // Accepts normalizationFactor and imageSize to compute pixel distances correctly.
    float4 jfaDecodeKernel(sampler jfaOutput, float normalizationFactor, float2 imageSize, destination dest) {
        float2 fragCoord = dest.coord();
        float4 data = jfaOutput.sample(fragCoord);
        
        float2 seedCoord; // normalized
        float seedFlag;
        DecodeData(data, seedCoord, seedFlag);
        
        // Convert normalized coord back to pixel space before computing distance
        float2 seedPixelCoord = seedCoord * imageSize;
        float dist = length(seedPixelCoord - fragCoord);
        float normalizedDist = clamp(dist / normalizationFactor, 0.0, 1.0);
        
        return float4(normalizedDist, normalizedDist, normalizedDist, 1.0);
    }
 
}
