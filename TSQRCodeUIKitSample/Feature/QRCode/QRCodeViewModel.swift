//
//  QRCodeViewModel.swift
//  TSQRCodeUIKitSample
//
//  Created by TAE SU LEE on 8/23/24.
//

import Foundation
import Combine

class QRCodeViewModel {
    private let qrCodeService: QRCodeServiceProtocol
    
    // Output
    @Published var qrCodeGenerated: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Input
    let generateAndSaveQRCode = PassthroughSubject<String, Never>()
    let processQRCodeImage = PassthroughSubject<Data, Never>()
    
    private var cancellables = Set<AnyCancellable>()
    
    init(qrCodeService: QRCodeServiceProtocol = QRCodeService()) {
        self.qrCodeService = qrCodeService
        setupBindings()
    }
    
    private func setupBindings() {
        generateAndSaveQRCode
            .filter { !$0.isEmpty }
            .flatMap { [weak self] text -> AnyPublisher<Result<Void, Error>, Never> in
                guard let self = self else { return Empty().eraseToAnyPublisher() }
                return Future { promise in
                    guard let qrCodeData = self.qrCodeService.generateQRCode(from: text, logo: self.updateLogoImageData(from: "TS")) else {
                        promise(.success(.failure(NSError(domain: "QRCodeError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to generate QR code"]))))
                        return
                    }
                    self.qrCodeService.saveQRCodeToPhotoLibrary(qrCodeData) { result in
                        promise(.success(result))
                    }
                }.eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                switch result {
                case .success:
                    self?.successMessage = "QR code generated and saved to photo library successfully."
                    self?.qrCodeGenerated = true
                case .failure(let error):
                    self?.errorMessage = "Failed to generate or save QR code: \(error.localizedDescription)"
                }
            }
            .store(in: &cancellables)
        
        generateAndSaveQRCode
            .filter { $0.isEmpty }
            .map { _ in "Please enter some text for the QR code." }
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        processQRCodeImage
            .tryMap { [weak self] data -> String in
                guard let self = self else { throw NSError(domain: "QRCodeError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Self is nil"]) }
                return try self.qrCodeService.processQRCode(from: data)
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] content in
                    self?.errorMessage = "QR Code content: \(content)"
                }
            )
            .store(in: &cancellables)
    }
}

#if DEBUG
import UIKit

private extension QRCodeViewModel {
    func updateLogoImageData(from text: String) -> Data? {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        
        // Draw circular clipping path
        context.addEllipse(in: CGRect(origin: .zero, size: size))
        context.clip()
        
        // Fill with white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 30),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle
        ]
        
        // Calculate text size
        let textSize = (text as NSString).boundingRect(
            with: CGSize(width: size.width, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: attrs,
            context: nil
        ).size
        
        // Calculate vertical position to center the text
        let textOriginY = (size.height - textSize.height) / 2
        
        let textRect = CGRect(x: 0, y: textOriginY, width: size.width, height: textSize.height)
        text.draw(with: textRect, options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        
        if let image = UIGraphicsGetImageFromCurrentImageContext() {
            return image.pngData()
        }
        return nil
    }
}
#endif
