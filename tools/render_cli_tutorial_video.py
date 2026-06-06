#!/usr/bin/env python3
"""Render a short CrashSimulator CLI tutorial video.

Generated assets:
  - assets/tutorial/crashsimulator_cli_tutorial.mp4
  - assets/tutorial/crashsimulator_cli_tutorial_subtitles.vtt
  - assets/tutorial/README.md

Dependencies:
  python3 -m pip install pillow imageio imageio-ffmpeg
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import imageio.v2 as imageio
import numpy as np
from PIL import Image, ImageDraw, ImageFont


WIDTH = 1920
HEIGHT = 1080
FPS = 12
TOTAL_SECONDS = 72

REPO_ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = REPO_ROOT / "assets" / "tutorial"
VIDEO_PATH = OUT_DIR / "crashsimulator_cli_tutorial.mp4"
SUBTITLE_PATH = OUT_DIR / "crashsimulator_cli_tutorial_subtitles.vtt"
README_PATH = OUT_DIR / "README.md"
TAGLINE = "Setup, protect, execute, recover, and validate an Oracle Database crash drill from the CLI"
FOOTER_TEXT = "CrashSimulator | Oracle HA/DR and backup/recovery practice | CLI workflow"


@dataclass(frozen=True)
class Scene:
    start: float
    end: float
    title: str
    label: str
    subtitle: str
    lines: tuple[str, ...]


SCENES: tuple[Scene, ...] = (
    Scene(
        0,
        6,
        "CrashSimulator CLI Tutorial",
        "Overview",
        "This tutorial shows how to set up CrashSimulator and run a complete CLI drill in a non-production Oracle lab.",
        (
            "$ ./CrashSimulatorV2.sh --help",
            "CrashSimulator V2 - Oracle HA/DR/backup and recovery practice framework",
            "",
            "Default mode is safe: dry-run planning.",
            "Destructive actions require --execute and confirmation.",
        ),
    ),
    Scene(
        6,
        14,
        "1. Install The Tool",
        "Install",
        "Download the repository, unzip it on the database server, and make the scripts executable.",
        (
            "$ unzip crashsimulator-main.zip",
            "$ cd crashsimulator-main",
            "$ chmod +x CrashSimulatorV2.sh crashsim_run_baseline_backup.sh",
            "$ chmod +x crashsim_prepare_redundant_gi_lab.sh",
            "",
            "Tip: run only in an approved resilience-test environment.",
        ),
    ),
    Scene(
        14,
        22,
        "2. Set The Oracle Environment",
        "Oracle Env",
        "Switch to the Oracle software owner and export the target ORACLE_HOME, ORACLE_SID, and PATH.",
        (
            "$ sudo su - oracle",
            "$ export ORACLE_HOME=/u02/app/oracle/product/19.0.0.0/dbhome_1",
            "$ export ORACLE_SID=crashdb1",
            "$ export ORACLE_UNQNAME=crashdb",
            "$ export PATH=$ORACLE_HOME/bin:/u01/app/19.0.0.0/gridhome_1/bin:$PATH",
            "$ cd /tmp/crashsimulator",
        ),
    ),
    Scene(
        22,
        31,
        "3. Discover And Check Health",
        "Discover",
        "Before choosing a drill, discover topology and confirm the CDB and PDB are healthy.",
        (
            "$ ./CrashSimulatorV2.sh --discover",
            "Database: CRASHDB  Role: PRIMARY  CDB: YES",
            "Storage: ASM       Cluster: RAC",
            "PDBs: CRASHPDB READ WRITE",
            "",
            "$ ./CrashSimulatorV2.sh --health-check --pdb CRASHPDB",
            "V$RECOVER_FILE: no rows",
            "V$DATABASE_BLOCK_CORRUPTION: no rows",
        ),
    ),
    Scene(
        31,
        39,
        "4. Validate The Scenario",
        "Validate",
        "Use readiness validation first. The tool checks topology, target selection, and scenario guardrails.",
        (
            "$ ./CrashSimulatorV2.sh --validate-scenario 30 --pdb CRASHPDB",
            "Scenario 30: PDB loss of one non-system datafile",
            "Result: RUNNABLE",
            "Reason: Requirements passed and target selection produced executable actions.",
            "",
            "$ ./CrashSimulatorV2.sh --scenario 30 --pdb CRASHPDB --dry-run",
            "Planned actions:",
            " 1. asm_rm +DATACRASHDB/.../DATAFILE/users...",
        ),
    ),
    Scene(
        39,
        47,
        "5. Protect The Target",
        "Protect",
        "For datafile drills, run protection first so RMAN backs up the exact FILE# and current control file.",
        (
            "$ ./CrashSimulatorV2.sh --protect 30 --pdb CRASHPDB --execute",
            "Type PROTECT-30 to continue:",
            "PROTECT-30",
            "",
            "Protection target datafiles:",
            "  FILE# 13  CRASHPDB  USERS  +DATACRASHDB/.../users...",
            "Backup tag: CSIM30_YYYYMMDD_HH24MISS",
        ),
    ),
    Scene(
        47,
        55,
        "6. Execute The Crash Drill",
        "Execute",
        "Execute only after reviewing the dry-run plan, runbook hints, and protection evidence.",
        (
            "$ ./CrashSimulatorV2.sh --scenario 30 --pdb CRASHPDB --execute",
            "Type EXECUTE-30 to continue:",
            "EXECUTE-30",
            "",
            "Planned actions:",
            " 1. asm_rm +DATACRASHDB/.../DATAFILE/users...",
            "asmcmd rm +DATACRASHDB/.../users...",
        ),
    ),
    Scene(
        55,
        64,
        "7. Recover From The Manifest",
        "Recover",
        "Recover with the executed scenario manifest so the helper knows the exact FILE#, PDB, and target path.",
        (
            "$ ./CrashSimulatorV2.sh --recover 30 \\",
            "    --pdb CRASHPDB \\",
            "    --manifest crashsim_scenario_s30_<run_id>.manifest \\",
            "    --execute",
            "",
            "RMAN:",
            "  restore datafile 13;",
            "  recover datafile 13;",
            "SQL: alter pluggable database CRASHPDB open;",
        ),
    ),
    Scene(
        64,
        72,
        "8. Validate And Preserve Evidence",
        "Validate",
        "Finish with health checks, backup validation, and preserved logs/manifests for audit, training, and lessons learned.",
        (
            "$ ./CrashSimulatorV2.sh --health-check --pdb CRASHPDB",
            "Database: READ WRITE",
            "CRASHPDB: READ WRITE",
            "V$RECOVER_FILE: no rows",
            "V$DATABASE_BLOCK_CORRUPTION: no rows",
            "",
            "$ ./CrashSimulatorV2.sh --backup-report --html",
            "Keep the manifest, RMAN logs, health checks, and audit record.",
        ),
    ),
)


def rgba(hex_value: str, alpha: int = 255, base: tuple[int, int, int] = (15, 24, 30)) -> tuple[int, int, int]:
    raw = hex_value.strip("#")
    if len(raw) == 3:
        raw = "".join(ch * 2 for ch in raw)
    r, g, b = int(raw[0:2], 16), int(raw[2:4], 16), int(raw[4:6], 16)
    if alpha >= 255:
        return (r, g, b)
    opacity = alpha / 255
    return (
        int(r * opacity + base[0] * (1 - opacity)),
        int(g * opacity + base[1] * (1 - opacity)),
        int(b * opacity + base[2] * (1 - opacity)),
    )


def font(paths: Iterable[str], size: int) -> ImageFont.FreeTypeFont:
    for item in paths:
        path = Path(item)
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default(size=size)


FONT_REGULAR = font(
    (
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ),
    26,
)
FONT_BOLD = font(
    (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ),
    56,
)
FONT_STEP = font(("/System/Library/Fonts/Supplemental/Arial Bold.ttf",), 18)
FONT_TERMINAL = font(("/System/Library/Fonts/Menlo.ttc", "/System/Library/Fonts/Monaco.ttf"), 25)
FONT_TERMINAL_TITLE = font(("/System/Library/Fonts/Menlo.ttc",), 22)
FONT_SUBTITLE = font(("/System/Library/Fonts/HelveticaNeue.ttc",), 32)
FONT_FOOTER = font(("/System/Library/Fonts/HelveticaNeue.ttc",), 20)


def build_background() -> Image.Image:
    stops = (
        (0.0, np.array((0x0B, 0x13, 0x20), dtype=np.float32)),
        (0.45, np.array((0x13, 0x25, 0x2C), dtype=np.float32)),
        (1.0, np.array((0x15, 0x15, 0x16), dtype=np.float32)),
    )
    x = np.linspace(0, 1, WIDTH, dtype=np.float32)
    y = np.linspace(0, 1, HEIGHT, dtype=np.float32)[:, None]
    mix = (x * 0.58 + y * 0.42).clip(0, 1)
    rgb = np.zeros((HEIGHT, WIDTH, 3), dtype=np.float32)
    for (left_pos, left_color), (right_pos, right_color) in zip(stops, stops[1:]):
        mask = (mix >= left_pos) & (mix <= right_pos)
        local = ((mix - left_pos) / (right_pos - left_pos)).clip(0, 1)
        color = left_color * (1 - local[..., None]) + right_color * local[..., None]
        rgb = np.where(mask[..., None], color, rgb)
    return Image.fromarray(rgb.astype(np.uint8), "RGB")


BASE_BACKGROUND = build_background()


def text_width(draw: ImageDraw.ImageDraw, text: str, selected_font: ImageFont.ImageFont) -> int:
    if not text:
        return 0
    bbox = draw.textbbox((0, 0), text, font=selected_font)
    return bbox[2] - bbox[0]


def wrap_text(draw: ImageDraw.ImageDraw, text: str, max_width: int, selected_font: ImageFont.ImageFont) -> list[str]:
    words = text.split()
    lines: list[str] = []
    line = ""
    for word in words:
        candidate = word if not line else f"{line} {word}"
        if text_width(draw, candidate, selected_font) <= max_width or not line:
            line = candidate
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def current_scene(t: float) -> Scene:
    for scene in SCENES:
        if scene.start <= t < scene.end:
            return scene
    return SCENES[-1]


def ease_out_cubic(value: float) -> float:
    clamped = max(0.0, min(1.0, value))
    return 1 - pow(1 - clamped, 3)


def line_color(line: str) -> tuple[int, int, int, int]:
    if line.startswith("$"):
        return rgba("#93c5fd")
    if any(token in line for token in ("RUNNABLE", "READ WRITE", "no rows", "Backup tag")):
        return rgba("#86efac")
    if line.startswith("Type") or line.startswith("PROTECT") or line.startswith("EXECUTE"):
        return rgba("#fcd34d")
    return rgba("#ecf4ff", 230)


def draw_header(draw: ImageDraw.ImageDraw, scene: Scene) -> None:
    draw.text((92, 48), scene.title, font=FONT_BOLD, fill=rgba("#f7fbff"))
    draw.text(
        (94, 126),
        TAGLINE,
        font=FONT_REGULAR,
        fill=rgba("#f5f9ff", 184),
    )

    start_x = 94
    step_y = 184
    available = WIDTH - start_x * 2
    gap = 12
    step_w = int((available - gap * (len(SCENES) - 1)) / len(SCENES))
    for index, step in enumerate(SCENES):
        x = start_x + index * (step_w + gap)
        active = step.title == scene.title
        draw.rounded_rectangle(
            (x, step_y, x + step_w, step_y + 42),
            radius=21,
            fill=rgba("#34d399") if active else rgba("#ffffff", 41),
        )
        label_w = text_width(draw, step.label, FONT_STEP)
        draw.text(
            (x + (step_w - label_w) / 2, step_y + 12),
            step.label,
            font=FONT_STEP,
            fill=rgba("#062018") if active else rgba("#ffffff", 194),
        )


def draw_terminal(draw: ImageDraw.ImageDraw, scene: Scene, t: float) -> None:
    x, y, w, h = 94, 260, 1732, 600
    draw.rounded_rectangle((x, y, x + w, y + h), radius=18, fill=rgba("#050a10", 240), outline=rgba("#ffffff", 41), width=2)
    draw.rounded_rectangle((x, y, x + w, y + 62), radius=18, fill=rgba("#121a25"))
    draw.ellipse((x + 25, y + 21, x + 45, y + 41), fill=rgba("#ff5f57"))
    draw.ellipse((x + 57, y + 21, x + 77, y + 41), fill=rgba("#febc2e"))
    draw.ellipse((x + 89, y + 21, x + 109, y + 41), fill=rgba("#28c840"))
    draw.text(
        (x + 140, y + 16),
        "oracle@crashlab:/tmp/crashsimulator",
        font=FONT_TERMINAL_TITLE,
        fill=rgba("#ffffff", 184),
    )

    local_t = t - scene.start
    duration = scene.end - scene.start
    reveal = ease_out_cubic(local_t / max(1, duration - 1))
    total_chars = sum(len(line) + 1 for line in scene.lines)
    chars_to_show = int(total_chars * reveal)
    shown = 0
    line_y = y + 100
    line_height = 38
    cursor_x = x + 46
    cursor_y = line_y
    for line in scene.lines:
        remaining = chars_to_show - shown
        visible_count = max(0, min(len(line), remaining))
        visible = line[:visible_count]
        shown += len(line) + 1
        draw.text((x + 46, line_y), visible, font=FONT_TERMINAL, fill=line_color(line))
        if visible:
            cursor_x = x + 46 + text_width(draw, visible, FONT_TERMINAL) + 4
            cursor_y = line_y
        line_y += line_height

    if int(t * 2) % 2 == 0 and chars_to_show >= total_chars:
        draw.rectangle((cursor_x, cursor_y + 8, cursor_x + 16, cursor_y + 36), fill=rgba("#34d399"))


def draw_subtitle(draw: ImageDraw.ImageDraw, scene: Scene) -> None:
    box_x = 230
    box_w = WIDTH - 460
    box_y = 884
    lines = wrap_text(draw, scene.subtitle, box_w - 90, FONT_SUBTITLE)
    box_h = max(78, 34 + len(lines) * 40)
    draw.rounded_rectangle(
        (box_x, box_y, box_x + box_w, box_y + box_h),
        radius=18,
        fill=rgba("#000000", 184),
        outline=rgba("#ffffff", 46),
        width=1,
    )
    for index, line in enumerate(lines):
        draw.text((box_x + 45, box_y + 18 + index * 40), line, font=FONT_SUBTITLE, fill=rgba("#ffffff"))


def draw_footer(draw: ImageDraw.ImageDraw, t: float) -> None:
    draw.text(
        (94, 1010),
        FOOTER_TEXT,
        font=FONT_FOOTER,
        fill=rgba("#ffffff", 148),
    )
    progress = max(0, min(1, t / TOTAL_SECONDS))
    draw.rounded_rectangle((94, 1040, WIDTH - 94, 1050), radius=5, fill=rgba("#ffffff", 46))
    draw.rounded_rectangle((94, 1040, int(94 + (WIDTH - 188) * progress), 1050), radius=5, fill=rgba("#34d399"))


def render_frame(t: float) -> Image.Image:
    frame = BASE_BACKGROUND.copy()
    draw = ImageDraw.Draw(frame)

    x_offset = int((t * 12) % 80)
    for x in range(-80 + x_offset, WIDTH + 80, 80):
        draw.line((x, 0, x, HEIGHT), fill=rgba("#ffffff", 14), width=1)
    y_offset = int((t * 8) % 80)
    for y in range(-80 + y_offset, HEIGHT + 80, 80):
        draw.line((0, y, WIDTH, y), fill=rgba("#ffffff", 14), width=1)

    scene = current_scene(t)
    draw_header(draw, scene)
    draw_terminal(draw, scene, t)
    draw_subtitle(draw, scene)
    draw_footer(draw, t)
    return frame.convert("RGB")


def webvtt_time(seconds: float) -> str:
    total_ms = round(seconds * 1000)
    ms = total_ms % 1000
    total_s = total_ms // 1000
    s = total_s % 60
    m = (total_s // 60) % 60
    h = total_s // 3600
    return f"{h:02d}:{m:02d}:{s:02d}.{ms:03d}"


def write_subtitles() -> None:
    chunks = ["WEBVTT", ""]
    for index, scene in enumerate(SCENES, start=1):
        chunks.append(str(index))
        chunks.append(f"{webvtt_time(scene.start)} --> {webvtt_time(scene.end)}")
        chunks.append(scene.subtitle)
        chunks.append("")
    SUBTITLE_PATH.write_text("\n".join(chunks), encoding="utf-8")


def write_readme() -> None:
    README_PATH.write_text(
        """# CrashSimulator Tutorial Videos

Generated assets:

- `crashsimulator_cli_tutorial.mp4`: short 1080p CLI setup and scenario tutorial with burned-in subtitles.
- `crashsimulator_cli_tutorial_with_audio.mp4`: narrated CLI setup and scenario tutorial generated from the subtitles.
- `crashsimulator_cli_tutorial_subtitles.vtt`: CLI tutorial WebVTT subtitle sidecar.
- `crashsimulator_guided_workflow_tutorial.mp4`: short 1080p Guided Workflow menu scenario tutorial with burned-in subtitles.
- `crashsimulator_guided_workflow_tutorial_with_audio.mp4`: narrated Guided Workflow menu scenario tutorial generated from the subtitles.
- `crashsimulator_guided_workflow_tutorial_subtitles.vtt`: Guided Workflow tutorial WebVTT subtitle sidecar.
- `crashsimulator_audit_retention_tutorial.mp4`: short 1080p audit retention tutorial for CLI and Guided Workflow menu modes with burned-in subtitles.
- `crashsimulator_audit_retention_tutorial_with_audio.mp4`: narrated audit retention tutorial generated from the subtitles.
- `crashsimulator_audit_retention_tutorial_subtitles.vtt`: audit retention tutorial WebVTT subtitle sidecar.
- `crashsimulator_scenario_readiness_tutorial.mp4`: short 1080p scenario readiness tutorial for CLI and Guided Workflow menu modes with burned-in subtitles.
- `crashsimulator_scenario_readiness_tutorial_with_audio.mp4`: narrated scenario readiness tutorial generated from the subtitles.
- `crashsimulator_scenario_readiness_tutorial_subtitles.vtt`: scenario readiness tutorial WebVTT subtitle sidecar.

Regenerate from the repository root with:

```bash
python3 -m pip install pillow imageio imageio-ffmpeg
python3 tools/render_cli_tutorial_video.py
python3 tools/render_guided_workflow_tutorial_video.py
python3 tools/render_audit_retention_tutorial_video.py
python3 tools/render_scenario_readiness_tutorial_video.py
```

On macOS, regenerate the narrated copies from the subtitle scripts with:

```bash
python3 tools/add_tutorial_audio.py --voice Samantha --rate 175
```

The tutorial set demonstrates direct CLI execution, the menu-driven
best-practice scenario workflow, audit-retention operations, and topology-aware
scenario readiness reporting. The readiness tutorial covers generating the
environment-versus-scenario report, reading the runnable/blocked buckets, using
`latest:scenario-readiness`, and launching the same capability from the Guided
Workflow menu.
""",
        encoding="utf-8",
    )


def render_video() -> None:
    total_frames = int(TOTAL_SECONDS * FPS)
    if VIDEO_PATH.exists():
        VIDEO_PATH.unlink()

    with imageio.get_writer(
        VIDEO_PATH,
        fps=FPS,
        codec="libx264",
        quality=8,
        macro_block_size=1,
        ffmpeg_params=["-pix_fmt", "yuv420p", "-movflags", "+faststart"],
    ) as writer:
        for frame_no in range(total_frames):
            t = frame_no / FPS
            frame = render_frame(t)
            writer.append_data(np.asarray(frame))
            if frame_no % (FPS * 6) == 0:
                pct = int((frame_no / total_frames) * 100)
                print(f"Rendering frame {frame_no}/{total_frames} ({pct}%)")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    write_subtitles()
    write_readme()
    render_video()
    print(f"Wrote {VIDEO_PATH}")
    print(f"Size: {VIDEO_PATH.stat().st_size / 1024 / 1024:.2f} MB")
    print(f"Subtitles: {SUBTITLE_PATH}")


if __name__ == "__main__":
    main()
