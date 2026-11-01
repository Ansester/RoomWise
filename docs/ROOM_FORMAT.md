# Room JSON v1

The authoritative serializable contract is `shared/src/commonMain/kotlin/fitcheck/Models.kt`. `decodeRoom` rejects incompatible versions/units/coordinate strings, malformed dimensions, nonfinite positions, oversized files and invalid complete boundaries.

- `schemaVersion`: `1`.
- `units`: `m`; every linear quantity is metres.
- `coordinates`: `right-handed:Y-up:floor-XZ:yaw-X-toward-Z`.
- Coordinates preserve RoomPlan's gravity-aligned world origin and orientation. No recentering or rectangular-room assumption occurs. The desktop projects world X horizontally and world Z downward on screen, with a uniform metres-to-pixels scale.
- A pose is the centre `(x,z)` and `yaw` in radians. Positive plan yaw rotates local +width X toward world +Z. This is explicitly the plan-angle convention, not a claim about Apple's Euler-Y sign.
- Width is local X, height is local Y, depth is local Z. Swift exports RoomPlan's `dimensions.x/y/z` accordingly. Surface depth may be zero. Recognized furniture must have positive width/depth/height to be used for footprint collision checks.
- Each element retains its complete original 4×4 transform as 16 column-major numbers. Position is indices 12/14; plan yaw is `atan2(transform[2],transform[0])`. Import checks agreement between the transform and normalized pose. Vertical placement is retained in the transform but not rendered in the top-down plan.
- `walls`, `openings` (doors/windows/openings), and `objects` carry IDs, kinds, dimensions, poses and transforms. Door swing is never inferred.
- `boundary` is an ordered, simple floor polygon. `boundaryComplete` is false in the raw Swift capture; shared validation attempts to join every wall's two endpoints into one unambiguous loop, with a 3 cm scan-join tolerance. Disconnected, branching, degenerate or self-intersecting loops remain incomplete. This tolerance is an approximation of captured geometry, not a survey-grade guarantee. Export and import both use the same Kotlin logic.
- `savedDemo` labels synthetic recovery geometry; it never represents a real LiDAR scan.

Placement uses all four corners of each rotated candidate/furniture rectangle. Furniture overlap uses separating axes from both rectangles. Touching an existing object is conservatively counted as an overlap. Boundary checks test all corners, segment crossings, concave intrusions and edge midpoints. No fit is confirmed when the boundary is incomplete. These are footprint checks against recognized scan geometry, not guarantees about hidden obstructions, chair motion, overhead clearance, door swings or entry routes.

Room JSON may contain private room geometry; transfer it deliberately. It contains no provider credentials, photos or network endpoints.
