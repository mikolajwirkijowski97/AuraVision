#include <metal_stdlib>
#include <CoreImage/CoreImage.h>

using namespace metal;

// --- Constants & Helpers ---

constant float c_maxSteps = 10.0;

// Encodes coordinate and color data into a float4.
float4 EncodeData(float2 coord, float3 color) {
    float4 ret = float4(0.0);
    ret.xy = coord;
    ret.z = floor(color.x * 255.0) * 256.0 + floor(color.y * 255.0);
    ret.w = floor(color.z * 255.0);
    return ret;
}

// Decodes the packed data from a float4.
void DecodeData(float4 data, thread float2 &coord, thread float3 &color) {
    coord = data.xy;
    color.x = floor(data.z / 256.0) / 255.0;
    color.y = fmod(data.z, 256.0) / 255.0;
    color.z = fmod(data.w, 256.0) / 255.0;
}

// --- Kernels ---

extern "C" {

    // Prepares the initial seed map from a grayscale mask.
    float4 jfaSeedKernel(sampler mask, destination dest) {
        float2 currentCoordinate = dest.coord();
        float4 maskPixel = mask.sample(currentCoordinate);

        if (maskPixel.r > 0.3) {
            return EncodeData(currentCoordinate, float3(1.0, 0.0, 0.0));
        } else {
            return float4(0.0);
        }
    }
    // Performs a jfa step
    float4 jfaStepKernel(sampler src, float jfaLevel, destination dest) {
        float2 fragCoord = dest.coord();
        float level = clamp(jfaLevel, 0.0, c_maxSteps);
        float stepwidth = floor(exp2(c_maxSteps - level) + 0.5);

        float bestDistance = 9999.0;
        float2 bestCoord = float2(0.0);
        float3 bestColor = float3(0.0);

        for (int y = -1; y <= 1; ++y) {
            for (int x = -1; x <= 1; ++x) {
                float2 sampleCoord = fragCoord + float2(x, y) * stepwidth;
                float4 data = src.sample(sampleCoord);
                
                float2 seedCoord;
                float3 seedColor;
                DecodeData(data, seedCoord, seedColor);
                
                float dist = length(seedCoord - fragCoord);
                
                if ((seedCoord.x != 0.0 || seedCoord.y != 0.0) && dist < bestDistance) {
                    bestDistance = dist;
                    bestCoord = seedCoord;
                    bestColor = seedColor;
                }
            }
        }
        return EncodeData(bestCoord, bestColor);
    }
    // Convert result to a normalised b/w image
    float4 jfaDecodeKernel(sampler jfaOutput, float normalizationFactor, destination dest) { // <-- Corrected
        float2 fragCoord = dest.coord(); // <-- Corrected
        float4 data = jfaOutput.sample(fragCoord);
        
        float2 seedCoord;
        float3 seedColor;
        DecodeData(data, seedCoord, seedColor);
        
        float dist = length(seedCoord - fragCoord);
        float normalizedDist = clamp(dist / normalizationFactor, 0.0, 1.0);
        
        return float4(normalizedDist, normalizedDist, normalizedDist, 1.0);
    }

}
