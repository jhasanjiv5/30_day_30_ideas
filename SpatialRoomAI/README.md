# SpatialRoom AI

SpatialRoom AI is a SwiftUI prototype for planning a room refresh: capture or select a room, review a decluttering checklist, compare a proposed layout, and estimate decor costs.

> **Prototype status:** The current source is a UI/demo, not a working room-scanning or AI app. The camera viewfinder, room analysis, spatial measurements, sample recommendations, and 3D presentation are simulated or pre-populated. `OnDeviceReasoningModel` returns fixed demo steps; it does not call Core ML, Apple Intelligence, or Foundation Models. The Foundation Models integration below is the intended implementation, not a feature currently present.

## User story

As a person planning a room refresh, I want to capture my room, understand what can be decluttered, preview a practical furniture layout, and see an estimated budget so that I can decide what to change before buying anything.

## Current app data flow

1. `SpatialRoomAIApp` presents `ContentView`.
2. `ContentView` owns a sample `Room` and displays the Capture, 3D Space, Declutter, and Cost & Decor tabs.
3. The current Capture screen displays a sample network image and simulated camera controls. Its shutter sends an empty `UIImage` to the view.
4. `OnDeviceReasoningModel` waits through a sequence of hard-coded reasoning steps and returns them; it does not inspect the image or update the room plan.
5. The other tabs render the sample room data. Declutter checkboxes and decor selections update local view state; shopping links open retailer websites. The Apple Pay button is a UI placeholder and does not initiate a payment.

## Intended on-device data flow

Use Apple’s on-device Foundation Models for language-based planning, together with dedicated computer-vision/spatial APIs for image perception. Foundation Models should not be described as analyzing the pixels of a room photo.

```text
Camera / Photos
      │ room photo + (when available) RoomPlan/LiDAR measurements
      ▼
Vision + RoomPlan / Core ML
      │ detected objects, room dimensions, depth and confidence
      ▼
Local structured room model
      │ privacy-filtered facts and user preferences (not raw photos)
      ▼
Foundation Models (on-device, when available)
      │ decluttering suggestions, layout rationale, style and shopping criteria
      ▼
Validated plan ──► 3D/2D preview, checklist, cost estimate
```

Keep room geometry and object detection grounded in Vision, RoomPlan, and/or a tested Core ML model. Use Foundation Models to turn those structured observations and the user’s preferences into explanations and a proposed plan. Validate generated output against the measured room, safety clearances, product data, and budget before showing it. Do not rely on generated text as a substitute for measurements or safety checks.

Foundation Models require a compatible Apple device, supported OS, language, and Apple Intelligence availability. Check model availability at runtime and provide a clear unsupported/unavailable state; do not silently present sample results as AI results. The intended flow keeps inference on device. The current prototype still loads its example images from Unsplash.

## Implementation steps

1. **Implement capture and import.** Replace the simulated viewfinder and empty image with AVFoundation capture and a Photos picker. Request camera/photo access only when needed and handle denial or cancellation.
3. **Add room perception.** Use RoomPlan on supported devices for room structure and LiDAR where available; use Vision or a Core ML object-detection model for objects. Return typed measurements/detections with confidence values and support devices without LiDAR.
4. **Add Foundation Models.** On supported OS versions, use `FoundationModels` (`SystemLanguageModel` and `LanguageModelSession`) to generate a structured, typed plan from the local measurements and user preferences. Guard APIs with availability checks, inspect model availability, validate the result, and provide a non-AI fallback when unavailable. The model handles language planning—not direct image understanding.
5. **Connect the plan to the UI.** Replace the sample `Room` in `ContentView` with the capture and analysis result. Keep the 2D layout, any genuine 3D rendering, declutter checklist, and itemized estimate driven by the same validated plan.
6. **Test and harden.** Test supported and unsupported devices, denied permissions, poor scans, malformed model output, and offline behavior. Verify privacy behavior and label any estimates or retailer data that are not live.

## Install and run from Xcode

### Requirements

- A Mac with Xcode and the iOS SDK.
- An iOS Simulator for UI development; a physical iPhone is recommended for camera, LiDAR/RoomPlan, and on-device model testing.
- For the intended Foundation Models feature, a device and OS version that support Apple Intelligence/Foundation Models. The prototype’s package minimum is iOS 17, which does not by itself guarantee Foundation Models availability.

### Install and launch

1. Open `SpatialRoomAI.xcodeproj` in Xcode.
2. Select the **SpatialRoomAI** scheme and an iOS Simulator or connected iPhone.
3. Press **⌘R** to build, install, and launch the app. On a device, approve permissions if prompted.
4. For on-device model validation, check `SystemLanguageModel.default` availability on the target device and test both available and unavailable states. A simulator or unsupported device may not provide the required model.

The Xcode project uses the existing `Info.plist` and compiles the Swift files under `Sources/`. `Package.swift` remains a library product for package consumers; `swift build` on macOS cannot build this iOS UI code against the macOS SDK.
