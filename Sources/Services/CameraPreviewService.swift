import Cocoa
import AVFoundation
import SwiftUI
import Combine

public final class CameraPreviewService: ObservableObject {
    public static let shared = CameraPreviewService()
    
    @Published public var isRunning: Bool = false
    @Published public var isAuthorized: Bool = false
    @Published public var hasCamera: Bool = false
    
    public let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.keynotch.camerapreview", qos: .userInitiated)
    private var isConfigured = false
    
    private init() {
        checkInitialStatus()
    }
    
    private func checkInitialStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.isAuthorized = (status == .authorized)
        }
    }
    
    public func requestAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            DispatchQueue.main.async {
                self.isAuthorized = true
                completion(true)
            }
            return
        }
        
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    completion(granted)
                }
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isAuthorized = false
            completion(false)
        }
    }
    
    public func start() {
        requestAccessIfNeeded { [weak self] granted in
            guard let self = self, granted else { return }
            self.sessionQueue.async {
                self.configureSessionIfNeeded()
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                    DispatchQueue.main.async {
                        self.isRunning = true
                    }
                }
            }
        }
    }
    
    public func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
    }
    
    private func configureSessionIfNeeded() {
        guard !isConfigured else { return }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480
        
        var device: AVCaptureDevice?
        if #available(macOS 14.0, *) {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .external],
                mediaType: .video,
                position: .unspecified
            )
            device = discovery.devices.first
        } else {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
                mediaType: .video,
                position: .unspecified
            )
            device = discovery.devices.first
        }
        
        if device == nil {
            device = AVCaptureDevice.default(for: .video)
        }
        
        guard let camera = device,
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            DispatchQueue.main.async {
                self.hasCamera = false
            }
            return
        }
        
        captureSession.addInput(input)
        captureSession.commitConfiguration()
        
        isConfigured = true
        DispatchQueue.main.async {
            self.hasCamera = true
        }
    }
}

// MARK: - AppKit Video Preview Layer Wrapper

public struct CameraPreviewView: NSViewRepresentable {
    public init() {}
    
    public func makeNSView(context: Context) -> CameraPreviewNSView {
        return CameraPreviewNSView()
    }
    
    public func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.updatePreview()
    }
}

public final class CameraPreviewNSView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        setupPreviewLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.masksToBounds = true
        setupPreviewLayer()
    }
    
    private func setupPreviewLayer() {
        let session = CameraPreviewService.shared.captureSession
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.connection?.automaticallyAdjustsVideoMirroring = false
        layer.connection?.isVideoMirrored = true
        
        self.layer?.addSublayer(layer)
        self.previewLayer = layer
    }
    
    override public func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = bounds
        CATransaction.commit()
    }
    
    public func updatePreview() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = bounds
        CATransaction.commit()
    }
}
