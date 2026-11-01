import Foundation
import SwiftUI
import AVFoundation
import simd
import FitCheckShared

#if canImport(UIKit)
import UIKit
#else
import AppKit
public typealias UIView = NSView
public typealias UIViewController = NSViewController
public typealias UIViewRepresentable = NSViewRepresentable
#endif

#if canImport(RoomPlan)
import RoomPlan
#else
// Stubs for compiling and testing RoomCaptureController on macOS test runner
public struct CapturedRoomData {}

public final class CapturedRoomSurface: NSObject {
    public let identifier: UUID = UUID()
    public let category: String = "surface"
    public let dimensions: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
    public let transform: simd_float4x4 = matrix_identity_float4x4
}

public final class CapturedRoomObject: NSObject {
    public let identifier: UUID = UUID()
    public let category: String = "chair"
    public let dimensions: SIMD3<Float> = SIMD3<Float>(0.6, 0.6, 1.0)
    public let transform: simd_float4x4 = matrix_identity_float4x4
}

public final class CapturedRoom: NSObject {
    public let identifier: UUID = UUID()
    public let walls: [CapturedRoomSurface] = []
    public let doors: [CapturedRoomSurface] = []
    public let windows: [CapturedRoomSurface] = []
    public let openings: [CapturedRoomSurface] = []
    public let objects: [CapturedRoomObject] = []
}

public protocol RoomCaptureViewDelegate: AnyObject {
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool
    func captureView(didPresent processedResult: CapturedRoom, error: Error?)
}

public final class RoomCaptureSession: NSObject {
    public static var isSupported: Bool { false }
    public struct Configuration {}
    public func run(configuration: Configuration) {}
    public func stop() {}
}

public final class RoomCaptureView: UIView {
    public weak var delegate: RoomCaptureViewDelegate?
    public let captureSession: RoomCaptureSession = RoomCaptureSession()
    #if !canImport(UIKit)
    public override init(frame: NSRect) {
        super.init(frame: frame)
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    #endif
}
#endif

enum CapturePhase: Equatable {
    case idle
    case scanning
    case processing(startedAt: Date)
    case reviewing(room: CapturedRoom)
    case failed(message: String)

    static func == (lhs: CapturePhase, rhs: CapturePhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.scanning, .scanning): return true
        case (.processing, .processing): return true
        case (.reviewing(let a), .reviewing(let b)): return a.identifier == b.identifier
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

/// Dedicated per-session delegate proxy and capture view holder.
/// Owns an immutable session ID and invalidates all callbacks upon cancellation or supersession.
final class ScanSession: NSObject, RoomCaptureViewDelegate {
    let id: UUID
    private(set) var isCancelled: Bool = false
    private(set) var isCompleted: Bool = false
    private weak var controller: RoomCaptureController?
    let captureView: RoomCaptureView

    init(id: UUID = UUID(), controller: RoomCaptureController) {
        self.id = id
        self.controller = controller
        self.captureView = RoomCaptureView(frame: .zero)
        super.init()
        self.captureView.delegate = self
    }

    required init?(coder: NSCoder) {
        self.id = UUID()
        self.captureView = RoomCaptureView(frame: .zero)
        super.init()
    }

    func encode(with coder: NSCoder) {
        // Scan sessions are transient and not encoded.
    }

    func cancel() {
        isCancelled = true
        captureView.delegate = nil
        captureView.captureSession.stop()
    }

    var shouldAcceptCallback: Bool {
        guard !isCancelled, !isCompleted, let controller = controller, controller.activeSessionId == id else {
            return false
        }
        return true
    }

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        guard shouldAcceptCallback else {
            NSLog("[RoomPlan Lifecycle] Session \(id) shouldPresent rejected (cancelled, completed, or superseded)")
            return false
        }
        return controller?.session(self, shouldPresent: roomDataForProcessing, error: error) ?? false
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        guard shouldAcceptCallback else {
            NSLog("[RoomPlan Lifecycle] Session \(id) didPresent ignored (cancelled, completed, or superseded)")
            return
        }
        isCompleted = true
        controller?.session(self, didPresent: processedResult, error: error)
    }
}

final class RoomCaptureController: NSObject, ObservableObject {
    @Published var phase: CapturePhase = .idle
    @Published var message: String = "LiDAR capture stays on your phone. Share the room file to your Mac."
    @Published var exportURL: URL?
    @Published var isProcessingLongerThanExpected: Bool = false

    private(set) var activeSession: ScanSession?
    var activeSessionId: UUID? { activeSession?.id }
    private var processingTimer: Timer?

    var captureView: RoomCaptureView? {
        activeSession?.captureView
    }

    override init() {
        super.init()
    }

    func startScan() {
        // Explicitly cancel and invalidate any previous session
        activeSession?.cancel()
        activeSession = nil
        exportURL = nil
        isProcessingLongerThanExpected = false
        processingTimer?.invalidate()
        processingTimer = nil

        guard RoomCaptureSession.isSupported else {
            phase = .failed(message: "RoomPlan requires a LiDAR-equipped iPhone (Pro model). Simulator is not supported.")
            return
        }

        let newSession = ScanSession(controller: self)
        activeSession = newSession
        let sessionId = newSession.id

        AVCaptureDevice.requestAccess(for: .video) { [weak self, weak newSession] allowed in
            DispatchQueue.main.async {
                guard let self = self, let session = newSession, !session.isCancelled, self.activeSessionId == sessionId else {
                    NSLog("[RoomPlan Lifecycle] Ignored delayed camera permission for cancelled/superseded session \(sessionId)")
                    return
                }
                if allowed {
                    NSLog("[RoomPlan Lifecycle] Starting scan session \(sessionId)")
                    self.phase = .scanning
                    self.message = "Move slowly and scan all walls, openings, and furniture."
                    session.captureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
                } else {
                    self.phase = .failed(message: "Camera permission is required. Enable in Settings → RoomWise → Camera.")
                }
            }
        }
    }

    func finishScan() {
        guard case .scanning = phase, let session = activeSession, !session.isCancelled else { return }
        NSLog("[RoomPlan Lifecycle] Finishing scan session \(session.id); awaiting post-processing")
        phase = .processing(startedAt: Date())
        message = "Processing room geometry…"
        isProcessingLongerThanExpected = false

        // Start a 15-second recovery timer to inform the user if processing takes long
        processingTimer?.invalidate()
        processingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self, weak session] _ in
            DispatchQueue.main.async {
                guard let self = self, let session = session, !session.isCancelled, self.activeSessionId == session.id, case .processing = self.phase else { return }
                NSLog("[RoomPlan Lifecycle] Processing session \(session.id) taking longer than 15s; offering recovery")
                self.isProcessingLongerThanExpected = true
            }
        }

        session.captureView.captureSession.stop()
    }

    func cancelScan() {
        NSLog("[RoomPlan Lifecycle] Cancelling scan session \(activeSessionId?.uuidString ?? "none")")
        processingTimer?.invalidate()
        processingTimer = nil
        activeSession?.cancel()
        activeSession = nil
        phase = .idle
        message = "Scan cancelled. Existing room preserved."
        isProcessingLongerThanExpected = false
    }

    func discardReview() {
        NSLog("[RoomPlan Lifecycle] Discarded candidate scan \(activeSessionId?.uuidString ?? "none"); preserving previous room")
        activeSession?.cancel()
        activeSession = nil
        phase = .idle
        message = "Scan discarded. Previous room preserved."
        isProcessingLongerThanExpected = false
    }

    func setActiveSessionForTesting(_ session: ScanSession?) {
        self.activeSession = session
    }

    // MARK: - Delegate Callbacks from ScanSession

    func session(_ session: ScanSession, shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        guard !session.isCancelled, activeSessionId == session.id else {
            NSLog("[RoomPlan Lifecycle] Session \(session.id) shouldPresent ignored: session inactive")
            return false
        }
        if let error = error {
            NSLog("[RoomPlan Lifecycle] Session \(session.id) shouldPresent error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                guard !session.isCancelled, self.activeSessionId == session.id else { return }
                self.processingTimer?.invalidate()
                self.phase = .failed(message: "Scan processing failed: \(error.localizedDescription)")
            }
            return false
        }
        NSLog("[RoomPlan Lifecycle] Session \(session.id) presenting post-processing view")
        return true
    }

    func session(_ session: ScanSession, didPresent processedResult: CapturedRoom, error: Error?) {
        guard !session.isCancelled, activeSessionId == session.id else {
            NSLog("[RoomPlan Lifecycle] Session \(session.id) didPresent ignored: session inactive")
            return
        }
        DispatchQueue.main.async {
            guard !session.isCancelled, self.activeSessionId == session.id else {
                NSLog("[RoomPlan Lifecycle] Ignored late callback for superseded session \(session.id)")
                return
            }
            self.processingTimer?.invalidate()
            self.processingTimer = nil
            self.isProcessingLongerThanExpected = false

            if let error = error {
                NSLog("[RoomPlan Lifecycle] Session \(session.id) didPresent error: \(error.localizedDescription)")
                self.phase = .failed(message: "Scan post-processing failed: \(error.localizedDescription)")
            } else {
                NSLog("[RoomPlan Lifecycle] Session \(session.id) completed: \(processedResult.walls.count) walls, \(processedResult.objects.count) objects")
                self.phase = .reviewing(room: processedResult)
                self.message = "Scan ready. Review room geometry and tap 'Accept scan'."
            }
        }
    }

    func exportCurrentRoom(_ room: CapturedRoom) {
        exportURL = nil
        do {
            let raw = try RoomExporter.data(room)
            let jsonString = String(decoding: raw, as: UTF8.self)
            guard let _ = RoomPersistence.safeDecodeRoom(json: jsonString) else {
                message = "Room geometry failed validation. Previous room preserved."
                return
            }
            let validated = RoomBridge().validate(text: jsonString)
            guard !validated.isEmpty, let data = validated.data(using: .utf8) else {
                message = "Room geometry failed validation. Previous room preserved."
                return
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("RoomWise-room.json")
            try data.write(to: url, options: .atomic)
            exportURL = url
        } catch {
            message = "Could not export room file. Please try again."
        }
    }
}

#if canImport(UIKit)
struct CaptureViewRepresentable: UIViewRepresentable {
    let controller: RoomCaptureController

    func makeUIView(context: Context) -> UIView {
        if let view = controller.captureView {
            return view
        }
        let placeholder = UIView(frame: .zero)
        placeholder.backgroundColor = .black
        return placeholder
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#else
struct CaptureViewRepresentable: NSViewRepresentable {
    let controller: RoomCaptureController

    func makeNSView(context: Context) -> NSView {
        if let view = controller.captureView {
            return view
        }
        let placeholder = NSView(frame: .zero)
        return placeholder
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif

enum RoomExporter {
    static func element(_ id: UUID, _ kind: String, _ d: SIMD3<Float>, _ t: simd_float4x4) -> [String: Any] {
        ["id": id.uuidString, "kind": kind,
         "dimensions": ["width": Double(d.x), "height": Double(d.y), "depth": Double(d.z)],
         "pose": ["x": Double(t.columns.3.x), "z": Double(t.columns.3.z), "yaw": Double(atan2(t.columns.0.z, t.columns.0.x))],
         "transform": (0..<4).flatMap { col in (0..<4).map { row in Double(t[col][row]) } }]
    }

    static func data(_ r: CapturedRoom) throws -> Data {
        let surfaces = r.doors + r.windows + r.openings
        let json: [String: Any] = [
            "schemaVersion": 1, "units": "m", "coordinates": "right-handed:Y-up:floor-XZ:yaw-X-toward-Z",
            "name": "iPhone room scan", "capturedAt": ISO8601DateFormatter().string(from: Date()),
            "walls": r.walls.map { element($0.identifier, "wall", $0.dimensions, $0.transform) },
            "openings": surfaces.map { element($0.identifier, String(describing: $0.category), $0.dimensions, $0.transform) },
            "objects": r.objects.map { element($0.identifier, String(describing: $0.category), $0.dimensions, $0.transform) },
            "boundary": [], "boundaryComplete": false, "savedDemo": false
        ]
        return try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    }
}
