#!/usr/bin/env python3
"""Render a CrashSimulator general best-practices tutorial video."""

from __future__ import annotations

import render_cli_tutorial_video as renderer
from render_cli_tutorial_video import Scene


BASE_WRITE_README = renderer.write_readme


BEST_PRACTICE_SCENES: tuple[Scene, ...] = (
    Scene(
        0,
        7,
        "CrashSimulator Best Practices",
        "Overview",
        "This tutorial summarizes the recommended operating model for safe, repeatable, evidence-rich resilience validation.",
        (
            "CrashSimulator practice loop:",
            "  discover",
            "  assess",
            "  validate readiness",
            "  protect",
            "  dry-run",
            "  execute with approval",
            "  recover",
            "  stabilize and report",
        ),
    ),
    Scene(
        7,
        18,
        "1. Use The Right Lab",
        "Lab",
        "Run destructive drills only in approved non-production environments that match the topology you want to learn.",
        (
            "Topology examples:",
            "  standalone, RAC, RAC One Node",
            "  ASM, FEX, ACFS, filesystem",
            "  Data Guard and Active Data Guard",
            "  CDB and non-CDB from 12c through 26ai",
            "",
            "Never improvise destructive injection on production.",
        ),
    ),
    Scene(
        18,
        29,
        "2. Discover And Assess",
        "Assess",
        "Start every cycle with topology discovery, health checks, configuration reports, backup recoverability, and MAA readiness.",
        (
            "$ ./CrashSimulatorV2.sh --discover",
            "$ ./CrashSimulatorV2.sh --health-check --pdb CRASHPDB",
            "$ ./CrashSimulatorV2.sh --config-report --html",
            "$ ./CrashSimulatorV2.sh --backup-report --html",
            "$ ./CrashSimulatorV2.sh --maa-report --html",
            "$ ./CrashSimulatorV2.sh --scenario-readiness-report --html",
        ),
    ),
    Scene(
        29,
        41,
        "3. Choose Runnable Scenarios",
        "Readiness",
        "Use scenario readiness buckets to avoid unsupported topology and provider-specific destructive actions.",
        (
            "Readiness buckets:",
            "  RUNNABLE: safe to dry-run and execute with approval",
            "  PLAN-ONLY: produce runbook evidence, execution blocked",
            "  NOT-RUNNABLE: missing role, target, service, or helper",
            "",
            "FEX/ACFS storage handles often stay PLAN-ONLY",
            "until provider-aware injection is approved.",
        ),
    ),
    Scene(
        41,
        53,
        "4. Protect Before Risk",
        "Protect",
        "Refresh backups and targeted protection before destructive drills, especially after structural changes or prior recoveries.",
        (
            "$ ./CrashSimulatorV2.sh --baseline-backup --dry-run",
            "$ ./CrashSimulatorV2.sh --baseline-backup --execute",
            "$ ./CrashSimulatorV2.sh --protect 30 --pdb CRASHPDB --execute",
            "",
            "Keep control-file autobackup, archive logs,",
            "RMAN catalog posture, and restore validation current.",
        ),
    ),
    Scene(
        53,
        64,
        "5. Dry-Run Everything",
        "Dry-Run",
        "A dry-run should show target selection, planned actions, guardrails, runbook hints, and evidence paths before any fault is injected.",
        (
            "$ ./CrashSimulatorV2.sh --scenario 53 --dry-run",
            "$ ./CrashSimulatorV2.sh --recover 32 --dry-run",
            "$ ./CrashSimulatorV2.sh --random-scenario --dry-run",
            "",
            "If target selection looks wrong, stop and fix context.",
            "Do not rely on recovery bravery.",
        ),
    ),
    Scene(
        64,
        76,
        "6. Execute With Confirmation",
        "Execute",
        "Execution requires explicit confirmation and should be paired with monitoring, timestamps, and a rollback or recovery owner.",
        (
            "$ ./CrashSimulatorV2.sh --scenario 55 --execute",
            "Type EXECUTE-55 to continue:",
            "",
            "Record timestamps:",
            "  fault injected",
            "  outage detected",
            "  recovery started",
            "  database and application validated",
        ),
    ),
    Scene(
        76,
        88,
        "7. Recover And Stabilize",
        "Recover",
        "Recovery is complete only after the database, PDBs, services, application path, backups, and validation reports are healthy again.",
        (
            "$ ./CrashSimulatorV2.sh --recover 30 --execute",
            "$ ./CrashSimulatorV2.sh --health-check --pdb CRASHPDB",
            "$ ./CrashSimulatorV2.sh --backup-report --html",
            "$ ./CrashSimulatorV2.sh --baseline-backup --execute",
            "",
            "Refresh the backup baseline before the next high-risk drill.",
        ),
    ),
    Scene(
        88,
        100,
        "8. Preserve Evidence",
        "Evidence",
        "Keep manifests, runbooks, audit logs, reports, screenshots, and HTML artifacts so drills support training and compliance.",
        (
            "$ ./CrashSimulatorV2.sh --review --html",
            "$ ./CrashSimulatorV2.sh --show-artifact latest:scenario --html",
            "$ ./CrashSimulatorV2.sh --show-artifact latest:recover --html",
            "$ ./CrashSimulatorV2.sh --audit-status",
            "",
            "Evidence should explain what happened, what recovered,",
            "and whether RTO and RPO objectives were met.",
        ),
    ),
    Scene(
        100,
        112,
        "9. Keep Improving",
        "Improve",
        "After every drill, update scenarios, guardrails, runbooks, reports, and topology notes based on what the lab taught you.",
        (
            "Post-drill questions:",
            "  Did validation catch unavailable scenarios?",
            "  Did protection target the right files?",
            "  Did recovery helpers use the working method?",
            "  Were user-facing services validated?",
            "  Is the next batch safe?",
        ),
    ),
)


def write_best_practices_readme() -> None:
    BASE_WRITE_README()


def main() -> None:
    renderer.SCENES = BEST_PRACTICE_SCENES
    renderer.TOTAL_SECONDS = 112
    renderer.VIDEO_PATH = renderer.OUT_DIR / "crashsimulator_best_practices_tutorial.mp4"
    renderer.SUBTITLE_PATH = renderer.OUT_DIR / "crashsimulator_best_practices_tutorial_subtitles.vtt"
    renderer.TAGLINE = "Operate every drill through discovery, readiness, protection, recovery, and evidence"
    renderer.FOOTER_TEXT = "CrashSimulator | Best practices for resilience validation"
    renderer.write_readme = write_best_practices_readme
    renderer.main()


if __name__ == "__main__":
    main()
