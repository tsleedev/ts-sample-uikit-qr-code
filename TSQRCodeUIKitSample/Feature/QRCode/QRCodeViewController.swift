//
//  QRCodeViewController.swift
//  TSQRCodeUIKitSample
//
//  Created by TAE SU LEE on 8/23/24.
//

import UIKit
import AVFoundation
import Combine

class QRCodeViewController: UIViewController {
    private let viewModel = QRCodeViewModel()
    private var scannerService: QRScannerService?
    private var imagePickerManager: ImagePickerManager?
    
    private let textField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.placeholder = "Enter text for QR Code"
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let generateButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Generate QR Code", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let scanButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Scan QR Code", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let selectImageButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Select QR Code from Photos", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        
        scannerService = QRScannerService()
        scannerService?.delegate = self
        
        imagePickerManager = ImagePickerManager(presentationController: self, delegate: self)
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(textField)
        view.addSubview(generateButton)
        view.addSubview(scanButton)
        view.addSubview(selectImageButton)
        
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            generateButton.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 20),
            generateButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            scanButton.topAnchor.constraint(equalTo: generateButton.bottomAnchor, constant: 20),
            scanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            selectImageButton.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 20),
            selectImageButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        generateButton.addTarget(self, action: #selector(generateButtonTapped), for: .touchUpInside)
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        selectImageButton.addTarget(self, action: #selector(selectImageButtonTapped), for: .touchUpInside)
    }
    
    private func setupBindings() {
        viewModel.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.showAlert(message: message)
            }
            .store(in: &cancellables)
        
        viewModel.$successMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.showAlert(message: message)
            }
            .store(in: &cancellables)
        
        viewModel.$qrCodeGenerated
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.textField.text = ""
            }
            .store(in: &cancellables)
    }
    
    @objc private func generateButtonTapped() {
        view.endEditing(true)
        guard let text = textField.text else { return }
        viewModel.generateAndSaveQRCode.send(text)
    }
    
    @objc private func scanButtonTapped() {
        guard let captureSession = scannerService?.setupCaptureSession() else {
            showAlert(message: "Failed to setup camera for scanning.")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
        
        scannerService?.startScanning()
    }
    
    @objc private func selectImageButtonTapped() {
        imagePickerManager?.present()
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "알림", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

extension QRCodeViewController: QRScannerServiceDelegate {
    func qrScanningDidFail() {
        showAlert(message: "QR code scanning failed.")
    }
    
    func qrScanningSucceededWithCode(_ str: String?) {
        guard let code = str else { return }
        showAlert(message: "QR Code content: \(code)")
        scannerService?.stopScanning()
        previewLayer?.removeFromSuperlayer()
    }
    
    func qrScanningDidStop() {
        previewLayer?.removeFromSuperlayer()
    }
}

extension QRCodeViewController: ImagePickerDelegate {
    func didSelect(image: UIImage?) {
        guard let image = image,
              let imageData = image.pngData() else {
            showAlert(message: "Failed to get image")
            return
        }
        viewModel.processQRCodeImage.send(imageData)
    }
}
