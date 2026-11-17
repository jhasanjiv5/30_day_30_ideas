# Third-Party Licenses & Open Offline Models

`PersonalVideoStudio` ships with **zero external Swift package dependencies** in its MVP build. All project management, storyboard composition, still-image motion, audio mixing, playback preview, and local `.mp4` rendering use native Apple macOS system frameworks (`SwiftUI`, `AVFoundation`, `AVKit`, `CoreImage`, `CoreGraphics`, `CoreMedia`, `AppKit`, `OSLog`).

## Free / Open-Weight Offline Models Supported via Local Import

`PersonalVideoStudio` does **not** bundle, download, or redistribute AI model weights. To enable on-device **Visual-Text Image-to-Video** (subject action/hand motion + scene generation) and **Audio-Driven Portrait Lip-Sync** in future or locally linked Apple Silicon MLX/CoreML builds, use free, open-weight models whose licenses fit your project:

### 1. Stage 1 — Visual-Text Image-to-Video (Subject Action & Scene Generation)
- **Wan2.1-I2V / Wan2.2-I2V (Wan-AI)**: **Apache License 2.0** (free for personal and commercial offline use with attribution). Converts supplied reference image(s) + a behavior text prompt (e.g., *"woman strumming acoustic guitar with natural hand movement"*) into motion frames. Runnable on Apple Silicon via **Apple MLX** (**MIT / Apache 2.0**, e.g. `mlx-video` / `rapid-mlx`).
- **LTX-Video (Lightricks)**: Fast lightweight Image-to-Video model; verify the exact Hugging Face checkpoint model card license before commercial use.

### 2. Stage 2 — Audio-Driven Portrait Lip-Sync (Music / Narration Sync)
- **EchoMimic / EchoMimicV2 / EchoMimicV3**: **Apache License 2.0** (audio-driven portrait & semi-body lip-sync animation).
- **Hallo2**: **MIT License** for core pipeline (note: optional face-restoration components such as CodeFormer carry S-Lab License 1.0).
- **LatentSync-MLX**: Community **Apple MLX** diffusion lip-sync port optimized for Apple Silicon unified memory (verify upstream open-rail terms for commercial deployment).

### Required Local Attribution
- Retain upstream `LICENSE` and `NOTICE` files inside any model folder imported into `models/scene-generation/active/`.
- Unless a compatible local inference runtime is linked and valid weights are imported on Apple Silicon with sufficient unified memory, AI scene generation remains **Unavailable** and is never fabricated or routed to cloud services.
