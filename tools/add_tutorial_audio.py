#!/usr/bin/env python3
"""Add friendly voice narration to CrashSimulator tutorial videos.

The script uses each tutorial WebVTT subtitle file as the narration script,
synthesizes audio locally with macOS `say`, and muxes the narration into a new
`*_with_audio.mp4` file without replacing the existing silent tutorial.

Dependencies:
  - macOS `say`
  - ffmpeg, or python package `imageio-ffmpeg`
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
TUTORIAL_DIR = REPO_ROOT / "assets" / "tutorial"
DEFAULT_VOICE = "Samantha"
DEFAULT_RATE = 175

DEFAULT_TUTORIALS = (
    "crashsimulator_cli_tutorial",
    "crashsimulator_guided_workflow_tutorial",
    "crashsimulator_audit_retention_tutorial",
    "crashsimulator_scenario_readiness_tutorial",
    "crashsimulator_guided_reports_menu_tutorial",
    "crashsimulator_apex_session_driver_tutorial",
    "crashsimulator_config_review_tutorial",
    "crashsimulator_adb_readiness_tutorial",
    "crashsimulator_adb_scenario_tutorial",
    "crashsimulator_best_practices_tutorial",
    "crashsimulator_prepare_environment_tutorial",
    "crashsimulator_first_run_public_readiness_tutorial",
    "crashsimulator_public_limitations_tutorial",
)


@dataclass(frozen=True)
class Cue:
    start: float
    end: float
    text: str


def parse_timestamp(value: str) -> float:
    hours, minutes, rest = value.strip().split(":")
    seconds, millis = rest.split(".")
    return (
        int(hours) * 3600
        + int(minutes) * 60
        + int(seconds)
        + int(millis) / 1000
    )


def parse_vtt(path: Path) -> list[Cue]:
    raw = path.read_text(encoding="utf-8")
    blocks = re.split(r"\n\s*\n", raw.strip())
    cues: list[Cue] = []
    for block in blocks:
        lines = [line.strip() for line in block.splitlines() if line.strip()]
        if not lines or lines[0] == "WEBVTT":
            continue
        timing_idx = next((i for i, line in enumerate(lines) if "-->" in line), -1)
        if timing_idx < 0:
            continue
        start_raw, end_raw = [part.strip().split()[0] for part in lines[timing_idx].split("-->")]
        text = " ".join(lines[timing_idx + 1 :]).strip()
        if text:
            cues.append(Cue(parse_timestamp(start_raw), parse_timestamp(end_raw), text))
    if not cues:
        raise RuntimeError(f"No subtitle cues found in {path}")
    return cues


def find_ffmpeg() -> str:
    env_path = os.environ.get("FFMPEG")
    if env_path:
        return env_path
    try:
        import imageio_ffmpeg

        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        pass
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg:
        return ffmpeg
    raise RuntimeError("ffmpeg was not found. Install ffmpeg or imageio-ffmpeg.")


def require_say() -> str:
    say = shutil.which("say")
    if not say:
        raise RuntimeError("macOS `say` command was not found.")
    return say


def run_command(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def synthesize_segments(cues: list[Cue], temp_dir: Path, voice: str, rate: int) -> list[Path]:
    say = require_say()
    segment_paths: list[Path] = []
    for index, cue in enumerate(cues, start=1):
        output = temp_dir / f"cue_{index:03d}.aiff"
        run_command([say, "-v", voice, "-r", str(rate), "-o", str(output), cue.text])
        if not output.exists() or output.stat().st_size <= 4096:
            raise RuntimeError(
                "macOS `say` produced an empty audio segment. "
                "Run this script in a local macOS session with audio synthesis access."
            )
        segment_paths.append(output)
    return segment_paths


def mux_audio(
    video_path: Path,
    cues: list[Cue],
    segments: list[Path],
    output_path: Path,
    ffmpeg: str,
    volume: float,
) -> None:
    duration = max(cue.end for cue in cues)
    cmd = [ffmpeg, "-y", "-i", str(video_path)]
    for segment in segments:
        cmd.extend(["-i", str(segment)])
    cmd.extend(["-f", "lavfi", "-i", f"anullsrc=r=44100:cl=stereo:d={duration:.3f}"])

    silent_input = len(segments) + 1
    filters: list[str] = []
    mix_labels = [f"[{silent_input}:a]"]
    for index, cue in enumerate(cues, start=1):
        delay_ms = int(round(cue.start * 1000))
        label = f"a{index}"
        filters.append(
            f"[{index}:a]aresample=44100,"
            f"aformat=sample_fmts=fltp:channel_layouts=stereo,"
            f"volume={volume},adelay={delay_ms}|{delay_ms}[{label}]"
        )
        mix_labels.append(f"[{label}]")

    filters.append(
        "".join(mix_labels)
        + f"amix=inputs={len(mix_labels)}:duration=first:dropout_transition=0,"
        + f"atrim=0:{duration:.3f},asetpts=N/SR/TB[aout]"
    )

    cmd.extend(
        [
            "-filter_complex",
            ";".join(filters),
            "-map",
            "0:v:0",
            "-map",
            "[aout]",
            "-c:v",
            "copy",
            "-c:a",
            "aac",
            "-b:a",
            "160k",
            "-movflags",
            "+faststart",
            str(output_path),
        ]
    )
    run_command(cmd)


def build_audio_video(stem: str, voice: str, rate: int, volume: float) -> Path:
    video_path = TUTORIAL_DIR / f"{stem}.mp4"
    subtitle_path = TUTORIAL_DIR / f"{stem}_subtitles.vtt"
    output_path = TUTORIAL_DIR / f"{stem}_with_audio.mp4"
    if not video_path.exists():
        raise RuntimeError(f"Missing video: {video_path}")
    if not subtitle_path.exists():
        raise RuntimeError(f"Missing subtitles: {subtitle_path}")

    cues = parse_vtt(subtitle_path)
    ffmpeg = find_ffmpeg()
    with tempfile.TemporaryDirectory(prefix=f"{stem}_audio_") as temp_raw:
        temp_dir = Path(temp_raw)
        segments = synthesize_segments(cues, temp_dir, voice, rate)
        mux_audio(video_path, cues, segments, output_path, ffmpeg, volume)
    return output_path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--voice", default=DEFAULT_VOICE, help="macOS say voice name")
    parser.add_argument("--rate", type=int, default=DEFAULT_RATE, help="speech rate in words per minute")
    parser.add_argument("--volume", type=float, default=1.0, help="narration volume multiplier")
    parser.add_argument(
        "tutorials",
        nargs="*",
        default=DEFAULT_TUTORIALS,
        help="tutorial basename(s), without .mp4",
    )
    args = parser.parse_args()

    for stem in args.tutorials:
        output = build_audio_video(stem, args.voice, args.rate, args.volume)
        print(f"Wrote {output}")


if __name__ == "__main__":
    main()
