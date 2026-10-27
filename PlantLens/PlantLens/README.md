# PlantLens iOS App

PlantLens is a SwiftUI iPhone app that uses the camera to photograph a plant and the Gemini 2.5 Flash API to return an identification and health assessment.

## Code navigation

- `App/PlantLensApp.swift` starts the app and displays `ContentView`.
- `Views/ContentView.swift` contains the live camera screen, shutter button, scan progress, result summary, and navigation to the full assessment.
- `Views/CameraPreviewView.swift` displays the camera feed, and `Views/ReticleOverlayView.swift` draws the targeting guide.
- `Views/PlantDetailView.swift` presents the health score, diagnosis, watering and sunlight needs, immediate care steps, and long-term advice.
- `Services/CameraManager.swift` requests camera permission, configures the rear camera, and captures photos.
- `Services/GeminiService.swift` sends the captured image to Gemini and decodes the JSON assessment.
- `Models/PlantAnalysis.swift` defines the assessment data returned by the service.
- `Info.plist` provides the camera permission explanation shown to the user.
- `Config/Secrets.plist` holds the Gemini API key used by the app.

## Set up and run on an iPhone

1. Open `PlantLens.xcodeproj` in Xcode.
2. Add your Gemini API key to `Config/Secrets.plist` under the `GEMINI_API_KEY` key. Make sure `Secrets.plist` is included in the PlantLens app target so it is copied into the app bundle.
3. In Xcode, select the PlantLens app target, open **Signing & Capabilities**, and choose your development team. Use a unique bundle identifier if your team requires one.
4. Connect and unlock your iPhone, select it as the run destination in Xcode, then press **Cmd + R**. Follow any prompts on your iPhone to trust the developer or grant camera access.
5. If camera access was denied, enable it for PlantLens in **Settings > Privacy & Security > Camera** (or the app's settings page) and reopen the app.

PlantLens needs a physical iPhone for camera capture and an internet connection to contact Gemini. The first launch asks for camera permission; the app's camera preview appears after permission is granted.

## Use the app

1. Point the iPhone's rear camera at a plant and center the leaves or stem in the on-screen reticle.
2. Tap the shutter button. PlantLens captures the image and displays a scanning indicator while Gemini analyzes it.
3. Review the result card for the plant name, health percentage, and brief status. Tap **View More** to open the full assessment, then **Done** to return to the camera.
4. Tap the **X** on the result card to dismiss it and scan another plant. If the image is not recognized as a plant, the summary is shown without the **View More** action.

The API key is bundled in the app for this prototype. Do not use a client-bundled key for a publicly distributed app; use a backend to protect production credentials.
