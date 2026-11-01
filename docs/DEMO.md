# RoomWise walkthrough

Demonstrate the core loop: **conversation → product pages → changing room preview**. A clean clone can demonstrate sample products and a local paired session without a provider account or the author's device.

1. Run the iPhone app in Simulator and load the sample room. Explain that the room/chairs are synthetic and the preview is a dimension-based schematic.
2. Use **Send** to start a chair conversation: “a black office chair under AED 500 with armrests.” Follow with “make it white” or “under AED 300 instead.” Point out the reply, retained context, and whether Groq or the limited local fallback is active.
3. Use **Find matches** when ready to retrieve listings. A nonempty draft is sent once first; with no draft, it searches from accepted preferences without another model call. Swipe through the product pages. Show that the active product changes the room object without a separate Preview button. A product with unknown assembled dimensions should withhold the object, not keep the previous product visible.
4. Edit assembled dimensions, then move/rotate/recenter the chair. Show a wall/object conflict and explain that the result covers captured footprints only.
5. Open the selected product's retailer page explicitly. Explain the difference between the RoomWise product carousel and arbitrary navigation within a retailer website; only validated RoomWise selection drives the preview.
6. Run the desktop companion, load samples, explicitly start pairing, and paste its private local URL into the phone's pairing controls. On a trusted local network, step/swipe between desktop products and show the phone's selection changing. Stop pairing to invalidate the session.
7. Optional live discovery: enter personal Groq Free and Tavily Researcher keys, disable sample mode, consent to sharing, then retrieve listings. Show missing evidence and source labels rather than filling gaps from the model.
8. Show Add chair, room import/export, Help & Privacy, provider-permission revocation, and separate key clearing as time allows.

Physical LiDAR scanning and camera AR are optional hardware demonstrations. Simulator's 3D rehearsal is not a physical AR test. The chair is a generic schematic scaled to known dimensions, not the retailer's exact mesh.

Pairing has no cloud or subscription cost. It transfers products and selection, not rooms, chat, or keys; local HTTP needs a trusted network. Do not show private session tokens or provider keys in a recorded demo.

Use the [validation record](VALIDATION.md) to state which checks actually ran. Do not describe mocked provider responses as a live shopping demonstration. Do not use historical demo credentials.
