#!/usr/bin/env python3
"""Render a CrashSimulator prepare-environment tutorial video."""

from __future__ import annotations

import render_cli_tutorial_video as renderer
from render_cli_tutorial_video import Scene


PREPARE_ENVIRONMENT_SCENES: tuple[Scene, ...] = (
    Scene(
        0,
        8,
        "Prepare Environment Tutorial",
        "Purpose",
        "The prepare-environment workflow detects which lab seeds and preparation steps are missing for the detected topology.",
        (
            "$ ./CrashSimulatorV2.sh --prepare-environment --dry-run --html",
            "Seed/prepare environment planner generated:",
            "  crashsim_prepare_environment_<run_id>.md",
            "",
            "Dry-run mode does not change the database.",
            "It builds a topology-aware preparation matrix.",
        ),
    ),
    Scene(
        8,
        18,
        "1. Run Safe Discovery First",
        "Discover",
        "Start with configuration, doctor, and discovery so the planner knows the database role, CDB/PDB posture, cluster type, and storage style.",
        (
            "$ ./CrashSimulatorV2.sh --show-config",
            "$ ./CrashSimulatorV2.sh --doctor --html",
            "$ ./CrashSimulatorV2.sh --discover",
            "",
            "Signals used:",
            "  role, CDB, PDB, RAC/GI, ASM/FEX/ACFS",
            "  redo/control-file posture, APEX/ORDS, FSFO",
        ),
    ),
    Scene(
        18,
        30,
        "2. Generate The Preparation Plan",
        "Dry-Run",
        "Use dry-run first. The report labels each preparation as present, missing, not required, conditional, or plan-only.",
        (
            "$ ./CrashSimulatorV2.sh --prepare-environment --dry-run --html",
            "",
            "Preparation Matrix:",
            "  logical_lab              PRESENT",
            "  redo_multiplex           MISSING",
            "  controlfile_multiplex    PLAN_ONLY",
            "  services_ac_tac          MISSING",
            "  asm_gi_redundant_lab     PLAN_ONLY",
        ),
    ),
    Scene(
        30,
        42,
        "3. Understand Guardrails",
        "Guardrails",
        "The planner can recommend helpers, but provider-specific and high-risk preparations remain explicit operator runbooks.",
        (
            "Auto-eligible examples:",
            "  seed disposable lab schemas",
            "  add redo members in supported lab posture",
            "  create AC/TAC lab services when GI privileges exist",
            "",
            "Plan-only examples:",
            "  control-file multiplexing with outage",
            "  FSFO enablement",
            "  ASM/FEX/ACFS redundant disk lab",
        ),
    ),
    Scene(
        42,
        54,
        "4. Guided Workflow Option 21",
        "Menu 21",
        "The same workflow is available in the Guided Workflow menu as option 21: Seed / prepare scenario lab for this topology.",
        (
            "$ ./CrashSimulatorV2.sh --menu",
            "",
            "Guided Workflow",
            " 21. Seed / prepare scenario lab for this topology",
            "",
            "Prepare Environment",
            "  1. Dry-run preparation planner",
            "  2. Execute eligible preparation helpers",
        ),
    ),
    Scene(
        54,
        66,
        "5. Execute Only Eligible Helpers",
        "Execute",
        "Execution is guarded. Use it only in an approved lab after reviewing the plan, expected changes, and rollback notes.",
        (
            "$ export CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES",
            "$ ./CrashSimulatorV2.sh --prepare-environment --execute",
            "",
            "Type PREPARE-ENVIRONMENT to continue:",
            "PREPARE-ENVIRONMENT",
            "",
            "Items without safe automation stay skipped or plan-only.",
        ),
    ),
    Scene(
        66,
        78,
        "6. Validate After Preparation",
        "Validate",
        "After any preparation change, refresh readiness and backup evidence before executing scenarios.",
        (
            "$ ./CrashSimulatorV2.sh --scenario-readiness-report --html",
            "$ ./CrashSimulatorV2.sh --backup-report --html",
            "$ ./CrashSimulatorV2.sh --baseline-backup --dry-run",
            "",
            "Good starter drills after preparation:",
            "  6 / 31 tempfile loss",
            "  11 / 36 disposable indexes",
            "  43 disposable table loss",
        ),
    ),
)


def main() -> None:
    renderer.SCENES = PREPARE_ENVIRONMENT_SCENES
    renderer.TOTAL_SECONDS = 78
    renderer.VIDEO_PATH = renderer.OUT_DIR / "crashsimulator_prepare_environment_tutorial.mp4"
    renderer.SUBTITLE_PATH = renderer.OUT_DIR / "crashsimulator_prepare_environment_tutorial_subtitles.vtt"
    renderer.TAGLINE = "Detect and prepare only the scenario lab seeds needed for the current topology"
    renderer.FOOTER_TEXT = "CrashSimulator | Prepare environment CLI and Guided Workflow option 21"
    renderer.main()


if __name__ == "__main__":
    main()
