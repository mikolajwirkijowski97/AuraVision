//
//  SubtractShader.metal
//  LiveCameraSwiftUI
//
//  Created by Mikołaj Wirkijowski on 26/08/2025.
//

#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h>

extern "C" float4 subtractHalf(coreimage::sample_t pixelColor, coreimage::destination destination)
{
    return clamp(pixelColor - 0.5, 0.0, 1.0);
}
