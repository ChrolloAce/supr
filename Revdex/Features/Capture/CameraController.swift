import AVFoundation
import SwiftUI
import UIKit

/// Thin AVFoundation wrapper. Falls back cleanly on simulators with no camera.
@MainActor
final class CameraController: NSObject, ObservableObject {

    enum State: Equatable {
        case idle, ready, denied, unavailable
    }

    @Published private(set) var state: State = .idle
    @Published var zoom: CGFloat = 1
    @Published var torchOn = false
    @Published private(set) var position: AVCaptureDevice.Position = .back

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var configured = false
    private var captureHandler: ((UIImage?) -> Void)?
    private let queue = DispatchQueue(label: "revdex.camera")

    // MARK: Lifecycle

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    granted ? self?.configureAndRun() : (self?.state = .denied)
                }
            }
        default:
            state = .denied
        }
    }

    func stop() {
        guard configured else { return }
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureAndRun() {
        guard !configured else {
            queue.async { [session] in if !session.isRunning { session.startRunning() } }
            return
        }

        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: cam) else {
            state = .unavailable
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        device = cam
        configured = true
        state = .ready

        queue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    // MARK: Controls

    /// Highest factor this lens will actually do, capped so the image stays usable.
    var maxZoom: CGFloat {
        guard let device else { return 10 }
        return min(device.activeFormat.videoMaxZoomFactor, 25)
    }

    func setZoom(_ factor: CGFloat) {
        guard let device else { return }
        let clamped = max(1, min(factor, maxZoom))
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            zoom = clamped
        } catch { }
    }

    /// Front and back. Cars are almost always behind the phone, but people
    /// photograph their own car from the driver's seat too.
    var canFlip: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    func flip() {
        guard configured else { return }
        let next: AVCaptureDevice.Position = position == .back ? .front : .back
        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: next),
              let input = try? AVCaptureDeviceInput(device: cam) else { return }

        // Torch belongs to the old device, so it goes out with it.
        if torchOn { toggleTorch() }

        session.beginConfiguration()
        for existing in session.inputs { session.removeInput(existing) }
        if session.canAddInput(input) {
            session.addInput(input)
            device = cam
            position = next
        } else if let old = self.device,
                  let restore = try? AVCaptureDeviceInput(device: old),
                  session.canAddInput(restore) {
            session.addInput(restore)
        }
        session.commitConfiguration()

        zoom = 1
        setZoom(1)
    }

    func toggleTorch() {
        guard let device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            torchOn = device.torchMode == .on
            device.unlockForConfiguration()
        } catch { }
    }

    func focus(at point: CGPoint) {
        guard let device else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch { }
    }

    // MARK: Capture

    func capture(_ completion: @escaping (UIImage?) -> Void) {
        guard state == .ready, configured else {
            completion(nil)
            return
        }
        captureHandler = completion
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        Task { @MainActor in
            let handler = self.captureHandler
            self.captureHandler = nil
            handler?(image)
        }
    }
}

// MARK: - Preview layer

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) { }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
