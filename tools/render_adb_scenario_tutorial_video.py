#!/usr/bin/env python3
"""Render a CrashSimulator Autonomous Database scenario tutorial video."""

from __future__ import annotations

import render_cli_tutorial_video as renderer
from render_cli_tutorial_video import Scene


BASE_WRITE_README = renderer.write_readme


ADB_SCENARIO_SCENES: tuple[Scene, ...] = (
    Scene(
        0,
        7,
        "Autonomous Database Scenario Tutorial",
        "Overview",
        "This tutorial shows how to browse ADB01 through ADB15 and review one scenario before future ADB-specific helpers execute drills.",
        (
            "$ ./CrashSimulatorV2.sh --list-adb-scenarios",
            "",
            "ADB01 Drop critical application table",
            "ADB03 Mass DELETE without WHERE clause",
            "ADB05 Recover from clone",
            "ADB12 Autonomous Data Guard validation",
        ),
    ),
    Scene(
        7,
        17,
        "1. Start With Readiness",
        "Readiness",
        "Generate the ADB readiness report first so each scenario status is based on current wallet, SQL, APEX, and OCI context.",
        (
            "$ ./CrashSimulatorV2.sh --adb-readiness-report --html",
            "",
            "Scenario coverage:",
            "  RUNNABLE after disposable lab seed",
            "  PLAN/RUNBOOK",
            "  CONFIG NEEDED",
            "  OCI CONFIG NEEDED",
        ),
    ),
    Scene(
        17,
        29,
        "2. Browse The Catalog",
        "Catalog",
        "Use the ADB scenario catalog to see what can be practiced with SQL alone and what requires OCI control-plane evidence.",
        (
            "$ ./CrashSimulatorV2.sh --list-adb-scenarios",
            "",
            "ID     Area                 Status",
            "ADB01  Logical recovery     RUNNABLE AFTER LAB SEED",
            "ADB08  Connectivity         PLAN/RUNBOOK",
            "ADB12  Autonomous DataGuard OCI CONFIG NEEDED",
            "ADB15  Object Storage       OCI CONFIG NEEDED",
        ),
    ),
    Scene(
        29,
        41,
        "3. Inspect ADB01",
        "ADB01",
        "ADB01 is a logical recovery drill for a disposable critical table, designed around Flashback Table, clone, or export-based recovery.",
        (
            "$ ./CrashSimulatorV2.sh --adb-scenario ADB01",
            "",
            "Scenario: Drop critical application table",
            "Validation:",
            "  confirm disposable lab table",
            "  confirm flashback eligibility",
            "  confirm clone or export fallback",
            "Recovery focus: Flashback Table and application validation",
        ),
    ),
    Scene(
        41,
        53,
        "4. Seed Disposable Objects",
        "Seed",
        "Before any logical ADB drill, seed disposable objects and label them clearly so production application data is never the target.",
        (
            "Example lab posture:",
            "  owner: CRASHSIM_ADB_LAB",
            "  table: CRASHSIM_CRITICAL_ORDER",
            "  recovery marker: before row count and sample checksum",
            "",
            "Never target application-owned tables without approval,",
            "backup evidence, and an application validation plan.",
        ),
    ),
    Scene(
        53,
        65,
        "5. Dry-Run The Future Helper",
        "Dry-Run",
        "The current ADB scenario menu is readiness-first. Future seeded helpers should keep the same guardrail model: validate, dry-run, execute, recover, report.",
        (
            "Expected helper pattern:",
            "$ ./CrashSimulatorV2.sh --adb-scenario ADB01 --dry-run",
            "",
            "Planned actions:",
            "  verify lab table",
            "  capture before evidence",
            "  simulate DROP TABLE",
            "  flashback or restore from clone/export",
        ),
    ),
    Scene(
        65,
        76,
        "6. Use Guided Workflow",
        "Menu",
        "The Guided Workflow ADB submenu lets operators browse, select, inspect, and refresh readiness without database-host access.",
        (
            "Guided Workflow choice: 20",
            "",
            "Autonomous Database Scenarios",
            "  1. List ADB01-ADB15 with readiness status",
            "  2. Select ADB scenario",
            "  3. Show selected ADB scenario detail and validation status",
            "  5. Run fresh Autonomous Database readiness report",
        ),
    ),
    Scene(
        76,
        88,
        "7. Recovery Evidence",
        "Evidence",
        "For ADB logical drills, evidence should prove the object was restored and the application can read the expected data again.",
        (
            "Evidence checklist:",
            "  before and after row counts",
            "  flashback or clone timestamp",
            "  SQL validation query",
            "  application smoke URL",
            "  elapsed time and data-loss window",
            "  Markdown, HTML, and audit artifacts",
        ),
    ),
    Scene(
        88,
        100,
        "8. Expand Safely",
        "Roadmap",
        "After ADB01, prioritize ADB03 and ADB04 logical mistakes, then add OCI-backed clone, PITR, Autonomous Data Guard, IAM, and Object Storage drills.",
        (
            "Recommended order:",
            "  ADB01 Drop table",
            "  ADB03 Mass DELETE",
            "  ADB04 Incorrect UPDATE",
            "  ADB05-07 Clone and PITR",
            "  ADB12-15 Autonomous Data Guard, IAM, Object Storage",
            "",
            "Keep each helper reversible and evidence-rich.",
        ),
    ),
)


def write_adb_scenario_readme() -> None:
    BASE_WRITE_README()


def main() -> None:
    renderer.SCENES = ADB_SCENARIO_SCENES
    renderer.TOTAL_SECONDS = 100
    renderer.VIDEO_PATH = renderer.OUT_DIR / "crashsimulator_adb_scenario_tutorial.mp4"
    renderer.SUBTITLE_PATH = renderer.OUT_DIR / "crashsimulator_adb_scenario_tutorial_subtitles.vtt"
    renderer.TAGLINE = "Browse ADB01-ADB15 and validate ADB logical recovery scenario posture"
    renderer.FOOTER_TEXT = "CrashSimulator | Autonomous Database scenario readiness"
    renderer.write_readme = write_adb_scenario_readme
    renderer.main()


if __name__ == "__main__":
    main()
