# Role & Objective
Act as a Senior macOS & Apple Graphics/Game Systems Architect. Build a standalone, high-performance native macOS game application titled "[GAME_NAME]".

---

## 1. Project Specifications
- **Target OS**: macOS 14.0+ (Sonoma / Sequoia)
- **Tech Stack**: Swift 5.10+ / SwiftUI / SpriteKit (for 2D) OR RealityKit/Metal (for 3D)
- **Architecture**: MVVM or ECS (Entity Component System) separating game state, physics, rendering, and UI.
- **Form Factor**: Desktop windowed by default ([e.g., 1280x720]), resizable with fixed aspect ratio, supports macOS Fullscreen toggle (`Cmd + Enter`).

---

## 2. Core Game Loop & Gameplay
- **Genre & Theme**: [e.g., Fast-paced top-down arcade shopping cart run]
- **Core Loop**:
  1. [Step 1: Player spawns / receives objective]
  2. [Step 2: Collect/Dodge/Fight mechanics against timer or score]
  3. [Step 3: Progression, wave clearance, or Game Over]
- **Win / Loss Condition**: [Describe how a run ends and how score/stars are calculated]

---

## 3. macOS Native Input & Features
- **Controls**:
  - Keyboard: [e.g., WASD / Arrow keys for movement, Space for action/brake]
  - Mouse/Trackpad: [e.g., Aiming with cursor, click to interact]
  - Gamepad (Optional): Support Apple `GameController` framework (Xbox, PlayStation, MFi).
- **macOS Menu Bar & App Lifecycle**:
  - Standard menus: File (New Game, Restart, Quit), Game (Pause `Space`/`Esc`), Audio Mute.
  - Window state handling: Auto-pause game logic when window loses focus or app is hidden.

---

## 4. Visuals, Audio & UI
- **Rendering & Assets**:
  - Crisp Retina resolution rendering (`contentMode = .aspectFit` / `.resizeFill`).
  - Procedural / vector fallback graphics for all items so the game is immediately runnable without missing assets.
- **Audio**:
  - Sound effects manager using `AVAudioPlayer` or SpriteKit `SKAction.playSoundFileNamed`.
  - Placeholder synthetic audio generation or soft fallbacks when audio files are absent.
- **HUD & Menus**:
  - Clean SwiftUI overlay on top of the game canvas for: Start Menu, Pause Menu, Game Over / High Scores, and HUD (Timer, Score, Health).

---

## 5. Deliverables & Execution Requirements
Please build this in structured stages:
1. **File Tree & Architecture**: Output the project structure and explain each file's responsibility.
2. **Setup Instructions**: Exact steps to create the Xcode project / Swift Package Manager setup.
3. **Complete, Compilable Code**:
   - Provide complete code files with NO placeholder comments like `// TODO: implement later`.
   - Implement the full game loop, input handlers, collision detection, and score tracking.
4. **Run Verification**: Provide the exact CLI command or Xcode build steps (`swift run` or `xcodebuild`) to compile and test immediately.