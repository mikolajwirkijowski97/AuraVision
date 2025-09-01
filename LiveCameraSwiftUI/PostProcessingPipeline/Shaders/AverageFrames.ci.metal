//
//  AverageFrames.metal
//  LiveCameraSwiftUI
//
//  Created by Mikołaj Wirkijowski on 26/08/2025.
//
#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

extern "C" float4 averageFrames(coreimage::sample_t newPixelColor, coreimage::sample_t currentPixelColor, float frameCount, coreimage::destination destination)
{
    float alpha = 1.0 / frameCount;
    return currentPixelColor*(1.0-alpha) + newPixelColor*alpha;
}
