#!/usr/bin/env python3
"""
External offline model downloader for Personal Video Studio (macOS Apple Silicon).

This script runs OUTSIDE the sandboxed macOS app (which has no network-client
entitlement). It downloads free, open-weight Visual-Text Image-to-Video and
Audio-Driven Lip-Sync checkpoints from Hugging Face into a local folder and
writes a validated `model_manifest.json` so you can import the folder offline
inside Personal Video Studio -> Local AI Models.

Usage:
  python3 Scripts/download_offline_models.py --preset wan2.1-echomimic
  python3 Scripts/download_offline_models.py --preset ltx-echomimic
"""

import argparse
import json
from pathlib import Path
import sys

try:
    from huggingface_hub import snapshot_download
except ImportError:
    print(
        "Missing dependency 'huggingface_hub'. Install in a venv first:\n"
        "  python3 -m venv \"$HOME/.venvs/pvs-video-models\"\n"
        "  \"$HOME/.venvs/pvs-video-models/bin/python\" -m pip install --upgrade huggingface_hub",
        file=sys.stderr,
    )
    sys.exit(1)


PRESETS = {
    "wan2.1-echomimic": {
        "architecture": "wan2.1_i2v_480p_echomimic_v3",
        "runtime": "mlx",
        "min_unified_memory_gb": 24,
        "max_clip_duration_seconds": 8.0,
        "visual_text_repo": "Wan-AI/Wan2.1-I2V-14B-480P",
        "lipsync_repo": "BadToBest/EchoMimicV3",
        "notes": "Stage 1: Wan2.1-I2V (Apache 2.0). Stage 2: EchoMimicV3 (Apache 2.0).",
    },
    "ltx-echomimic": {
        "architecture": "ltx_video_i2v_echomimic_v2",
        "runtime": "mlx",
        "min_unified_memory_gb": 16,
        "max_clip_duration_seconds": 8.0,
        "visual_text_repo": "Lightricks/LTX-Video",
        "lipsync_repo": "BadToBest/EchoMimicV2",
        "notes": "Stage 1: LTX-Video (verify model card license). Stage 2: EchoMimicV2 (Apache 2.0).",
    },
}


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Download offline Visual-Text I2V + Audio Lip-Sync weights for Personal Video Studio."
    )
    parser.add_argument(
        "--preset",
        choices=sorted(PRESETS.keys()),
        default="wan2.1-echomimic",
        help="Model pair preset to download.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path.home() / "Downloads" / "PersonalVideoStudio-OfflineModels",
        help="Destination folder to import into Personal Video Studio.",
    )
    parser.add_argument(
        "--skip-visual-text",
        action="store_true",
        help="Download only the audio lip-sync stage.",
    )
    args = parser.parse_args()

    preset = PRESETS[args.preset]
    root_dir: Path = args.output_dir.expanduser().resolve()
    visual_dir = root_dir / "visual_text"
    lipsync_dir = root_dir / "lipsync"
    root_dir.mkdir(parents=True, exist_ok=True)

    if not args.skip_visual_text:
        print(f"Downloading Stage 1 Visual-Text I2V model: {preset['visual_text_repo']}")
        snapshot_download(repo_id=preset["visual_text_repo"], local_dir=visual_dir)

    print(f"Downloading Stage 2 Audio Lip-Sync model: {preset['lipsync_repo']}")
    snapshot_download(repo_id=preset["lipsync_repo"], local_dir=lipsync_dir)

    manifest = {
        "model_type": preset["architecture"],
        "runtime": preset["runtime"],
        "supports_image_to_video": not args.skip_visual_text,
        "supports_behavior_text_prompt": not args.skip_visual_text,
        "supports_hand_and_body_motion": not args.skip_visual_text,
        "supports_lip_sync": True,
        "supports_audio_conditioning": True,
        "min_unified_memory_gb": preset["min_unified_memory_gb"],
        "max_clip_duration_seconds": preset["max_clip_duration_seconds"],
        "visual_text_repo": None if args.skip_visual_text else preset["visual_text_repo"],
        "lipsync_repo": preset["lipsync_repo"],
        "notes": preset["notes"],
    }
    manifest_path = root_dir / "model_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print("\nOffline model bundle ready at:", root_dir)
    print("Next step: Open Personal Video Studio -> Local AI Models -> Import Local Model Folder...")


if __name__ == "__main__":
    main()
