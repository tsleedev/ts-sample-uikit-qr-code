//
//  QRCodeService.swift
//  TSQRCodeUIKitSample
//
//  Created by TAE SU LEE on 8/23/24.
//

import UIKit
import Photos

protocol QRCodeServiceProtocol {
    func generateQRCode(from string: String, logo: Data?) -> Data?
    func processQRCode(from imageData: Data) throws -> String
    func saveQRCodeToPhotoLibrary(_ imageData: Data, completion: @escaping (Result<Void, Error>) -> Void)
}

class QRCodeService: QRCodeServiceProtocol {
    func generateQRCode(from string: String, logo: Data?) -> Data? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        
        let data = string.data(using: .ascii)
        filter.setValue(data, forKey: "inputMessage")
        
        guard let ciImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledCIImage = ciImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else { return nil }
        
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Draw white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Draw QR code
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        
        // Create transparent area for logo
        let logoSize = CGSize(width: size.width * 0.2, height: size.height * 0.2) // 20% of QR code size
        let logoOrigin = CGPoint(x: (size.width - logoSize.width) / 2, y: (size.height - logoSize.height) / 2)
        let logoRect = CGRect(origin: logoOrigin, size: logoSize)
        
        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)
        context.fillEllipse(in: logoRect)
        context.setBlendMode(.normal)
        
        // Draw logo
        if let logo = logo, let logoImage = UIImage(data: logo) {
            logoImage.draw(in: logoRect)
        }
        
        guard let newImage = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        UIGraphicsEndImageContext()
        
        return newImage.pngData()
    }
    
    func generateQRCode(from string: String) -> Data? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        
        let data = string.data(using: .ascii)
        filter.setValue(data, forKey: "inputMessage")
        
        guard let ciImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledCIImage = ciImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else { return nil }
        
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.pngData()
    }

    func processQRCode(from imageData: Data) throws -> String {
        guard let ciImage = CIImage(data: imageData) else {
            throw NSError(domain: "QRCodeError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
        }
        
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage) ?? []
        
        guard let qrFeature = features.first as? CIQRCodeFeature,
              let messageString = qrFeature.messageString else {
            throw NSError(domain: "QRCodeError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No QR code found in the image"])
        }
        
        return messageString
    }
    
    func saveQRCodeToPhotoLibrary(_ imageData: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized, .limited:
                PHPhotoLibrary.shared().performChanges {
                    let options = PHAssetResourceCreationOptions()
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: imageData, options: options)
                } completionHandler: { success, error in
                    DispatchQueue.main.async {
                        if success {
                            completion(.success(()))
                        } else if let error = error {
                            completion(.failure(error))
                        } else {
                            completion(.failure(NSError(domain: "QRCodeError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred while saving image"])))
                        }
                    }
                }
            case .denied, .restricted:
                completion(.failure(NSError(domain: "QRCodeError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Permission to access photo library was denied"])))
            case .notDetermined:
                completion(.failure(NSError(domain: "QRCodeError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Photo library access not determined"])))
            @unknown default:
                completion(.failure(NSError(domain: "QRCodeError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unknown photo library access status"])))
            }
        }
    }
}
