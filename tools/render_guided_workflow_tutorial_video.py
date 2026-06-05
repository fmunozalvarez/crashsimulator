#!/usr/bin/env python3
"""Render a CrashSimulator Guided Workflow menu tutorial video.

Generated assets:
  - assets/tutorial/crashsimulator_guided_workflow_tutorial.mp4
  - assets/tutorial/crashsimulator_guided_workflow_tutorial_subtitles.vtt
  - assets/tutorial/README.md

Dependencies:
  python3 -m pip install pillow imageio imageio-ffmpeg
"""

from __future__ import annotations

import render_cli_tutorial_video as renderer
from render_cli_tutorial_video import Scene


GUIDED_SCENES: tuple[Scene, ...] = (
    Scene(
        0,
        7,
        "CrashSimulator Guided Workflow",
        "Menu",
        "Start from the Guided Workflow menu when you want guardrails, prompts, and a repeatable best-practice flow.",
        (
            "$ ./CrashSimulatorV2.sh --menu",
            "",
            "CrashSimulator Guided Workflow",
            " 1. Discover topology",
            " 2. Health checks",
            " 3. Reports and MAA readiness",
            " 4. Scenario planning and validation",
            " 5. Protection, execution, recovery, and evidence",
        ),
    ),
    Scene(
        7,
        15,
        "1. Review The Target",
        "Review",
        "Begin by confirming the database topology, role, storage, cluster state, and selected PDB.",
        (
            "Menu choice: 1",
            "Review collected topology or discover now? discover",
            "",
            "Database: CRASHDB  Role: PRIMARY  CDB: YES",
            "Cluster: RAC       Storage: ASM",
            "PDB: CRASHPDB      Open mode: READ WRITE",
            "",
            "Best practice: never execute before topology is known.",
        ),
    ),
    Scene(
        15,
        23,
        "2. Confirm Health",
        "Health",
        "Run health checks before the drill so the starting state is clean and the evidence has a baseline.",
        (
            "Menu choice: 2",
            "Target PDB: CRASHPDB",
            "",
            "CDB open mode: READ WRITE",
            "PDB open mode: READ WRITE",
            "V$RECOVER_FILE: no rows",
            "V$DATABASE_BLOCK_CORRUPTION: no rows",
            "RMAN validation: completed",
        ),
    ),
    Scene(
        23,
        31,
        "3. Check Reports",
        "Reports",
        "Use the menu reports to review backup posture, FRA usage, MAA readiness, and recoverability before choosing a scenario.",
        (
            "Menu choice: 3",
            "Reports > Backup recoverability report",
            "Reports > MAA readiness report",
            "Reports > Configuration report",
            "",
            "Backup status: AVAILABLE",
            "Last baseline backup: current",
            "Generated HTML reports are kept for review.",
        ),
    ),
    Scene(
        31,
        40,
        "4. Validate Scenario 30",
        "Validate",
        "Choose a scenario and let CrashSimulator verify whether it is runnable in the current topology.",
        (
            "Menu choice: 4",
            "Scenario number: 30",
            "PDB name: CRASHPDB",
            "",
            "Scenario 30: PDB loss of one non-system datafile",
            "Validation result: RUNNABLE",
            "Reason: topology, backup, and target checks passed.",
            "Next: review dry-run and runbook hints.",
        ),
    ),
    Scene(
        40,
        49,
        "5. Dry-Run And Runbook",
        "Dry-Run",
        "Dry-run first. Inspect target selection, expected impact, recovery commands, and rollback evidence before any execution.",
        (
            "Menu choice: 4 > Dry-run selected scenario",
            "",
            "Planned target:",
            "  FILE# 13  CRASHPDB  USERS",
            "  +DATACRASHDB/.../DATAFILE/users...",
            "",
            "Runbook hints:",
            "  protect target, execute only with approval, recover from manifest",
        ),
    ),
    Scene(
        49,
        58,
        "6. Protect Before Execution",
        "Protect",
        "Run protection from the menu so RMAN captures the exact target and the current control file before the failure.",
        (
            "Menu choice: 5 > Protect scenario",
            "Scenario number: 30",
            "Type PROTECT-30 to continue:",
            "PROTECT-30",
            "",
            "RMAN backup tag: CSIM30_YYYYMMDD_HH24MISS",
            "Manifest: crashsim_scenario_s30_<run_id>.manifest",
            "Protection status: complete",
        ),
    ),
    Scene(
        58,
        67,
        "7. Execute With Approval",
        "Execute",
        "Execute only after the dry-run, runbook, health check, and protection evidence are complete.",
        (
            "Menu choice: 5 > Execute scenario",
            "Scenario number: 30",
            "Type EXECUTE-30 to continue:",
            "EXECUTE-30",
            "",
            "Action: asmcmd rm +DATACRASHDB/.../users...",
            "Impact: CRASHPDB datafile unavailable",
            "Evidence: execution log and manifest retained",
        ),
    ),
    Scene(
        67,
        76,
        "8. Recover From Manifest",
        "Recover",
        "Use the Guided Workflow recovery option and provide the manifest created during execution.",
        (
            "Menu choice: 5 > Recover scenario",
            "Scenario number: 30",
            "Manifest: crashsim_scenario_s30_<run_id>.manifest",
            "",
            "RMAN restore datafile 13;",
            "RMAN recover datafile 13;",
            "SQL alter pluggable database CRASHPDB open;",
            "Recovery status: complete",
        ),
    ),
    Scene(
        76,
        85,
        "9. Validate And Archive",
        "Evidence",
        "Finish the drill by validating database health and preserving logs, reports, manifests, and HTML evidence.",
        (
            "Menu choice: 2 > Post-drill health check",
            "Menu choice: 3 > Backup report --html",
            "Menu choice: 6 > Review collected artifacts",
            "",
            "CDB: READ WRITE",
            "CRASHPDB: READ WRITE",
            "V$RECOVER_FILE: no rows",
            "Audit bundle: retained according to policy",
        ),
    ),
)


def write_guided_readme() -> None:
    renderer.README_PATH.write_text(
        """# CrashSimulator Tutorial Videos

Generated assets:

- `crashsimulator_cli_tutorial.mp4`: short 1080p CLI setup and scenario tutorial with burned-in subtitles.
- `crashsimulator_cli_tutorial_subtitles.vtt`: CLI tutorial WebVTT subtitle sidecar.
- `crashsimulator_guided_workflow_tutorial.mp4`: short 1080p Guided Workflow menu scenario tutorial with burned-in subtitles.
- `crashsimulator_guided_workflow_tutorial_subtitles.vtt`: Guided Workflow tutorial WebVTT subtitle sidecar.

Regenerate from the repository root with:

```bash
python3 -m pip install pillow imageio imageio-ffmpeg
python3 tools/render_cli_tutorial_video.py
python3 tools/render_guided_workflow_tutorial_video.py
```

The CLI tutorial demonstrates direct command execution. The Guided Workflow
tutorial demonstrates the menu-driven best-practice path: discover, health
check, report, validate, dry-run, protect, execute, recover, validate, and keep
evidence for audit and training.
""",
        encoding="utf-8",
    )


def main() -> None:
    renderer.SCENES = GUIDED_SCENES
    renderer.TOTAL_SECONDS = 85
    renderer.VIDEO_PATH = renderer.OUT_DIR / "crashsimulator_guided_workflow_tutorial.mp4"
    renderer.SUBTITLE_PATH = renderer.OUT_DIR / "crashsimulator_guided_workflow_tutorial_subtitles.vtt"
    renderer.TAGLINE = "Run a complete protected crash drill from the Guided Workflow menu"
    renderer.FOOTER_TEXT = "CrashSimulator | Oracle HA/DR and backup/recovery practice | Guided Workflow"
    renderer.write_readme = write_guided_readme
    renderer.main()


if __name__ == "__main__":
    main()
