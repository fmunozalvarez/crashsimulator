#!/usr/bin/env python3
"""Render a CrashSimulator guided first-run public-readiness tutorial video."""

from __future__ import annotations

import render_cli_tutorial_video as renderer
from render_cli_tutorial_video import Scene


FIRST_RUN_SCENES: tuple[Scene, ...] = (
    Scene(
        0,
        8,
        "Guided First-Run Path",
        "Start",
        "This tutorial shows the safest first order of operations for new users before any database-changing drill.",
        (
            "$ ./CrashSimulatorV2.sh --menu",
            "",
            "Guided Workflow",
            " 22. Public readiness and safety checks",
            "",
            "Use this path before running scenarios.",
        ),
    ),
    Scene(
        8,
        18,
        "1. Configuration First",
        "Config",
        "Set Oracle environment variables or a non-secret configuration file, then verify what CrashSimulator will use.",
        (
            "$ cp config/crashsimulator.conf.example crashsimulator.conf",
            "$ vi crashsimulator.conf",
            "$ ./CrashSimulatorV2.sh --show-config",
            "$ ./CrashSimulatorV2.sh --validate-config",
            "",
            "Passwords stay in environment variables or wallets.",
        ),
    ),
    Scene(
        18,
        28,
        "2. Read Public Limitations",
        "Limits",
        "New users should understand plan-only scenarios, provider-specific operations, ADB differences, licensing sensitivity, and destructive expectations.",
        (
            "$ ./CrashSimulatorV2.sh --public-limitations --html",
            "",
            "Covers:",
            "  ASM/GI/FEX/ACFS plan-only drills",
            "  OCI, Exadata, GoldenGate provider scope",
            "  ADB cloud-service coverage model",
            "  destructive-lab approval requirements",
        ),
    ),
    Scene(
        28,
        38,
        "3. Doctor And Discovery",
        "Doctor",
        "Run the doctor preflight, then collect topology evidence. This checks tools before touching scenario targets.",
        (
            "$ ./CrashSimulatorV2.sh --doctor --html",
            "$ ./CrashSimulatorV2.sh --discover",
            "",
            "Doctor checks:",
            "  sqlplus, rman, srvctl, dgmgrl, asmcmd",
            "  ORDS, OCI, Node/Playwright, zip/unzip",
            "  logging, audit, config, release safety",
        ),
    ),
    Scene(
        38,
        50,
        "4. Prepare Dry-Run",
        "Prepare",
        "Run the preparation planner in dry-run mode to see missing seeds without surprising database activity.",
        (
            "$ ./CrashSimulatorV2.sh --prepare-environment --dry-run --html",
            "",
            "The planner detects:",
            "  logical lab objects",
            "  redo and control-file posture",
            "  RMAN catalog, FSFO, AC/TAC/FAN",
            "  APEX/ORDS and baseline backup evidence",
        ),
    ),
    Scene(
        50,
        62,
        "5. Readiness And Lifecycle",
        "Readiness",
        "Generate topology-aware readiness and static lifecycle reports before choosing a scenario.",
        (
            "$ ./CrashSimulatorV2.sh --scenario-readiness-report --html",
            "$ ./CrashSimulatorV2.sh --scenario-lifecycle-report --html",
            "$ ./CrashSimulatorV2.sh --scenario-lifecycle-check --html",
            "",
            "Look for:",
            "  RUNNABLE, PLAN-ONLY, NOT-RUNNABLE",
            "  validation, protection, recovery, evidence",
        ),
    ),
    Scene(
        62,
        74,
        "6. Evidence Reports",
        "Reports",
        "Collect backup, MAA, service, scorecard, APEX/ORDS, or ADB reports before destructive testing.",
        (
            "$ ./CrashSimulatorV2.sh --backup-report --html",
            "$ ./CrashSimulatorV2.sh --maa-report --html",
            "$ ./CrashSimulatorV2.sh --service-review --html",
            "$ ./CrashSimulatorV2.sh --resilience-scorecard --html",
            "$ ./CrashSimulatorV2.sh --apex-ords-report --html",
            "$ ./CrashSimulatorV2.sh --adb-readiness-report --html",
        ),
    ),
    Scene(
        74,
        88,
        "7. Safe Starter Drills",
        "Starter",
        "Begin with read-only reports and low-risk drills, then move gradually toward destructive scenarios after backups and runbooks are proven.",
        (
            "Suggested starters:",
            "  health, config, backup, MAA, service reports",
            "  6 / 31 tempfile loss",
            "  11 / 36 disposable index loss",
            "  43 disposable table loss",
            "  63 controlled TEMP pressure",
            "",
            "Defer plan-only and provider-specific drills.",
        ),
    ),
    Scene(
        88,
        100,
        "8. Execute Only With Approval",
        "Approval",
        "Destructive execution must be explicit, reviewed, backed up, and tied to recovery validation evidence.",
        (
            "$ ./CrashSimulatorV2.sh --runbook 6 --html",
            "$ ./CrashSimulatorV2.sh --scenario 6 --dry-run",
            "$ export CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES",
            "$ ./CrashSimulatorV2.sh --scenario 6 --execute",
            "",
            "Finish with health check, backup report, review index,",
            "and retained audit evidence.",
        ),
    ),
)


def main() -> None:
    renderer.SCENES = FIRST_RUN_SCENES
    renderer.TOTAL_SECONDS = 100
    renderer.VIDEO_PATH = renderer.OUT_DIR / "crashsimulator_first_run_public_readiness_tutorial.mp4"
    renderer.SUBTITLE_PATH = renderer.OUT_DIR / "crashsimulator_first_run_public_readiness_tutorial_subtitles.vtt"
    renderer.TAGLINE = "A safe first-run path from configuration to readiness before scenario execution"
    renderer.FOOTER_TEXT = "CrashSimulator | Guided first-run public-readiness workflow"
    renderer.main()


if __name__ == "__main__":
    main()
