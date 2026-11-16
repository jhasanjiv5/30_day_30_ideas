# Third-Party Licenses & Attribution

Personal Voice Studio relies exclusively on open-source packages and open model weights when configured for Apple Silicon on-device inference. No closed cloud APIs or proprietary runtime services are used.

## 1. Inference Engine (Optional Apple Silicon Package)

- **Package**: `mlx-audio-swift` (`MLXAudioCore`, `MLXAudioTTS`)
- **Repository**: https://github.com/Blaizzy/mlx-audio-swift
- **Author / Contributors**: Prince Canuma (Blaizzy) and `mlx-audio-swift` contributors
- **License**: MIT License
- **Underlying Framework**: Apple MLX / `mlx-swift` (MIT License)

## 2. Target On-Device Voice Cloning Model (User-Supplied Offline Weights)

- **Model**: `Qwen/Qwen3-TTS-12Hz-0.6B-Base` (and MLX-quantized derivative `mlx-community/Qwen3-TTS-12Hz-0.6B-Base-8bit`)
- **Version**: `12Hz-0.6B-Base`
- **Author / Organization**: Qwen Team, Alibaba Group
- **License**: Apache License 2.0
- **Distribution Notes**:
  - Apache License 2.0 permits personal, research, and commercial distribution provided the `LICENSE` and `NOTICE` attribution texts are retained.
  - Model weights (~650 MB–1.2 GB) are not bundled inside the repository and are never downloaded at runtime inside the app; users import an unpacked local folder offline.
