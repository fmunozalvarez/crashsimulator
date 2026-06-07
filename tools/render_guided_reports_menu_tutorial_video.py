#!/usr/bin/env python3
"""Render a CrashSimulator Guided Workflow Reports menu tutorial video.

Generated assets:
  - assets/tutorial/crashsimulator_guided_reports_menu_tutorial.mp4
  - assets/tutorial/crashsimulator_guided_reports_menu_tutorial_subtitles.vtt
  - assets/tutorial/README.md

Dependencies:
  python3 -m pip install pillow imageio imageio-ffmpeg
"""

from __future__ import annotations

import render_cli_tutorial_video as renderer
from render_cli_tutorial_video import Scene


BASE_WRITE_README = renderer.write_readme


REPORTS_SCENES: tuple[Scene, ...] = (
    Scene(
        0,
        7,
        "Guided Reports Menu",
        "Overview",
        "Use the Guided Workflow Reports menu before and after drills to collect evidence, review readiness, and keep recovery decisions visible.",
        (
            "$ ./CrashSimulatorV2.sh --menu",
            "",
            "Guided Workflow",
            " 16. Reports",
            " 19. Review collected topology, logs, reports, and history",
            "",
            "Reports are read-only unless you choose the baseline backup action.",
        ),
    ),
    Scene(
        7,
        16,
        "Open Reports",
        "Menu",
        "The Reports menu groups configuration, MAA, service HA, backup, baseline backup, and lifecycle coverage in one guided place.",
        (
            "Choice: 16",
            "",
            "Reports",
            " 1. Generate target configuration report",
            " 2. Configuration report with deep RMAN validation",
            " 3. Generate Oracle MAA readiness report",
            " 4. Set MAA / SLA planning context",
            " 5. Generate Oracle service HA best-practice review",
        ),
    ),
    Scene(
        16,
        25,
        "Configuration Evidence",
        "Config",
        "Start with the target configuration report to document topology, storage, files, FRA, listeners, and non-default parameters.",
        (
            "Reports choice: 1",
            "",
            "Generated: crashsim_config_report_<run_id>.md",
            "Optional: --html for browser-friendly viewing",
            "",
            "Includes:",
            "  CDB/PDB, RAC/GI/ASM, FRA, datafiles, tempfiles",
            "  control files, redo logs, listener.ora, tnsnames.ora",
        ),
    ),
    Scene(
        25,
        35,
        "MAA Best Practices",
        "MAA",
        "Run the MAA readiness review to detect the current MAA posture and highlight HA, DR, backup, and recoverability gaps.",
        (
            "Reports choice: 3",
            "",
            "Oracle MAA readiness report generated",
            "Detected MAA posture: Silver",
            "Readiness status: Baseline gaps detected",
            "",
            "CLI equivalent:",
            "./CrashSimulatorV2.sh --maa-report --html",
        ),
    ),
    Scene(
        35,
        44,
        "SLA Planning Context",
        "SLA",
        "Set RTO and RPO planning context so reports can connect the technical posture to business recovery expectations.",
        (
            "Reports choice: 4",
            "",
            "Application tier: mission-critical",
            "Target unplanned RTO: 15 minutes",
            "Target unplanned RPO: 5 minutes",
            "Target planned downtime: near zero where possible",
            "",
            "Use this before MAA and backup recoverability reviews.",
        ),
    ),
    Scene(
        44,
        54,
        "Oracle Service HA Review",
        "Services",
        "Review service design for AC, TAC, FSFO, Data Guard role-based services, and Active Data Guard DML redirection awareness.",
        (
            "Reports choice: 5",
            "",
            "Checks:",
            "  Application Continuity and TAC signals",
            "  FSFO observer and broker posture",
            "  Role-based services for DG/ADG",
            "  DML redirection signals",
            "",
            "CLI equivalent: --service-review --html",
        ),
    ),
    Scene(
        54,
        64,
        "Backup Recoverability",
        "Backup",
        "Generate the backup strategy report to review backup sources, RMAN catalog use, recoverability, and estimated RTO and RPO posture.",
        (
            "Reports choice: 6",
            "",
            "Backup strategy and recoverability report",
            "Sources: control file, RMAN catalog when configured",
            "Checks: backups, archivelogs, retention, validation",
            "Output: RTO/RPO estimate plus recommendations",
            "",
            "Deep validation: Reports choice 7",
        ),
    ),
    Scene(
        64,
        73,
        "Fresh Baseline Backup",
        "Baseline",
        "Use the baseline backup choices after destructive drills or structural changes, and dry-run before creating the backup.",
        (
            "Reports choice: 8",
            "Dry-run fresh RMAN baseline backup",
            "",
            "Reports choice: 9",
            "Run fresh RMAN baseline backup",
            "",
            "Best practice:",
            "  refresh the backup baseline before the next high-risk drill",
        ),
    ),
    Scene(
        73,
        84,
        "Lifecycle Coverage",
        "Lifecycle",
        "The lifecycle coverage report shows which scenarios have validation, protection, execution, recovery, and evidence coverage.",
        (
            "Reports choice: 10",
            "",
            "Generated: crashsim_scenario_lifecycle_<run_id>.md",
            "HTML copy: crashsim_scenario_lifecycle_<run_id>.html",
            "",
            "CLI equivalent:",
            "./CrashSimulatorV2.sh --scenario-lifecycle-report --html",
            "./CrashSimulatorV2.sh --show-artifact latest:lifecycle --html",
        ),
    ),
    Scene(
        84,
        94,
        "Review Evidence",
        "Review",
        "Finish by opening the Review Center so operators can inspect the latest reports, logs, runbooks, and HTML copies without rerunning drills.",
        (
            "Back to Guided Workflow",
            "Choice: 19",
            "",
            "Review aliases:",
            "  latest:topology",
            "  latest:maa",
            "  latest:backup",
            "  latest:lifecycle",
            "  latest:scenario-readiness",
        ),
    ),
)


def write_reports_readme() -> None:
    BASE_WRITE_README()


def main() -> None:
    renderer.SCENES = REPORTS_SCENES
    renderer.TOTAL_SECONDS = 94
    renderer.VIDEO_PATH = renderer.OUT_DIR / "crashsimulator_guided_reports_menu_tutorial.mp4"
    renderer.SUBTITLE_PATH = renderer.OUT_DIR / "crashsimulator_guided_reports_menu_tutorial_subtitles.vtt"
    renderer.TAGLINE = "Use the Guided Workflow Reports menu for MAA, backup, lifecycle, and HTML evidence"
    renderer.FOOTER_TEXT = "CrashSimulator | Guided Workflow Reports menu | MAA, lifecycle, and evidence"
    renderer.write_readme = write_reports_readme
    renderer.main()


if __name__ == "__main__":
    main()
