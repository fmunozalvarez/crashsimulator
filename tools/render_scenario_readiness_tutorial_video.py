#!/usr/bin/env python3
"""Render a CrashSimulator scenario readiness tutorial video.

Generated assets:
  - assets/tutorial/crashsimulator_scenario_readiness_tutorial.mp4
  - assets/tutorial/crashsimulator_scenario_readiness_tutorial_subtitles.vtt
  - assets/tutorial/README.md

Dependencies:
  python3 -m pip install pillow imageio imageio-ffmpeg
"""

from __future__ import annotations

import render_cli_tutorial_video as renderer
from render_cli_tutorial_video import Scene


READINESS_SCENES: tuple[Scene, ...] = (
    Scene(
        0,
        7,
        "Scenario Readiness Tutorial",
        "Overview",
        "Validate the target environment against the full scenario registry before choosing any destructive drill.",
        (
            "$ ./CrashSimulatorV2.sh --help",
            "",
            "New capability:",
            "  --scenario-readiness-report",
            "",
            "Purpose:",
            "  show topology signals",
            "  list runnable scenarios",
            "  explain blocked scenarios",
            "  prevent unavailable executions",
        ),
    ),
    Scene(
        7,
        15,
        "1. Set The Target Context",
        "Context",
        "Run as the Oracle software owner and set the database environment exactly as you would for a real drill.",
        (
            "$ sudo su - oracle",
            "$ export ORACLE_HOME=/u02/app/oracle/product/19.0.0.0/dbhome_1",
            "$ export ORACLE_SID=crashdb1",
            "$ export ORACLE_UNQNAME=crashdb",
            "$ export PATH=$ORACLE_HOME/bin:/u01/app/19.0.0.0/grid/bin:$PATH",
            "$ cd /tmp/crashsimulator",
        ),
    ),
    Scene(
        15,
        24,
        "2. Generate The CLI Report",
        "CLI",
        "Create the topology-versus-scenario report and request HTML for easy review and sharing.",
        (
            "$ ./CrashSimulatorV2.sh \\",
            "    --scenario-readiness-report \\",
            "    --pdb CRASHPDB \\",
            "    --html",
            "",
            "Scenario readiness report generated:",
            "  crashsim_scenario_readiness_20260605_103000.md",
            "Latest scenario readiness report:",
            "  crashsim_scenario_readiness_latest.md",
        ),
    ),
    Scene(
        24,
        33,
        "3. Review Topology Signals",
        "Topology",
        "Confirm that CrashSimulator detected the same topology you intend to test.",
        (
            "Current Topology",
            "",
            "Database role: PRIMARY",
            "Open mode: READ WRITE",
            "CDB: YES",
            "Target PDB context: CRASHPDB",
            "Cluster type: RAC",
            "Storage type: ASM",
            "GI managed: 1",
        ),
    ),
    Scene(
        33,
        43,
        "4. Read The Readiness Buckets",
        "Buckets",
        "Use the report buckets to decide what can be executed, what should stay dry-run only, and what needs topology work.",
        (
            "Readiness Summary",
            "",
            "RUNNABLE      34  ready for dry-run and execution",
            "PLAN-ONLY     19  useful planning, execution blocked",
            "NOT-RUNNABLE   7  missing topology, target, or helper",
            "",
            "Best practice:",
            "  choose execution drills only from RUNNABLE",
            "  treat PLAN-ONLY as design or runbook practice",
        ),
    ),
    Scene(
        43,
        52,
        "5. Validate One Scenario",
        "Single Check",
        "Before execution, run a single scenario validation so the latest target context is checked again.",
        (
            "$ ./CrashSimulatorV2.sh --validate-scenario 30 --pdb CRASHPDB",
            "",
            "Scenario 30: PDB loss of one non-system datafile",
            "Group: Storage",
            "Scope: PDB",
            "Impact: destructive",
            "",
            "Result: RUNNABLE",
            "Reason: requirements and target selection passed.",
        ),
    ),
    Scene(
        52,
        61,
        "6. Open The Saved Report",
        "Review",
        "Use the Review Center shortcuts to reopen the latest readiness report as text or HTML without remembering the file name.",
        (
            "$ ./CrashSimulatorV2.sh --show-artifact latest:scenario-readiness",
            "$ ./CrashSimulatorV2.sh --show-artifact latest:scenario-readiness --html",
            "$ ./CrashSimulatorV2.sh --render-html latest:scenario-readiness",
            "",
            "The timestamped Markdown stays unchanged.",
            "The latest shortcut follows the newest generated report.",
        ),
    ),
    Scene(
        61,
        70,
        "7. Use Guided Workflow",
        "Menu",
        "The Guided Workflow exposes the same report for operators who prefer prompts and menu guardrails.",
        (
            "$ ./CrashSimulatorV2.sh --menu",
            "",
            "Guided Workflow",
            "  1. Discover or refresh database topology",
            "  2. Select scenario",
            " 17. Generate scenario readiness report for this topology",
            " 19. Review collected topology, logs, reports, and history",
            "",
            "Menu choice: 17",
        ),
    ),
    Scene(
        70,
        79,
        "8. Menu Selection Guardrail",
        "Guardrail",
        "When a user selects a scenario, the menu now reports readiness immediately before dry-run or execution.",
        (
            "Menu choice: 2",
            "Scenario number: 46",
            "",
            "Selected scenario 46: ASM disk loss simulation",
            "Readiness: PLAN-ONLY",
            "Reason: ASM/GI destructive helper needs a redundant lab target.",
            "",
            "Execution remains blocked until the guardrail is resolved.",
        ),
    ),
    Scene(
        79,
        88,
        "9. Follow The Best-Practice Flow",
        "Practice",
        "Finish by choosing a runnable scenario, then dry-run, protect, execute, recover, and validate with retained evidence.",
        (
            "Recommended flow",
            "",
            "1. Generate readiness report",
            "2. Pick a RUNNABLE scenario",
            "3. Run --validate-scenario again",
            "4. Run --scenario <id> --dry-run",
            "5. Run --protect <id> --execute when supported",
            "6. Execute only with approval",
            "7. Recover and run health checks",
        ),
    ),
)


def write_readiness_readme() -> None:
    renderer.README_PATH.write_text(
        """# CrashSimulator Tutorial Videos

Generated assets:

- `crashsimulator_cli_tutorial.mp4`: short 1080p CLI setup and scenario tutorial with burned-in subtitles.
- `crashsimulator_cli_tutorial_subtitles.vtt`: CLI tutorial WebVTT subtitle sidecar.
- `crashsimulator_guided_workflow_tutorial.mp4`: short 1080p Guided Workflow menu scenario tutorial with burned-in subtitles.
- `crashsimulator_guided_workflow_tutorial_subtitles.vtt`: Guided Workflow tutorial WebVTT subtitle sidecar.
- `crashsimulator_audit_retention_tutorial.mp4`: short 1080p audit retention tutorial for CLI and Guided Workflow menu modes with burned-in subtitles.
- `crashsimulator_audit_retention_tutorial_subtitles.vtt`: audit retention tutorial WebVTT subtitle sidecar.
- `crashsimulator_scenario_readiness_tutorial.mp4`: short 1080p scenario readiness tutorial for CLI and Guided Workflow menu modes with burned-in subtitles.
- `crashsimulator_scenario_readiness_tutorial_subtitles.vtt`: scenario readiness tutorial WebVTT subtitle sidecar.

Regenerate from the repository root with:

```bash
python3 -m pip install pillow imageio imageio-ffmpeg
python3 tools/render_cli_tutorial_video.py
python3 tools/render_guided_workflow_tutorial_video.py
python3 tools/render_audit_retention_tutorial_video.py
python3 tools/render_scenario_readiness_tutorial_video.py
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


def main() -> None:
    renderer.SCENES = READINESS_SCENES
    renderer.TOTAL_SECONDS = 88
    renderer.VIDEO_PATH = renderer.OUT_DIR / "crashsimulator_scenario_readiness_tutorial.mp4"
    renderer.SUBTITLE_PATH = renderer.OUT_DIR / "crashsimulator_scenario_readiness_tutorial_subtitles.vtt"
    renderer.TAGLINE = "Validate database topology against every CrashSimulator scenario before executing drills"
    renderer.FOOTER_TEXT = "CrashSimulator | Oracle HA/DR and backup/recovery practice | Scenario Readiness"
    renderer.write_readme = write_readiness_readme
    renderer.main()


if __name__ == "__main__":
    main()
