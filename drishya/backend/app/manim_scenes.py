"""Manim Community 2D scene generator and FFmpeg assembler for Drishya."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any


def generate_manim_scene_script(scene_spec: dict[str, Any], output_py: Path) -> Path:
    """Writes a parameterized Manim Community Scene file for diagram/chart/equation/figure specs."""
    kind = scene_spec.get("visualSpec", {}).get("kind", "takeaway")
    title = scene_spec.get("chapterTitle", "Drishya Scene").replace('"', "'")
    spec_json = json.dumps(scene_spec.get("visualSpec", {}))

    script = f'''from manim import *
import json

SPEC = json.loads({spec_json!r})

class DrishyaScene(Scene):
    def construct(self):
        self.camera.background_color = "#0B1120"
        header = Text("{title}", font_size=32, color=WHITE).to_edge(UP)
        self.play(FadeIn(header))
        kind = "{kind}"
        if kind == "equation":
            eq = MathTex(SPEC.get("latex", "y = mx + b"), font_size=40)
            self.play(Write(eq))
        elif kind == "chart":
            series = SPEC.get("resolvedSeries", [])
            labels = [r.get("label", "") for r in series]
            y_cols = SPEC.get("yColumns", ["RMSE_5d"])
            vals = [float(r.get("values", {{}}).get(y_cols[0], 0)) for r in series] or [1.0]
            chart = BarChart(values=vals, bar_names=labels, y_range=[0, max(vals) * 1.2, 5])
            self.play(Create(chart))
        elif kind == "diagram":
            boxes = VGroup(*[
                RoundedRectangle(width=2.6, height=1.1, corner_radius=0.12, color=BLUE_C).add(
                    Text(n.get("label", ""), font_size=16)
                )
                for n in SPEC.get("nodes", [])
            ]).arrange(RIGHT, buff=0.4)
            self.play(LaggedStart(*[FadeIn(b) for b in boxes], lag_ratio=0.25))
        else:
            subtitle = Text(SPEC.get("subtitle", ""), font_size=24, color=BLUE_B)
            self.play(FadeIn(subtitle))
        self.wait(1)
'''
    output_py.write_text(script, encoding="utf-8")
    return output_py


def assemble_scenes_ffmpeg(
    scene_mp4s: list[Path], vtt_path: Path, output_mp4: Path
) -> Path:
    """Concatenates rendered Manim scene MP4s and muxes WebVTT captions with FFmpeg."""
    concat_file = output_mp4.parent / "concat.txt"
    concat_file.write_text(
        "\n".join(f"file '{p.resolve()}'" for p in scene_mp4s), encoding="utf-8"
    )
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(concat_file),
            "-i",
            str(vtt_path),
            "-c:v",
            "libx264",
            "-c:a",
            "aac",
            "-c:s",
            "mov_text",
            str(output_mp4),
        ],
        check=True,
    )
    return output_mp4
