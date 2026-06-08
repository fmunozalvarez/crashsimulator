#!/usr/bin/env python3
"""Render a CrashSimulator configuration, target selection, and review tutorial."""

from __future__ import annotations

import render_cli_tutorial_video as renderer
from render_cli_tutorial_video import Scene


BASE_WRITE_README = renderer.write_readme


CONFIG_REVIEW_SCENES: tuple[Scene, ...] = (
    Scene(
        0,
        7,
        "Configuration And Review Tutorial",
        "Overview",
        "This tutorial shows how to use configuration defaults, choose PDB, schema, and FILE# targets, and review retained evidence.",
        (
            "$ ./CrashSimulatorV2.sh --menu",
            "",
            "Guided Workflow",
            " 12. Configure targets and options",
            " 13. Browse recent manifests, logs, reports, and inspect contents",
            " 18. Audit / retention settings",
            " 19. Review collected topology, logs, reports, and history",
        ),
    ),
    Scene(
        7,
        16,
        "1. Start With A Config File",
        "Config",
        "Use crashsimulator.conf for non-secret defaults so operators do not need to retype ORACLE_HOME, PDB, log directory, or reporting context.",
        (
            "$ ./CrashSimulatorV2.sh --write-config-template config/crashsimulator.conf.example",
            "$ cp config/crashsimulator.conf.example ./crashsimulator.conf",
            "",
            "Recommended keys:",
            "  ORACLE_SID, ORACLE_HOME, ORACLE_BASE, TNS_ADMIN",
            "  CRASHSIM_PDB, CRASHSIM_LOG_DIR, CRASHSIM_GRID_HOME",
            "  CRASHSIM_AUDIT_RETAIN, CRASHSIM_AUDIT_RETENTION_DAYS",
        ),
    ),
    Scene(
        16,
        25,
        "2. Keep Secrets Out",
        "Safety",
        "Keep passwords, wallets, API keys, and private keys in environment variables or secure vaults, not in the config file or repository.",
        (
            "$ export CRASHSIM_ADB_PASSWORD='stored outside the repository'",
            "$ export CRASHSIM_ADB_WALLET_PASSWORD='stored outside the repository'",
            "",
            "Config stores names, not secrets:",
            "  CRASHSIM_ADB_PASSWORD_ENV=CRASHSIM_ADB_PASSWORD",
            "  CRASHSIM_ADB_WALLET_PASSWORD_ENV=CRASHSIM_ADB_WALLET_PASSWORD",
        ),
    ),
    Scene(
        25,
        35,
        "3. Validate Startup Context",
        "Show Config",
        "Before a drill, show the active startup configuration and confirm the values loaded from environment and config file.",
        (
            "$ ./CrashSimulatorV2.sh --show-config",
            "",
            "Oracle environment:",
            "  ORACLE_SID=crashdb1",
            "  ORACLE_HOME=/u02/app/oracle/product/23.0.0.0/dbhome_1",
            "CrashSimulator defaults:",
            "  PDB=CRASHPDB",
            "  Log dir=/tmp/crashsimulator/crashsimulator_logs",
        ),
    ),
    Scene(
        35,
        46,
        "4. Select Scenario Context",
        "Targets",
        "When a scenario needs a PDB, schema, or FILE#, the Guided Workflow prompts for the missing target before validation or execution.",
        (
            "Guided Workflow > Select scenario",
            "Scenario: 43 PDB loss of one user table",
            "",
            "Prompt:",
            "  Scenario 43 can use an optional schema filter.",
            "  Select a schema now? [y/N]",
            "",
            "Readiness: RUNNABLE",
        ),
    ),
    Scene(
        46,
        56,
        "5. Use FILE# Selection",
        "FILE#",
        "For datafile and recovery helpers, FILE# selection can be driven by discovery, the manifest, or explicit CLI context.",
        (
            "$ ./CrashSimulatorV2.sh --validate-scenario 30 --pdb CRASHPDB",
            "$ ./CrashSimulatorV2.sh --scenario 30 --pdb CRASHPDB --dry-run",
            "",
            "Fallback when discovery is not available:",
            "$ ./CrashSimulatorV2.sh --recover 32 --file-no 9 --dry-run",
            "",
            "Use the manifest whenever possible for exact recovery context.",
        ),
    ),
    Scene(
        56,
        67,
        "6. Browse Recent Artifacts",
        "Browse",
        "Use the artifact browser to inspect retained reports, manifests, SQL, RMAN command files, logs, and evidence files by date and type.",
        (
            "Guided Workflow choice: 13",
            "",
            "Recent Manifests, Logs, Reports, And Helper Files",
            "  No. Generated              Type       Size  File",
            "   1. 2026-06-08 14:57 UTC report     32K   crashsim_scenario_lifecycle.md",
            "   2. 2026-06-08 14:56 UTC manifest   4K    crashsim_scenario_s53.manifest",
            "",
            "Enter a number to inspect.",
        ),
    ),
    Scene(
        67,
        78,
        "7. Use The Review Center",
        "Review",
        "The Review Center opens the latest topology, reports, logs, and HTML artifacts without reconnecting to the database.",
        (
            "Guided Workflow choice: 19",
            "",
            "Review Center",
            "  1. Show latest collected topology",
            "  3. Generate collected activity review index",
            "  5. Show artifact as text",
            "  7. Generate HTML for artifact",
            "  8. Show recent manifests, logs, reports, and HTML files",
        ),
    ),
    Scene(
        78,
        90,
        "8. Audit Retention",
        "Audit",
        "For training and compliance, retain per-run audit records and set a purge policy that matches your evidence retention requirements.",
        (
            "Guided Workflow choice: 18",
            "",
            "Audit / retention settings",
            "  1. Enable/disable audit log retention",
            "  2. Set audit retention days",
            "  4. Show audit status",
            "  5. Dry-run audit purge",
            "  7. Browse audit logs and inspect contents",
        ),
    ),
    Scene(
        90,
        102,
        "9. Best Review Pattern",
        "Evidence",
        "At the end of every drill, review the runbook, manifest, execution log, recovery log, health check, and report HTML before closing the exercise.",
        (
            "$ ./CrashSimulatorV2.sh --show-artifact latest:runbook --html",
            "$ ./CrashSimulatorV2.sh --show-artifact latest:scenario --html",
            "$ ./CrashSimulatorV2.sh --show-artifact latest:recover --html",
            "$ ./CrashSimulatorV2.sh --review --html",
            "",
            "Outcome: reproducible evidence and fewer mystery steps.",
        ),
    ),
)


def write_config_review_readme() -> None:
    BASE_WRITE_README()


def main() -> None:
    renderer.SCENES = CONFIG_REVIEW_SCENES
    renderer.TOTAL_SECONDS = 102
    renderer.VIDEO_PATH = renderer.OUT_DIR / "crashsimulator_config_review_tutorial.mp4"
    renderer.SUBTITLE_PATH = renderer.OUT_DIR / "crashsimulator_config_review_tutorial_subtitles.vtt"
    renderer.TAGLINE = "Use saved configuration, target selectors, and the Review Center to preserve drill evidence"
    renderer.FOOTER_TEXT = "CrashSimulator | Configuration, target selection, and evidence review"
    renderer.write_readme = write_config_review_readme
    renderer.main()


if __name__ == "__main__":
    main()
