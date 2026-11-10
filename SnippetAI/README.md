# SnippetAI

SnippetAI is an iOS video-highlights editor. Import a video, use on-device
Vision image classification and Apple Intelligence reasoning to select
highlights, edit the resulting timeline, export a filtered reel, and optionally
sync project metadata to Firebase.

![SnippetAI running in the iOS Simulator](docs/app-screenshot.png)

## Dataflow

```mermaid
flowchart TD
    U[Import video] --> L[Copy video into app temporary storage]
    L --> P[AVPlayer preview]
    L --> E[VideoSummarizationEngine]
    E --> F[Sample video frames]
    F --> V[Vision image classification]
    V --> R[On-device Apple Intelligence selects meaningful moments and captions]
    R --> S[VideoSegment decisions]
    S --> T[Editable highlight timeline]
    T --> C[AVMutableComposition]
    C --> X[Filtered MP4 export]
    X --> SH[Share sheet]
    T --> PR[VideoProject metadata]
    PR --> AU[Firebase anonymous authentication]
    AU --> FS[Cloud Firestore project document]
```

Video selection, frame analysis, highlight reasoning, timeline editing, and
MP4 export run locally. The app analyzes up to 60 sampled frames with Vision,
then asks the system Foundation Model for a highlight selection, reasons, and
captions. It sends frame labels—not the source video—to the on-device model.
There is no heuristic or canned-result fallback: summarization reports an
error if Apple Intelligence is unavailable or the model response is invalid.
Firebase sync saves project metadata and segment details; the source video
itself is not uploaded. Sync requires an app-specific
`GoogleService-Info.plist` and Anonymous authentication enabled in Firebase.

## User interaction

```mermaid
flowchart TD
    O[Open SnippetAI] --> I[Import Video]
    I --> P[Preview and scrub video]
    P --> D[Choose summary length and platform]
    D --> A[AI Summarize]
    A --> R[Review selected highlight segments]
    R --> ED{Edit timeline?}
    ED -- Yes --> SP[Split or mute current segment]
    SP --> R
    ED -- No --> EX[Export filtered highlights]
    EX --> SH[Share exported MP4]
    R --> SY[Sync Project]
    SY --> FB{Firebase configured?}
    FB -- Yes --> CL[Save project metadata to Firestore]
    FB -- No --> ER[Show setup error]
    O --> CO[Review privacy and compliance notes]
```

## Build and run

Open `SnippetAI.xcodeproj`, select the `SnippetAI` scheme and an iOS Simulator
or device, and build. Firebase Auth, Core, and Firestore are declared as Swift
Package Manager dependencies and the resolved versions are tracked in the
workspace.

To enable cloud sync:

1. Register the iOS app in Firebase using bundle identifier
   `com.thirtyapps.SnippetAI`.
2. Add the generated `GoogleService-Info.plist` to the `SnippetAI` app target.
3. Enable Anonymous sign-in in Firebase Authentication and create a Firestore
   database.

Without that plist the app still launches and local editing/export work; sync
shows a configuration error rather than silently skipping the save.

Build from the command line:

```sh
xcodebuild -project SnippetAI.xcodeproj \
  -scheme SnippetAI \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  build
```

The analysis uses Vision's image classifier and the system Foundation Model; no
bundled Core ML model or saved analysis values are required. The model selects
from frame descriptions on each run. Audio and speech transcription are not
currently analyzed.
