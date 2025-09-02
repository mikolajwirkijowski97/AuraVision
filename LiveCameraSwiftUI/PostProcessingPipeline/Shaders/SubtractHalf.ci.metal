//
//  SubtractShader.metal
//  LiveCameraSwiftUI
//
//  Created by Mikołaj Wirkijowski on 26/08/2025.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 subtractHalf(coreimage::sample_t pixelColor, coreimage::destination destination)
{
    return clamp(pixelColor - 0.5, 0.0, 1.0);
}
