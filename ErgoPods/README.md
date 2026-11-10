# ErgoPods

ErgoPods is an iOS SwiftUI prototype for posture tracking with AirPods motion, Apple Health metrics, and physiotherapy guidance.

## Project structure

- `ErgoPods/App/ErgoPodsApp.swift` creates the shared motion and HealthKit managers and injects them into the app.
- `ErgoPods/Managers/` contains the CoreMotion and HealthKit integrations.
- `ErgoPods/Views/` contains the Posture, HealthKit, Physio, Badges, and onboarding screens.
- `ErgoPods/Models/OnDevicePhysioReasoningModel.swift` contains the rule-based prescription logic.
- `ErgoPods/LiveActivity/DynamicIslandPostureWidget.swift` defines a Live Activity widget.
- `Package.swift` currently defines a Swift package library; it does not define a runnable iOS app target.

## Data flow

```mermaid
flowchart TD
    App["ErgoPodsApp"] --> MotionMgr["HeadphoneMotionManager"]
    App --> HealthMgr["AppleHealthKitManager"]
    App --> UI["SwiftUI tab interface"]
    MotionMgr --> CoreMotion["CMHeadphoneMotionManager"]
    CoreMotion --> Angles["Pitch, roll, yaw"]
    Angles --> MotionMgr
    MotionMgr --> Posture["Posture screen"]
    MotionMgr --> Sitting["Sitting timer"]
    MotionMgr --> Physio["Physio screen"]
    MotionMgr --> HealthView["HealthKit screen"]
    HealthMgr --> HealthKit["HealthKit authorization"]
    HealthKit --> Steps["Today's step-count query"]
    HealthKit --> HeartRate["Heart-rate observer and latest sample query"]
    Steps --> HealthMgr
    HeartRate --> HealthMgr
    HealthMgr --> HealthView
    HealthMgr --> Physio
    Profile["Office / elderly profile"] --> Rules["Local rule-based evaluation"]
    MotionMgr --> Rules
    HealthMgr --> Rules
    Rules --> Physio
    Physio --> Prescription["Assessment, steps, and exercise instructions"]
```

Motion angles are published by the motion manager; calibration stores pitch and roll baselines, and the published pitch is used by the posture UI and prescription rules. The sitting timer starts when the manager is created and advances once per second until the user resets it. HealthKit authorization is requested at manager initialization. When authorized, the current implementation queries today's step total and observes heart-rate updates.

## User interaction

```mermaid
flowchart TD
    User["User"] --> Launch["Launch app"]
    Launch --> Posture["Posture tab (initial screen)"]
    Posture --> SensorAction{"Sensor connection"}
    SensorAction -->|"Connected: Calibrate"| Calibration["Capture neutral pitch and roll"]
    SensorAction -->|"Disconnected: Reconnect"| Retry["Restart motion updates"]
    Posture --> Settings["Open settings button"]
    Settings --> Onboarding["View live sensor values and movement checks"]
    Onboarding -->|"Complete onboarding"| Calibration
    Onboarding -->|"Close"| Posture
    User --> Tabs["Select a tab"]
    Tabs --> Health["HealthKit tab"]
    Health -->|"Stood Up"| Reset["Reset sitting timer"]
    Tabs --> Physio["Physio tab"]
    Physio --> Profile["Choose Office Ergonomics or Elderly Mobility Care"]
    Profile --> Advice["View current rule-based guidance"]
    Advice --> Exercise["Toggle guided-exercise state"]
    Tabs --> Badges["Badges tab"]
    Badges --> Static["View predefined badge statuses"]
```

The onboarding sheet is opened manually from the Posture screen; it is not shown automatically on first launch. Starting or pausing the exercise currently changes a UI state only; it does not run a countdown or audio cue.

## Build and run

The checked-in Swift package exposes a library, not an iOS app executable, and there is no `.xcodeproj` in this repository. Therefore the package can be compiled, but the app cannot currently be launched directly from the checked-in project structure.

To compile the package for the iOS Simulator:

```sh
swift build \
  --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  --triple arm64-apple-ios18.0-simulator
```

To run the app, create an iOS App target in Xcode and add the `ErgoPods` source files to that target. Set the deployment target to iOS 18 or later, configure the HealthKit capability, and include the privacy descriptions from `ErgoPods/Info.plist`. AirPods motion tracking requires compatible hardware paired to an iPhone; simulator builds do not validate that sensor flow.

## Current implementation notes

- Physiotherapy recommendations are produced by deterministic Swift rules, not a Core ML or Foundation Models inference call.
- HealthKit currently reads today's step total and latest heart rate. Other displayed health values (including resting heart rate and HRV) are initialized placeholders; no standing-hours query or HealthKit write is implemented.
- Badge states are predefined in the view and are not calculated from activity.
- The Live Activity widget type is defined but is not started or updated by the app.
