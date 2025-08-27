//
//  AverageFrames.metal
//  LiveCameraSwiftUI
//
//  Created by Mikołaj Wirkijowski on 26/08/2025.
//
#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

extern "C" float4 averageFrames(coreimage::sample_t newPixelColor, coreimage::sample_t oldestPixelColor, coreimage::sample_t currentPixelColor, int frameCount, coreimage::destination destination)
{
    return currentPixelColor - oldestPixelColor/frameCount + newPixelColor/frameCount;
}
