#!/usr/bin/env python3
"""Render a CrashSimulator audit retention tutorial video.

Generated assets:
  - assets/tutorial/crashsimulator_audit_retention_tutorial.mp4
  - assets/tutorial/crashsimulator_audit_retention_tutorial_subtitles.vtt
  - assets/tutorial/README.md

Dependencies:
  python3 -m pip install pillow imageio imageio-ffmpeg
"""

from __future__ import annotations

import render_cli_tutorial_video as renderer
from render_cli_tutorial_video import Scene


AUDIT_SCENES: tuple[Scene, ...] = (
    Scene(
        0,
        7,
        "CrashSimulator Audit Tutorial",
        "Overview",
        "This tutorial shows how to configure audit retention, review status, and purge old audit records safely.",
        (
            "$ ./CrashSimulatorV2.sh --help",
            "",
            "Audit archive purpose:",
            "  retain redacted commands, stdout, stderr, manifests, reports, and evidence",
            "",
            "Best practice:",
            "  keep audit retention enabled and purge only by policy",
        ),
    ),
    Scene(
        7,
        15,
        "1. Configure CLI Retention",
        "CLI Config",
        "Configure audit retention from the CLI with a deliberate retention window and a durable audit directory.",
        (
            "$ ./CrashSimulatorV2.sh \\",
            "    --audit-retain yes \\",
            "    --audit-retention-days 365 \\",
            "    --audit-dir /secure/audit/crashsimulator \\",
            "    --audit-status",
            "",
            "Retention: enabled",
            "Policy: keep audit run folders for 365 days",
        ),
    ),
    Scene(
        15,
        23,
        "2. Show CLI Audit Status",
        "CLI Status",
        "Use audit status before and after drills to confirm the active policy, directory, usage, and purge candidates.",
        (
            "$ ./CrashSimulatorV2.sh --audit-status",
            "",
            "CrashSimulator audit status",
            "Audit retain: yes",
            "Retention days: 365",
            "Audit directory: /secure/audit/crashsimulator",
            "Run folders: 148",
            "Purge candidates: 12",
        ),
    ),
    Scene(
        23,
        31,
        "3. Preview CLI Purge",
        "CLI DryRun",
        "Always dry-run the purge first so operators can review exactly which audit folders would be removed.",
        (
            "$ ./CrashSimulatorV2.sh \\",
            "    --audit-retention-days 365 \\",
            "    --audit-dir /secure/audit/crashsimulator \\",
            "    --purge-audit-logs --dry-run",
            "",
            "Audit run folders selected for purge:",
            "  2025-03-01/crashsim_audit_20250301_101010_2345",
            "DRY-RUN: no audit folders were removed.",
        ),
    ),
    Scene(
        31,
        39,
        "4. Execute CLI Purge",
        "CLI Purge",
        "Execute only after approval. CrashSimulator asks for a confirmation token before removing audit folders.",
        (
            "$ ./CrashSimulatorV2.sh --purge-audit-logs --execute",
            "About to purge audit run folders older than 365 days.",
            "Type PURGE-AUDIT-LOGS to continue:",
            "PURGE-AUDIT-LOGS",
            "",
            "Removing: 2025-03-01/crashsim_audit_20250301_101010_2345",
            "Purged 12 audit run folder(s).",
        ),
    ),
    Scene(
        39,
        47,
        "5. Verify CLI Evidence",
        "Verify",
        "After purge, show audit status again and keep the purge output as evidence for compliance and training.",
        (
            "$ ./CrashSimulatorV2.sh --audit-status",
            "Purge candidates: 0",
            "",
            "$ ./CrashSimulatorV2.sh --show-artifact latest:audit --html",
            "Generated HTML artifact for latest audit record.",
            "",
            "Evidence retained:",
            "  command.redacted, stdout.log, stderr.log, artifacts.index",
        ),
    ),
    Scene(
        47,
        55,
        "6. Open Guided Workflow",
        "Menu",
        "The same audit lifecycle is available in the Guided Workflow menu for operators who prefer prompts.",
        (
            "$ ./CrashSimulatorV2.sh --menu",
            "",
            "CrashSimulator Guided Workflow",
            " 16. Reports",
            " 17. Review collected artifacts",
            " 18. Audit / retention settings",
            "",
            "Choice: 18",
        ),
    ),
    Scene(
        55,
        63,
        "7. Configure From Menu",
        "Menu Config",
        "In the Audit menu, enable retention, set retention days, and choose the audit directory.",
        (
            "Audit / Retention Settings",
            "  1. Enable/disable audit log retention",
            "  2. Set audit retention days",
            "  3. Set audit directory",
            "",
            "Choice: 1  -> yes",
            "Choice: 2  -> 365",
            "Choice: 3  -> /secure/audit/crashsimulator",
        ),
    ),
    Scene(
        63,
        71,
        "8. Show Menu Status",
        "Menu Status",
        "Use the menu status option to confirm the retained settings before running or purging audit records.",
        (
            "Audit / Retention Settings",
            "Current retain=1 retention_days=365",
            "",
            "Choice: 4",
            "Running: CRASHSIM_AUDIT_RETAIN=1 \\",
            "         CRASHSIM_AUDIT_RETENTION_DAYS=365 \\",
            "         ./CrashSimulatorV2.sh --audit-status",
            "Command completed successfully.",
        ),
    ),
    Scene(
        71,
        80,
        "9. Dry-Run Menu Purge",
        "Menu DryRun",
        "From the Guided Workflow menu, choose dry-run purge first and review the selected folders before execution.",
        (
            "Audit / Retention Settings",
            "Choice: 5",
            "",
            "Running: ./CrashSimulatorV2.sh --purge-audit-logs --dry-run",
            "Audit run folders selected for purge:",
            "  2025-03-01/crashsim_audit_20250301_101010_2345",
            "DRY-RUN: no audit folders were removed.",
        ),
    ),
    Scene(
        80,
        90,
        "10. Execute And Review",
        "Menu Purge",
        "Execute the menu purge only after approval, then review audit status and collected artifacts.",
        (
            "Audit / Retention Settings",
            "Choice: 6",
            "Type PURGE-AUDIT-LOGS to continue:",
            "PURGE-AUDIT-LOGS",
            "Purged 12 audit run folder(s).",
            "",
            "Choice: 4  -> audit status",
            "Review Center -> latest:audit --html",
        ),
    ),
)


def write_tutorial_readme() -> None:
    renderer.README_PATH.write_text(
        """# CrashSimulator Tutorial Videos

Generated assets:

- `crashsimulator_cli_tutorial.mp4`: short 1080p CLI setup and scenario tutorial with burned-in subtitles.
- `crashsimulator_cli_tutorial_subtitles.vtt`: CLI tutorial WebVTT subtitle sidecar.
- `crashsimulator_guided_workflow_tutorial.mp4`: short 1080p Guided Workflow menu scenario tutorial with burned-in subtitles.
- `crashsimulator_guided_workflow_tutorial_subtitles.vtt`: Guided Workflow tutorial WebVTT subtitle sidecar.
- `crashsimulator_audit_retention_tutorial.mp4`: short 1080p audit retention tutorial for CLI and Guided Workflow menu modes with burned-in subtitles.
- `crashsimulator_audit_retention_tutorial_subtitles.vtt`: audit retention tutorial WebVTT subtitle sidecar.

Regenerate from the repository root with:

```bash
python3 -m pip install pillow imageio imageio-ffmpeg
python3 tools/render_cli_tutorial_video.py
python3 tools/render_guided_workflow_tutorial_video.py
python3 tools/render_audit_retention_tutorial_video.py
```

The tutorial set demonstrates direct CLI execution, the menu-driven
best-practice scenario workflow, and audit-retention operations. The audit
tutorial covers configuring retention, checking audit status, dry-running
purge, executing purge with confirmation, and reviewing retained evidence.
""",
        encoding="utf-8",
    )


def main() -> None:
    renderer.SCENES = AUDIT_SCENES
    renderer.TOTAL_SECONDS = 90
    renderer.VIDEO_PATH = renderer.OUT_DIR / "crashsimulator_audit_retention_tutorial.mp4"
    renderer.SUBTITLE_PATH = renderer.OUT_DIR / "crashsimulator_audit_retention_tutorial_subtitles.vtt"
    renderer.TAGLINE = "Configure audit retention, check status, purge safely, and preserve evidence"
    renderer.FOOTER_TEXT = "CrashSimulator | Audit retention and compliance evidence | CLI and Guided Workflow"
    renderer.write_readme = write_tutorial_readme
    renderer.main()


if __name__ == "__main__":
    main()
