//
//  MetalCIFilter.swift
//  LiveCameraSwiftUI
//
//  Created by Mikołaj Wirkijowski on 26/08/2025.
//

import CoreImage

/// A generalized CIFilter subclass for applying custom Metal CIColorKernels.
class MetalCIFilter: CIFilter {

    /// The input image to be processed by the filter.
    @objc dynamic var inputImage: CIImage?

    /// The custom Metal kernel that will be applied to the image.
    private let kernel: CIColorKernel

    /// An array of additional arguments to be passed to the kernel.
    private var arguments: [Any]

    /// Initializes a new filter with a specified Metal kernel and arguments.
    init(resourceName: String, functionName: String, arguments: [Any] = []) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "ci.metallib"),
              let data = try? Data(contentsOf: url) else {
            fatalError("Unable to load Metal library: \(resourceName).ci.metallib")
        }

        guard let metalKernel = try? CIColorKernel(functionName: functionName, fromMetalLibraryData: data) else {
            fatalError("Unable to create CIColorKernel with function name: \(functionName)")
        }

        self.kernel = metalKernel
        self.arguments = arguments
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else {
            return nil
        }

        // Prepend the input image to the arguments list, as it's always the first parameter for the kernel.
        let finalArguments = [inputImage as Any] + arguments

        return kernel.apply(
            extent: inputImage.extent,
            arguments: finalArguments
        )
    }
}
