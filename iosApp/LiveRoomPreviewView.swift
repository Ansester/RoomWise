import SwiftUI
import ARKit
import AVFoundation
import FitCheckShared

/// Persistent while browsing. The same product drives both the room drawing and AR node.
struct LiveRoomPreviewView: View {
    let room: Room
    let product: Product?
    @Binding var pose: Pose
    let previewPaused: Bool
    let pairedStatus: String?
    let onPoseChange: (Pose) -> Void
    @State private var cameraMode = false
    @State private var cameraAllowed = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    private var dimensions: Dimensions? { previewPaused ? nil : product?.previewSize() }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Label(cameraMode ? "Live room preview" : "Room preview", systemImage: cameraMode ? "arkit" : "cube.transparent")
                    .font(.caption.bold())
                Spacer()
                Button(cameraMode ? "Room view" : "Camera AR") {
                    cameraMode.toggle()
                    if cameraMode && ARWorldTrackingConfiguration.isSupported {
                        Task { cameraAllowed = await AVCaptureDevice.requestAccess(for: .video) }
                    }
                }.font(.caption).buttonStyle(.bordered)
            }
            ZStack {
                if cameraMode && ARWorldTrackingConfiguration.isSupported && cameraAllowed {
                    ARFurniturePlacementView(dimensions: dimensions)
                } else if cameraMode, let dimensions {
                    FurnitureScenePreview(dimensions: dimensions)
                } else {
                    FloorPlanDrawingView(room: room, selectedProduct: previewPaused ? nil : product, pose: $pose, onPoseChange: onPoseChange)
                }
                if dimensions == nil {
                    Text(previewPaused ? "Preview paused · retailer page changed" : "Add assembled dimensions to preview this item")
                        .font(.caption).padding(8).background(.regularMaterial, in: Capsule())
                        .accessibilityIdentifier("live-preview-missing-size")
                }
            }
            .frame(height: cameraMode ? 245 : 175)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(product?.title ?? "Swipe a shopping page to choose an item")
                .font(.caption.bold()).lineLimit(1).accessibilityIdentifier("live-preview-title")
            HStack(spacing: 5) {
                Text(cameraMode && ARWorldTrackingConfiguration.isSupported && cameraAllowed ? "Tap the floor to place · schematic chair" : (cameraMode ? "3D rehearsal · camera unavailable" : "Schematic · dimensions only"))
                if let dimensions { Text(String(format: "%.0f × %.0f × %.0f cm", dimensions.width * 100, dimensions.depth * 100, dimensions.height * 100)) }
            }.font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            if let pairedStatus { Text(pairedStatus).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
        }
        .padding(.horizontal).padding(.vertical, 6)
        .background(Color(.systemBackground))
    }
}
