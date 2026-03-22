import SwiftUI
import AVFoundation
import AudioToolbox

struct BarcodeScannerView: View {
    let onScanned: (String) -> Void
    let onFailure: (BarcodeScannerError) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                BarcodeScannerRepresentable(
                    onScanned: { code in
                        onScanned(code)
                        dismiss()
                    },
                    onFailure: onFailure
                )
                .ignoresSafeArea()

                scannerOverlay
            }
            .background(.black)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalizer.string("common.close")) {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var scannerOverlay: some View {
        VStack(spacing: 0) {
            Text(AppLocalizer.string("search.scan.title"))
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top, 24)

            Text(AppLocalizer.string("search.scan.subtitle"))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 8)
                .padding(.horizontal, 32)

            Spacer()

            RoundedRectangle(cornerRadius: 24)
                .stroke(.white, lineWidth: 3)
                .frame(width: 260, height: 170)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.clear)
                )
                .overlay(alignment: .center) {
                    Rectangle()
                        .fill(.white.opacity(0.85))
                        .frame(height: 2)
                        .padding(.horizontal, 24)
                }

            Spacer()
        }
    }
}

enum BarcodeScannerError: LocalizedError {
    case cameraUnavailable
    case permissionDenied
    case configurationFailed

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return AppLocalizer.string("search.scan.error.unavailable")
        case .permissionDenied:
            return AppLocalizer.string("search.scan.error.permission")
        case .configurationFailed:
            return AppLocalizer.string("search.scan.error.configuration")
        }
    }
}

private struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    let onScanned: (String) -> Void
    let onFailure: (BarcodeScannerError) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        controller.onScanned = onScanned
        controller.onFailure = onFailure
        return controller
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {}
}

private final class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScanned: ((String) -> Void)?
    var onFailure: ((BarcodeScannerError) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didFinishScanning = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissionAndConfigure()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning && !didFinishScanning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }

    private func checkPermissionAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureSession()
                    } else {
                        self?.onFailure?(.permissionDenied)
                    }
                }
            }
        case .denied, .restricted:
            onFailure?(.permissionDenied)
        @unknown default:
            onFailure?(.cameraUnavailable)
        }
    }

    private func configureSession() {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            onFailure?(.cameraUnavailable)
            return
        }

        do {
            session.beginConfiguration()

            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            guard session.canAddInput(videoInput) else {
                session.commitConfiguration()
                onFailure?(.configurationFailed)
                return
            }
            session.addInput(videoInput)

            let metadataOutput = AVCaptureMetadataOutput()
            guard session.canAddOutput(metadataOutput) else {
                session.commitConfiguration()
                onFailure?(.configurationFailed)
                return
            }
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [
                .ean8, .ean13, .upce, .code128
            ]

            session.commitConfiguration()

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.insertSublayer(previewLayer, at: 0)
            self.previewLayer = previewLayer

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        } catch {
            session.commitConfiguration()
            onFailure?(.configurationFailed)
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didFinishScanning else { return }

        guard let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = readableObject.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !code.isEmpty else {
            return
        }

        didFinishScanning = true
        session.stopRunning()
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onScanned?(code)
    }
}
