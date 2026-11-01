import SwiftUI
import FitCheckShared
import ARKit
import SceneKit
import AVFoundation

private let forestGreen = Color(red: 0.14, green: 0.29, blue: 0.21)
private let sageSurface = Color(red: 0.94, green: 0.95, blue: 0.94)
private let sageBorder = Color(red: 0.86, green: 0.89, blue: 0.87)
private let openingsAmber = Color(red: 0.73, green: 0.41, blue: 0.13)
private let charcoalText = Color(red: 0.09, green: 0.13, blue: 0.11)

struct FloorPlanCanvas: View {
    let room: Room
    let selectedProduct: Product?
    @Binding var pose: Pose
    let onPoseChange: (Pose) -> Void
    @State private var showARPreview = false
    private var arDimensions: Dimensions {
        selectedProduct?.previewSize() ?? Dimensions(width: 0.62, depth: 0.64, height: 1.12)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("3D room preview", systemImage: "cube.transparent")
                    .font(.caption.bold())
                    .foregroundColor(forestGreen)
                Spacer()
                Button {
                    showARPreview = true
                } label: {
                    Label("AR Preview", systemImage: "arkit")
                }
                .buttonStyle(.borderedProminent)
                .tint(forestGreen)
                .controlSize(.small)
                .disabled(selectedProduct?.previewSize() == nil)
            }

            FloorPlanDrawingView(
                room: room,
                selectedProduct: selectedProduct,
                pose: $pose,
                onPoseChange: onPoseChange
            )
            .frame(height: 280)

            if let product = selectedProduct {
                PlacementControlsView(
                    room: room,
                    product: product,
                    pose: $pose,
                    onPoseChange: onPoseChange
                )
            }
        }
        .sheet(isPresented: $showARPreview) {
            ARPreviewScreen(
                productTitle: selectedProduct?.title ?? "True-scale chair preview",
                dimensions: arDimensions
            )
        }
    }
}

struct FloorPlanDrawingView: View {
    let room: Room
    let selectedProduct: Product?
    @Binding var pose: Pose
    let onPoseChange: (Pose) -> Void

    @State private var dragStartPose: Pose? = nil

    var body: some View {
        GeometryReader { geometry in
            let bounds = computeBounds(room: room)
            let minX = bounds.minX
            let maxX = bounds.maxX
            let minZ = bounds.minZ
            let maxZ = bounds.maxZ
            let roomWidth = max(maxX - minX, 1.0)
            let roomHeight = max(maxZ - minZ, 1.0)
            let padding: CGFloat = 18.0
            let tallestWall = room.walls.map { min(max($0.dimensions.height, 0.4), 4.0) }.max() ?? 2.6
            let tallestObject = room.objects.map { min(max($0.dimensions.height, 0.1), 4.0) }.max() ?? 0.0
            let selectedHeight = selectedProduct?.previewSize()?.height ?? 0.0
            let maxHeight = max(tallestWall, tallestObject, selectedHeight)
            let projectedWidth = CGFloat(roomWidth + roomHeight) * 0.72
            let projectedHeight = CGFloat(roomWidth + roomHeight) * 0.36 + CGFloat(maxHeight) * 0.75
            let scale = min((geometry.size.width - padding * 2) / max(projectedWidth, 1),
                            (geometry.size.height - padding * 2) / max(projectedHeight, 1))
            let centerX = (minX + maxX) / 2
            let centerZ = (minZ + maxZ) / 2
            let floorHalfHeight = CGFloat(roomWidth + roomHeight) * 0.18 * scale
            let baseY = padding + CGFloat(maxHeight) * 0.75 * scale + floorHalfHeight

            Canvas { context, size in
                func toScreen(x: Double, z: Double, y: Double = 0) -> CGPoint {
                    let dx = CGFloat(x - centerX)
                    let dz = CGFloat(z - centerZ)
                    return CGPoint(
                        x: size.width / 2 + (dx - dz) * scale * 0.72,
                        y: baseY + (dx + dz) * scale * 0.36 - CGFloat(y) * scale * 0.75
                    )
                }

                func polygon(_ points: [CGPoint]) -> Path {
                    var path = Path()
                    guard let first = points.first else { return path }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                    path.closeSubpath()
                    return path
                }

                func drawBox(footprint: [Point], height: Double, fill: Color, stroke: Color) {
                    guard footprint.count >= 4 else { return }
                    let clampedHeight = min(max(height, 0.08), 4.0)
                    for index in footprint.indices {
                        let next = (index + 1) % footprint.count
                        let a = footprint[index]
                        let b = footprint[next]
                        let side = polygon([
                            toScreen(x: a.x, z: a.z),
                            toScreen(x: b.x, z: b.z),
                            toScreen(x: b.x, z: b.z, y: clampedHeight),
                            toScreen(x: a.x, z: a.z, y: clampedHeight)
                        ])
                        context.fill(side, with: .color(fill.opacity(0.58)))
                        context.stroke(side, with: .color(stroke.opacity(0.65)), lineWidth: 0.8)
                    }
                    let top = polygon(footprint.map { toScreen(x: $0.x, z: $0.z, y: clampedHeight) })
                    context.fill(top, with: .color(fill.opacity(0.92)))
                    context.stroke(top, with: .color(stroke), lineWidth: 1.2)
                }

                // 1. Grid
                var gx = floor(minX * 2) / 2.0
                while gx <= maxX {
                    var p = Path()
                    p.move(to: toScreen(x: gx, z: minZ))
                    p.addLine(to: toScreen(x: gx, z: maxZ))
                    context.stroke(p, with: .color(sageBorder.opacity(0.6)), lineWidth: 0.8)
                    gx += 0.5
                }
                var gz = floor(minZ * 2) / 2.0
                while gz <= maxZ {
                    var p = Path()
                    p.move(to: toScreen(x: minX, z: gz))
                    p.addLine(to: toScreen(x: maxX, z: gz))
                    context.stroke(p, with: .color(sageBorder.opacity(0.6)), lineWidth: 0.8)
                    gz += 0.5
                }

                // 2. Walls, extruded to their captured height.
                for wall in room.walls {
                    let ends = GeometryKt.wallEnds(e: wall)
                    if ends.count >= 2 {
                        let h = min(max(wall.dimensions.height, 0.4), 4.0)
                        let face = polygon([
                            toScreen(x: ends[0].x, z: ends[0].z),
                            toScreen(x: ends[1].x, z: ends[1].z),
                            toScreen(x: ends[1].x, z: ends[1].z, y: h),
                            toScreen(x: ends[0].x, z: ends[0].z, y: h)
                        ])
                        context.fill(face, with: .color(forestGreen.opacity(0.18)))
                        context.stroke(face, with: .color(forestGreen), lineWidth: 1.8)
                    }
                }

                // 3. Openings
                for opening in room.openings {
                    let ends = GeometryKt.wallEnds(e: opening)
                    if ends.count >= 2 {
                        let h = min(max(opening.dimensions.height, 0.4), 3.2)
                        let face = polygon([
                            toScreen(x: ends[0].x, z: ends[0].z),
                            toScreen(x: ends[1].x, z: ends[1].z),
                            toScreen(x: ends[1].x, z: ends[1].z, y: h),
                            toScreen(x: ends[0].x, z: ends[0].z, y: h)
                        ])
                        context.fill(face, with: .color(openingsAmber.opacity(0.32)))
                        context.stroke(face, with: .color(openingsAmber), lineWidth: 2.0)
                    }
                }

                // 4. Recognized objects as dimensionally scaled 3D boxes.
                for obj in room.objects.sorted(by: { ($0.pose.x + $0.pose.z) < ($1.pose.x + $1.pose.z) }) {
                    let fp = GeometryKt.footprint(d: obj.dimensions, p: obj.pose)
                    drawBox(footprint: fp, height: obj.dimensions.height, fill: sageSurface, stroke: forestGreen.opacity(0.62))
                }

                // 5. Selected candidate as a highlighted 3D volume.
                if let product = selectedProduct, let dims = product.previewSize() {
                    let fp = GeometryKt.footprint(d: dims, p: pose)
                    if fp.count >= 4 {
                        drawBox(footprint: fp, height: dims.height, fill: forestGreen.opacity(0.55), stroke: forestGreen)

                        let center = toScreen(x: pose.x, z: pose.z, y: dims.height + 0.16)
                        let wCm = Int(round(dims.width * 100))
                        let dCm = Int(round(dims.depth * 100))
                        let hCm = Int(round(dims.height * 100))
                        context.draw(Text("\(wCm) × \(dCm) × \(hCm) cm").font(.system(size: 10, weight: .semibold)), at: center)
                    }
                }

                // 6. 1m floor scale and explicit view label.
                let sStart = toScreen(x: minX, z: maxZ)
                let sEnd = toScreen(x: minX + 1.0, z: maxZ)
                var sp = Path()
                sp.move(to: sStart)
                sp.addLine(to: sEnd)
                context.stroke(sp, with: .color(forestGreen), lineWidth: 2.5)
                context.draw(Text("1 m").font(.system(size: 9, weight: .medium)), at: CGPoint(x: (sStart.x + sEnd.x) / 2, y: (sStart.y + sEnd.y) / 2 + 11))
                context.draw(Text("3D ROOM PREVIEW").font(.system(size: 9, weight: .bold)).foregroundColor(forestGreen), at: CGPoint(x: size.width - 67, y: 13))
            }
            .background(Color(red: 0.97, green: 0.97, blue: 0.96))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(sageBorder, lineWidth: 1))
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        guard selectedProduct?.previewSize() != nil else { return }
                        if dragStartPose == nil {
                            dragStartPose = pose
                        }
                        if let start = dragStartPose {
                            let projectedX = Double(value.translation.width / (scale * 0.72))
                            let projectedZ = Double(value.translation.height / (scale * 0.36))
                            let dmx = (projectedX + projectedZ) / 2
                            let dmz = (projectedZ - projectedX) / 2
                            let newPose = Pose(x: start.x + dmx, z: start.z + dmz, yaw: start.yaw)
                            pose = newPose
                            onPoseChange(newPose)
                        }
                    }
                    .onEnded { _ in
                        dragStartPose = nil
                    }
            )
        }
    }

    private func computeBounds(room: Room) -> (minX: Double, maxX: Double, minZ: Double, maxZ: Double) {
        var allX: [Double] = []
        var allZ: [Double] = []

        for w in room.walls {
            let ends = GeometryKt.wallEnds(e: w)
            for pt in ends {
                allX.append(pt.x)
                allZ.append(pt.z)
            }
        }
        for o in room.objects {
            allX.append(o.pose.x)
            allZ.append(o.pose.z)
        }
        if let dims = selectedProduct?.previewSize() {
            let fp = GeometryKt.footprint(d: dims, p: pose)
            for pt in fp {
                allX.append(pt.x)
                allZ.append(pt.z)
            }
        }

        let minX = (allX.min() ?? 0.0) - 0.5
        let maxX = (allX.max() ?? 4.0) + 0.5
        let minZ = (allZ.min() ?? 0.0) - 0.5
        let maxZ = (allZ.max() ?? 4.0) + 0.5

        return (minX, maxX, minZ, maxZ)
    }
}

private struct ARPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    let productTitle: String
    let dimensions: Dimensions
    @State private var cameraAllowed = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @State private var checkingCamera = true

    var body: some View {
        NavigationStack {
            Group {
                if ARWorldTrackingConfiguration.isSupported {
                    if checkingCamera {
                        ProgressView("Checking camera access…")
                    } else if !cameraAllowed {
                        ContentUnavailableView {
                            Label("Camera access needed", systemImage: "camera")
                        } description: {
                            Text("Allow camera access in Settings to place a chair in AR.")
                        } actions: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                Link("Open Settings", destination: url)
                            }
                        }
                    } else {
                        ZStack(alignment: .bottom) {
                        ARFurniturePlacementView(dimensions: dimensions)
                            .ignoresSafeArea(edges: .bottom)
                        Text("Simplified chair · dimensions only. Move to find the floor, then tap to place or move it.")
                            .font(.caption.weight(.medium))
                            .multilineTextAlignment(.center)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding()
                        }
                    }
                } else {
                    VStack(spacing: 14) {
                        FurnitureScenePreview(dimensions: dimensions)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        Label("AR rehearsal mode", systemImage: "iphone.gen3.radiowaves.left.and.right")
                            .font(.headline)
                            .foregroundColor(forestGreen)
                        Text("Camera AR is unavailable on this device or Simulator. Explore a simplified chair with the selected dimensions in 3D.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Text("\(Int(dimensions.width * 100)) × \(Int(dimensions.depth * 100)) × \(Int(dimensions.height * 100)) cm")
                            .font(.caption.monospaced().bold())
                    }
                    .padding()
                }
            }
            .navigationTitle(productTitle)
            .task {
                if ARWorldTrackingConfiguration.isSupported {
                    cameraAllowed = await AVCaptureDevice.requestAccess(for: .video)
                }
                checkingCamera = false
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ARFurniturePlacementView: UIViewRepresentable {
    let dimensions: Dimensions

    func makeCoordinator() -> Coordinator { Coordinator(dimensions: dimensions) }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.scene = SCNScene()
        view.automaticallyUpdatesLighting = true
        view.autoenablesDefaultLighting = true
        view.debugOptions = [.showFeaturePoints]

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        let coaching = ARCoachingOverlayView()
        coaching.sessionProvider = view
        coaching.goal = .horizontalPlane
        coaching.activatesAutomatically = true
        coaching.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coaching)
        NSLayoutConstraint.activate([
            coaching.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            coaching.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            coaching.topAnchor.constraint(equalTo: view.topAnchor),
            coaching.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.placeChair(_:))))
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    final class Coordinator: NSObject {
        let dimensions: Dimensions
        private var placedNode: SCNNode?

        init(dimensions: Dimensions) { self.dimensions = dimensions }

        @objc func placeChair(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? ARSCNView,
                  let query = view.raycastQuery(from: gesture.location(in: view), allowing: .estimatedPlane, alignment: .horizontal),
                  let result = view.session.raycast(query).first else { return }

            placedNode?.removeFromParentNode()
            let node = makeChairNode(dimensions)
            let transform = result.worldTransform
            node.simdPosition = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            view.scene.rootNode.addChildNode(node)
            placedNode = node
        }
    }
}

private struct FurnitureScenePreview: UIViewRepresentable {
    let dimensions: Dimensions

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = UIColor(red: 0.94, green: 0.96, blue: 0.94, alpha: 1)
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true

        let chair = makeChairNode(dimensions)
        scene.rootNode.addChildNode(chair)

        let floor = SCNFloor()
        floor.reflectivity = 0.08
        floor.firstMaterial?.diffuse.contents = UIColor(red: 0.84, green: 0.88, blue: 0.85, alpha: 1)
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        let camera = SCNCamera()
        camera.fieldOfView = 52
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        let span = Float(max(dimensions.width, dimensions.depth, dimensions.height, 1.0))
        cameraNode.position = SCNVector3(span * 1.7, span * 1.25, span * 1.7)
        cameraNode.look(at: SCNVector3(0, Float(dimensions.height * 0.42), 0))
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

func makeChairNode(_ dimensions: Dimensions) -> SCNNode {
    let width = CGFloat(dimensions.width)
    let depth = CGFloat(dimensions.depth)
    let height = CGFloat(dimensions.height)
    let root = SCNNode()

    func box(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat, _ position: SCNVector3, alpha: CGFloat = 1) -> SCNNode {
        let geometry = SCNBox(width: w, height: h, length: d, chamferRadius: min(w, h, d) * 0.08)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.14, green: 0.29, blue: 0.21, alpha: alpha)
        material.roughness.contents = 0.72
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.position = position
        return node
    }

    let seatY = height * 0.48
    let seatThickness = max(height * 0.07, 0.045)
    root.addChildNode(box(width, seatThickness, depth * 0.86, SCNVector3(0, Float(seatY), 0)))

    let backHeight = max(height * 0.46, 0.25)
    let backThickness = max(depth * 0.07, 0.035)
    root.addChildNode(box(width * 0.94, backHeight, backThickness,
                          SCNVector3(0, Float(seatY + backHeight * 0.48), Float(-depth * 0.43))))

    let legHeight = max(seatY - seatThickness / 2, 0.12)
    let legSize = max(min(width, depth) * 0.075, 0.025)
    for x in [-1.0, 1.0] {
        for z in [-1.0, 1.0] {
            root.addChildNode(box(legSize, legHeight, legSize,
                                  SCNVector3(Float(CGFloat(x) * (width / 2 - legSize)), Float(legHeight / 2), Float(CGFloat(z) * (depth * 0.38)))))
        }
    }

    let armHeight = max(height * 0.04, 0.025)
    for x in [-1.0, 1.0] {
        root.addChildNode(box(armHeight, armHeight, depth * 0.62,
                              SCNVector3(Float(CGFloat(x) * (width / 2 - armHeight / 2)), Float(seatY + height * 0.18), 0)))
        root.addChildNode(box(armHeight, height * 0.18, armHeight,
                              SCNVector3(Float(CGFloat(x) * (width / 2 - armHeight / 2)), Float(seatY + height * 0.09), Float(depth * 0.22))))
    }
    // The schematic parts have aesthetic proportions; normalize their combined
    // bounds to the entered assembled size, centred in X/Z and resting on Y=0.
    // Keep the placement container unscaled so AR raycast positions stay in metres.
    let (minimum, maximum) = root.boundingBox
    let span = SCNVector3(maximum.x - minimum.x, maximum.y - minimum.y, maximum.z - minimum.z)
    let scale = SCNVector3(Float(width) / span.x, Float(height) / span.y, Float(depth) / span.z)
    root.scale = scale
    root.position = SCNVector3(
        -(minimum.x + maximum.x) * 0.5 * scale.x,
        -minimum.y * scale.y,
        -(minimum.z + maximum.z) * 0.5 * scale.z
    )
    let placement = SCNNode()
    placement.addChildNode(root)
    return placement
}

struct PlacementControlsView: View {
    let room: Room
    let product: Product
    @Binding var pose: Pose
    let onPoseChange: (Pose) -> Void

    @State private var showDetails: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            if let dims = product.previewSize() {
                HStack {
                    Text(product.title)
                        .font(.subheadline.bold())
                        .foregroundColor(charcoalText)
                        .lineLimit(1)
                    Spacer()
                    let wCm = Int(round(dims.width * 100))
                    let dCm = Int(round(dims.depth * 100))
                    let hCm = Int(round(dims.height * 100))
                    Text("\(wCm) × \(dCm) × \(hCm) cm")
                        .font(.caption.monospaced())
                        .foregroundColor(charcoalText)
                }

                // Rotation slider & buttons
                HStack(spacing: 12) {
                    let degValue = (Int(round(pose.yaw * 180.0 / .pi).truncatingRemainder(dividingBy: 360.0)) + 360) % 360
                    Text("Rotation \(degValue)°")
                        .font(.caption)
                        .foregroundColor(charcoalText)
                        .frame(width: 84, alignment: .leading)

                    Slider(
                        value: Binding(
                            get: {
                                let deg = (pose.yaw * 180.0 / .pi).truncatingRemainder(dividingBy: 360.0)
                                return deg < 0 ? deg + 360.0 : deg
                            },
                            set: { newDeg in
                                let newPose = Pose(x: pose.x, z: pose.z, yaw: newDeg * .pi / 180.0)
                                pose = newPose
                                onPoseChange(newPose)
                            }
                        ),
                        in: 0...360
                    )
                    .tint(forestGreen)
                    .accessibilityLabel("Chair rotation")
                    .accessibilityValue("\(degValue) degrees")

                    Button("+90°") {
                        let newDeg = ((pose.yaw * 180.0 / .pi) + 90.0).truncatingRemainder(dividingBy: 360.0)
                        let newPose = Pose(x: pose.x, z: pose.z, yaw: newDeg * .pi / 180.0)
                        pose = newPose
                        onPoseChange(newPose)
                    }
                    .buttonStyle(.bordered)
                    .tint(forestGreen)
                    .controlSize(.small)

                    Button("Recenter") {
                        let recentered = GeometryKt.initialPlacement(room: room, d: dims)
                        pose = recentered
                        onPoseChange(recentered)
                    }
                    .buttonStyle(.bordered)
                    .tint(forestGreen)
                    .controlSize(.small)
                }

                HStack(spacing: 12) {
                    Text("Move 10 cm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    nudgeButton("arrow.left", label: "Move chair left 10 centimetres", x: -0.1, z: 0.1)
                    nudgeButton("arrow.up", label: "Move chair up 10 centimetres", x: -0.1, z: -0.1)
                    nudgeButton("arrow.down", label: "Move chair down 10 centimetres", x: 0.1, z: 0.1)
                    nudgeButton("arrow.right", label: "Move chair right 10 centimetres", x: 0.1, z: -0.1)
                }
                .buttonStyle(.bordered)
                .tint(forestGreen)

                // Geometry Check Banner
                let result = GeometryKt.checkPlacement(room: room, d: dims, p: pose)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(result.fits ? forestGreen : openingsAmber)
                            .frame(width: 8, height: 8)
                        Text(conciseStatus(result))
                            .font(.caption.bold())
                            .foregroundColor(result.fits ? forestGreen : openingsAmber)
                        Spacer()
                        Button(showDetails ? "Hide details" : "Details") {
                            showDetails.toggle()
                        }
                        .font(.caption)
                        .foregroundColor(forestGreen)
                    }
                    if showDetails {
                        Text(result.explanation())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
                .padding(10)
                .background(sageSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.title)
                            .font(.subheadline.bold())
                            .foregroundColor(charcoalText)
                            .lineLimit(1)
                        Text("Dimensions unavailable. Add them to preview this chair.")
                            .font(.caption)
                            .foregroundColor(openingsAmber)
                    }
                    Spacer()
                }
                .padding(10)
                .background(sageSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func conciseStatus(_ r: PlacementResult) -> String {
        if !r.collisions.isEmpty {
            return "Overlaps: \(r.collisions.joined(separator: ", "))"
        }
        if r.boundary == "Outside scanned boundary" {
            return "Outside scanned boundary"
        }
        if !r.complete {
            return "Boundary check incomplete"
        }
        if r.fits {
            return "Fits captured geometry"
        }
        return "Fit not confirmed"
    }

    private func nudgeButton(_ icon: String, label: String, x: Double, z: Double) -> some View {
        Button {
            let next = Pose(x: pose.x + x / sqrt(2), z: pose.z + z / sqrt(2), yaw: pose.yaw)
            pose = next
            onPoseChange(next)
        } label: {
            Image(systemName: icon).frame(minWidth: 24, minHeight: 28)
        }
        .accessibilityLabel(label)
    }
}
