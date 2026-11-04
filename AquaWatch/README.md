# AquaWatch

AquaWatch is an Apple Watch hydration-tracking prototype. It uses wrist motion to recognize a drinking-like gesture, prompts you to verify the drink, and can record the confirmed volume as dietary water in Apple Health.

## App screenshot

![AquaWatch running in the Apple Watch simulator](Screenshots/AquaWatch-watch-simulator.png)

## Motive

Hydration tracking often depends on remembering to open an app and enter every drink. AquaWatch explores a lower-friction alternative: notice a likely sip from wrist movement, offer a quick confirmation, and keep manual logging one tap away. The goal is to make hydration habits easier to track without turning the watch into a complicated logging tool.

## Why integrate with Apple Health?

With permission, AquaWatch saves confirmed entries as dietary water in Apple Health. This can help people:

- Keep hydration records alongside other health information in one place.
- Review intake over time and notice personal routines.
- Make AquaWatch entries available to other apps that use Apple Health data, subject to the user's permissions.

HealthKit authorization is controlled by the user. This prototype writes dietary water samples; it does not calculate personalized hydration targets, read back a daily total, or provide medical advice.

## User journey

```mermaid
journey
    title AquaWatch hydration logging
    section Set up
      Open AquaWatch and allow Health access: 4: User
      Wrist motion monitoring starts: 4: AquaWatch
    section Log a drink
      Lift and tilt a glass or bottle: 5: User
      Drinking-like motion is detected: 4: AquaWatch
      Review drink and volume, then confirm: 4: User
      Or tap Quick +250ml to log manually: 4: User
    section Review
      Hydration entry is saved to Apple Health: 4: AquaWatch
      Review hydration with other Health data: 4: User
```

## Data flow

```mermaid
flowchart LR
    A[Apple Watch motion sensors] --> B[CoreMotion samples at 50 Hz]
    B --> C[On-device tilt and duration heuristic]
    C --> D{Drinking-like gesture?}
    D -- No --> B
    D -- Yes --> E[Haptic prompt and volume confirmation]
    E --> F[User confirms amount]
    G[Quick add button] --> H[250 ml manual entry]
    F --> I[HealthKit dietary water sample]
    H --> I
    I --> J[Apple Health hydration history]
    K[Health access permission] -. required to save .-> I
```

## Run in the Apple Watch simulator

1. Open `AquaWatch.xcodeproj` in Xcode.
2. Select the **AquaWatch** scheme and an Apple Watch simulator.
3. Press **Run** (⌘R).
4. Allow motion and Health access when prompted. On the main screen, use **Quick +250ml** to test a manual entry; motion-triggered logging can be tested by simulating a drinking-like wrist tilt.

The app requires watchOS 10 or later. A physical watch can also be selected as the run destination with signing configured for your Apple Developer team.
