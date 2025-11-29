import SwiftUI
import AVFoundation
import Vision
internal import Combine

// MARK: - Main View
struct ContentView: View {
    @StateObject private var scrollController = ScrollController()
    @State private var text: String = """
    # Gesture Controlled Notebook
    
    Welcome! This notebook allows you to scroll using hand gestures detected by your front camera.
    
    Instructions:
    1. Hold your hand up to the front camera.
    2. Raise your index finger (point up).
    3. Move your finger to the TOP of the screen to scroll UP.
    4. Move your finger to the BOTTOM of the screen to scroll DOWN.
    5. Keep your finger in the MIDDLE to STOP scrolling.
    
    ---
    
    (Placeholder text for scrolling demonstration)
    
    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
    
    Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
    
    Chapter 1: The Beginning
    
    The quick brown fox jumps over the lazy dog. It was a dark and stormy night. The rain fell in torrents, except at occasional intervals, when it was checked by a violent gust of wind which swept up the streets (for it is in London that our scene lies), rattling along the housetops, and fiercely agitating the scanty flame of the lamps that struggled against the darkness.
    
    Chapter 2: The Journey
    
    Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit.
    
    (Keep scrolling down...)
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    Middle of the document.
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    Almost there...
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    End of the document.
    """

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // The Scrollable Text Editor
            ScrollableTextView(text: $text, scrollSpeed: $scrollController.scrollSpeed)
                .edgesIgnoringSafeArea(.all)

            // Camera Preview Overlay (for user feedback)
            CameraPreviewView(session: scrollController.captureSession)
                .frame(width: 120, height: 160)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor(for: scrollController.scrollSpeed), lineWidth: 4)
                )
                .padding()
                .shadow(radius: 10)
            
            // Debug / Status Text
            VStack {
                Spacer()
                Text(statusText(speed: scrollController.scrollSpeed))
                    .font(.caption)
                    .padding(6)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 180) // Above the camera view
                    .padding(.trailing, 20)
            }
            
            // Error Message Overlay
            if let errorMessage = scrollController.errorMessage {
                VStack {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                        .padding()
                    Spacer()
                }
            }
        }
        .onAppear {
            scrollController.checkPermissionsAndStart()
        }
        .onDisappear {
            // Stop camera when view disappears to save resources
            if scrollController.captureSession.isRunning {
                scrollController.captureSession.stopRunning()
            }
        }
    }
    
    func borderColor(for speed: CGFloat) -> Color {
        if speed > 0 { return .green }      // Scrolling down
        if speed < 0 { return .orange }     // Scrolling up
        return .gray                        // Neutral
    }
    
    func statusText(speed: CGFloat) -> String {
        if speed > 0 { return "Scrolling Down" }
        if speed < 0 { return "Scrolling Up" }
        return "Neutral"
    }
}

// MARK: - Scroll Logic & Camera Controller
class ScrollController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var objectWillChange: ObservableObjectPublisher
    
    @Published var scrollSpeed: CGFloat = 0.0 // Negative = Up, Positive = Down, 0 = Stop
    @Published var permissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    // Config
    private let scrollThresholdTop: CGFloat = 0.2    // Top 20% of screen triggers scroll up
    private let scrollThresholdBottom: CGFloat = 0.8 // Bottom 20% of screen triggers scroll down
    private let maxScrollSpeed: CGFloat = 15.0
    
    override init() {
        super.init()
        permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    deinit {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    func checkPermissionsAndStart() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        permissionStatus = status
        
        switch status {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
                    if granted {
                        self.setupCamera()
                    } else {
                        self.errorMessage = "Camera permission is required for gesture control"
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "Camera permission denied. Please enable it in Settings."
        @unknown default:
            errorMessage = "Unknown camera permission status"
        }
    }
    
    private func setupCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            
            // Use front camera
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                DispatchQueue.main.async { self.errorMessage = "Front camera not available" }
                self.captureSession.commitConfiguration()
                return
            }
            
            guard let input = try? AVCaptureDeviceInput(device: device) else {
                DispatchQueue.main.async { self.errorMessage = "Failed to create camera input" }
                self.captureSession.commitConfiguration()
                return
            }
            
            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            } else {
                DispatchQueue.main.async { self.errorMessage = "Cannot add camera input to session" }
                self.captureSession.commitConfiguration()
                return
            }
            
            // Output setup
            self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            } else {
                DispatchQueue.main.async { self.errorMessage = "Cannot add video output to session" }
                self.captureSession.commitConfiguration()
                return
            }
            
            self.captureSession.commitConfiguration()
            
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    // Delegate: Process Frames
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .leftMirrored, options: [:])
        
        let handPoseRequest = VNDetectHumanHandPoseRequest()
        handPoseRequest.maximumHandCount = 1
        
        do {
            try handler.perform([handPoseRequest])
            
            guard let hand = handPoseRequest.results?.first else {
                // No hand detected, stop scrolling
                DispatchQueue.main.async { self.scrollSpeed = 0 }
                return
            }
            
            // Get Index Finger Tip
            // Note: Vision coordinates are normalized (0,0) bottom-left to (1,1) top-right
            let indexFingerTip = try hand.recognizedPoint(.indexTip)
            
            if indexFingerTip.confidence > 0.3 {
                processFingerPosition(y: indexFingerTip.location.y)
            }
            
        } catch {
            // Vision errors are typically non-critical (e.g., no hand detected)
            // Only log significant errors, don't update UI for every frame
            if let visionError = error as? VNError, visionError.code != .requestCancelled {
                DispatchQueue.main.async { [weak self] in
                    // Only update error message for persistent issues
                    if self?.errorMessage == nil {
                        self?.errorMessage = "Vision processing error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func processFingerPosition(y: CGFloat) {
        // Y is normalized: 0.0 (bottom) to 1.0 (top)
        // Note: In Vision for camera, Y usually increases upwards.
        
        DispatchQueue.main.async {
            // Logic:
            // High Y (near 1.0) -> Top of screen -> Scroll Up (negative offset)
            // Low Y (near 0.0) -> Bottom of screen -> Scroll Down (positive offset)
            
            if y > (1.0 - self.scrollThresholdTop) {
                // Hand is at the top, scroll content DOWN to see previous
                // Wait, "Scroll Up" usually means content moves down.
                // Let's map Top Screen Area -> Scroll UP (view move down) -> negative offset usually in scrollview logic, but let's see logic below.
                
                // Let's standardise:
                // Finger High (Top) -> Scroll Up (Move content down) -> Speed < 0
                // Finger Low (Bottom) -> Scroll Down (Move content up) -> Speed > 0
                
                let intensity = (y - (1.0 - self.scrollThresholdTop)) / self.scrollThresholdTop
                self.scrollSpeed = -self.maxScrollSpeed * min(1.0, max(0.0, CGFloat(intensity)))
                
            } else if y < self.scrollThresholdBottom {
                // Hand is at bottom
                // Normalize intensity: when y=0 (bottom), intensity=1; when y=threshold, intensity=0
                let intensity = (self.scrollThresholdBottom - y) / self.scrollThresholdBottom
                self.scrollSpeed = self.maxScrollSpeed * min(1.0, max(0.0, intensity))
                
            } else {
                // Neutral zone
                self.scrollSpeed = 0
            }
        }
    }
}

// MARK: - UIKit Wrapper for TextView
// We use UITextView because programmatic scrolling is smoother than SwiftUI's ScrollViewReader
struct ScrollableTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var scrollSpeed: CGFloat
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.text = text
        textView.delegate = context.coordinator
        
        // Store reference to textView in coordinator for timer updates
        context.coordinator.textView = textView
        
        // Capture coordinator weakly to prevent retain cycle
        // Note: We capture the coordinator instance, not the context struct
        let coordinator = context.coordinator
        
        // Setup timer to handle smooth scrolling based on speed
        let timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak coordinator] _ in
            guard let coordinator = coordinator,
                  let textView = coordinator.textView else { return }
            coordinator.updateScrollPosition(textView: textView)
        }
        RunLoop.main.add(timer, forMode: .common)
        context.coordinator.scrollTimer = timer
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        context.coordinator.currentScrollSpeed = scrollSpeed
        context.coordinator.textView = uiView
        context.coordinator.parent = self
    }
    
    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        coordinator.invalidateTimer()
        coordinator.textView = nil
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: ScrollableTextView
        var currentScrollSpeed: CGFloat = 0.0
        var scrollTimer: Timer?
        weak var textView: UITextView?
        
        init(parent: ScrollableTextView) {
            self.parent = parent
        }
        
        func invalidateTimer() {
            scrollTimer?.invalidate()
            scrollTimer = nil
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        func updateScrollPosition(textView: UITextView) {
            guard currentScrollSpeed != 0 else { return }
            
            let newOffset = textView.contentOffset.y + currentScrollSpeed
            
            // Boundary checks - handle case where content is smaller than view
            let contentHeight = textView.contentSize.height
            let viewHeight = textView.bounds.height
            let maxOffset = max(0, contentHeight - viewHeight)
            
            // Only clamp if there's actually scrollable content
            let clampedOffset: CGFloat
            if maxOffset > 0 {
                clampedOffset = min(max(0, newOffset), maxOffset)
            } else {
                // Content fits in view, no scrolling needed
                clampedOffset = 0
            }
            
            textView.setContentOffset(CGPoint(x: 0, y: clampedOffset), animated: false)
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    // Custom UIView subclass to handle layout updates automatically
    class PreviewView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer? {
            return layer.sublayers?.first as? AVCaptureVideoPreviewLayer
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // No need to manually update frame here, layoutSubviews handles it
    }
    
    static func dismantleUIView(_ uiView: PreviewView, coordinator: Coordinator) {
        uiView.previewLayer?.removeFromSuperlayer()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        // No need to store references manually anymore
    }
}

