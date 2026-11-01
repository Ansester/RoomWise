# Geometry and fit checking

RoomWise checks whether a chair's rectangular floor footprint is contained in a validated room boundary and overlaps recognized furniture. The same Kotlin functions serve iPhone and desktop. Height contributes to the preview and dimension validity, but the fit calculation is two-dimensional.

The implementation is [`Geometry.kt`](../shared/src/commonMain/kotlin/fitcheck/Geometry.kt), with contracts in [`Models.kt`](../shared/src/commonMain/kotlin/fitcheck/Models.kt). The serialized format is documented in [Room JSON v1](ROOM_FORMAT.md).

## Coordinate system

All linear measurements use metres. World Y points upward; the floor plane is XZ. A pose stores the centre `(x, z)` and a plan rotation `yaw` in radians. Positive yaw rotates the local width axis, +X, toward world +Z. This is a documented floor-plan angle convention, not an assumption about the sign of an Apple Euler-Y angle.

Dimensions are `(width, depth, height)`, corresponding to local X, Z, and Y. For a local footprint corner `(u, v)` and pose `(x, z, θ)`, the world corner is:

```text
X = x + u cos(θ) − v sin(θ)
Z = z + u sin(θ) + v cos(θ)

u ∈ {−width/2, +width/2}
v ∈ {−depth/2, +depth/2}
```

`footprint` returns all four transformed corners in order. `wallEnds` treats a wall as a line segment of its width, centred at the wall pose and rotated by its plan yaw. Vertical position and the original 4×4 transform are retained for interchange; the collision calculation uses the normalized floor pose.

RoomPlan export reads position from column-major transform indices 12 and 14 and computes plan yaw as `atan2(transform[2], transform[0])`. Import checks that the normalized position and orientation agree with a supplied transform. Imported rooms retain their captured origin; the decoder does not replace them with axis-aligned rectangles.

## Boundary reconstruction

A raw capture can have walls without a ready floor polygon. `inferBoundary` attempts a conservative reconstruction:

1. Compute both endpoints of every wall.
2. For every endpoint, require exactly one endpoint on a different wall within a **strictly less than 3 cm** Euclidean distance.
3. Traverse the joins and the opposite end of each wall.
4. Require one loop that uses every wall exactly once.
5. Validate the resulting polygon.

The algorithm refuses ambiguous joins instead of picking the nearest branch. Disconnected loops, duplicate/branching walls, gaps outside the tolerance, degenerate polygons, and self-intersections do not establish a complete boundary. The tolerance is an approximation for scan joins, not a survey accuracy statement.

If the input declares `boundaryComplete = true`, the decoder validates the supplied polygon rather than reconstructing it from walls. If false, it attempts reconstruction from walls. A complete explicit boundary and a wall-derived boundary therefore have distinct input paths but share polygon validation and placement checks.

## Polygon validity

`validPolygon` accepts 3–2,000 finite vertices. It rejects effectively zero-length consecutive edges, nonadjacent edge crossings/touches detected by the implementation, and negligible signed-area magnitude. The code accumulates the doubled shoelace area and requires its absolute value to exceed `0.01`; this threshold should not be described as a calibrated room-size threshold.

Geometry comparisons use a small internal epsilon (`1e-8`). The epsilon supports numerical comparisons; it is not a real-world clearance margin. There is no configurable buffer around walls or furniture in the current fit engine.

## Containing the complete footprint

Checking only a chair's centre would accept placements whose edges protrude through walls. Checking only the four corners is also insufficient in a concave room. `contained` therefore requires:

- Every chair corner lies inside or on the room boundary.
- Chair edges do not properly cross boundary edges.
- A concave boundary vertex does not intrude into the interior of the chair polygon.
- Each chair edge midpoint lies inside or on the boundary.

The concavity checks matter for L- and U-shaped rooms, where a chair can span a notch even when a simpler test looks plausible. Touching a room boundary is included by the point-in-polygon edge rule; RoomWise does not claim extra movement clearance at that position.

## Furniture overlap

Recognized furniture is represented by rotated rectangles. `overlaps` applies the separating-axis theorem using axes derived from both rectangles. If an axis separates the projection intervals, the footprints do not overlap. Without a separating axis, the result is an overlap.

Touching an existing furniture footprint counts conservatively as overlap. The checks use every recognized object with valid dimensions; they do not infer which objects are movable, which legs have free space underneath, or whether furniture shapes have usable holes. Bounding rectangles may overstate the occupied area of a nonrectangular object.

## Fit and scan-quality states

| Result | Meaning |
| --- | --- |
| `COMPLETE` scan | A complete, valid boundary is available |
| `PARTIAL` scan | No complete valid boundary, but at least two walls or a recognized object exist |
| `UNUSABLE` scan | Neither of the above establishes useful captured geometry |
| `fits = true` | Complete boundary, full footprint inside it, and no recognized-object overlap |
| Fit not confirmed | Boundary incomplete/outside, or one or more overlaps |

For an incomplete scan, object collisions can still be reported, but wall-boundary fit is withheld. `PlacementResult.explanation()` exposes the boundary result, collision categories, fit status, and omitted real-world checks.

## Initial placement and recentering

For a complete valid boundary, `initialPlacement` tries the bounding-box centre, then a small fixed set of offsets around it. If those fail, it searches a bounded **17×17** grid over the floor extent, ordered near the centre, first at 0° and then 90°. Every returned fitting candidate passes full containment and recognized-object overlap checks.

If no tested candidate fits, the centre is returned as a visible, unconfirmed starting pose. This is a bounded heuristic, not a continuous layout optimizer: failure to find a candidate does not prove that no placement exists. For an incomplete room, the initial pose uses the captured walls/object-centre extent, or a default position when geometry is absent, without claiming boundary fit.

## Import bounds

`decodeRoom` rejects inputs larger than 5,000,000 characters, more than 5,000 combined walls/openings/objects, incompatible schema/units/coordinate strings, nonfinite geometry, or invalid complete boundaries. Element position/yaw/dimension values must satisfy the implementation's magnitude bounds; widths/heights must be positive and at most 100 m, surfaces may have zero depth, and recognized objects require positive valid footprint dimensions. Boundary coordinates are bounded to ±1,000 m and 2,000 points. Optional transforms must contain exactly 16 finite values and agree with the normalized pose.

The iPhone file-import UI also checks file size before reading. These limits bound malformed input and computational work; they are not a claim that all unusually large but valid files will feel responsive on every device.

## What the result does not establish

The engine does not check delivery routes, door swings, overhead clearance, chair movement, recline, people walking around furniture, hidden obstructions, scan error, or structural safety. A dimensionally scaled AR chair is a simplified preview. Users should verify the seller's selected variant and assembled dimensions and measure the room before purchase.

Tests exercise rotated extents, separating axes, concave containment, incomplete scans, ambiguous/gapped boundaries, input bounds, recentering, and serialization. See [validation evidence](VALIDATION.md) for the verified counts and the distinction between automated geometry checks and physical accuracy.
