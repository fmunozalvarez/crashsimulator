#!/usr/bin/env python3
"""Render a CrashSimulator public limitations tutorial video."""

from __future__ import annotations

import render_cli_tutorial_video as renderer
from render_cli_tutorial_video import Scene


LIMITATIONS_SCENES: tuple[Scene, ...] = (
    Scene(
        0,
        8,
        "Public Limitations Page",
        "Purpose",
        "The public limitations page sets expectations before users run CrashSimulator in their own Oracle labs.",
        (
            "$ ./CrashSimulatorV2.sh --public-limitations --html",
            "Public limitations page generated:",
            "  crashsim_public_limitations_<run_id>.md",
            "HTML artifact generated:",
            "  crashsim_public_limitations_<run_id>.md.html",
        ),
    ),
    Scene(
        8,
        20,
        "1. What CrashSimulator Is Not",
        "Scope",
        "CrashSimulator is not a production chaos tool, an Oracle certification program, a licensing verifier, or a substitute for tested backups.",
        (
            "Public expectation:",
            "  open-source resilience validation platform",
            "  lab-first and dry-run-first",
            "  evidence-oriented",
            "  not formal Oracle certification",
            "  not a replacement for support or change control",
        ),
    ),
    Scene(
        20,
        33,
        "2. Destructive Scenario Expectations",
        "Safety",
        "Destructive drills require an approved lab, reviewed backups, scenario readiness, runbooks, confirmation tokens, and recovery validation.",
        (
            "$ ./CrashSimulatorV2.sh --scenario-readiness-report --html",
            "$ ./CrashSimulatorV2.sh --runbook 30 --html",
            "$ ./CrashSimulatorV2.sh --scenario 30 --dry-run",
            "",
            "$ export CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES",
            "$ ./CrashSimulatorV2.sh --scenario 30 --execute",
        ),
    ),
    Scene(
        33,
        47,
        "3. Plan-Only Scenarios",
        "Plan-Only",
        "Plan-only scenarios produce evidence and runbooks when direct automation would be unsafe or provider-specific.",
        (
            "Examples:",
            "  ASM/GI/FEX/ACFS: 46, 47, 48, 49, 72",
            "  Data Guard transition: 52, 54, 66, 85, 86",
            "  PDB PITR and rollback: 88, 89, 90",
            "  Exadata, OCI Base DB, GoldenGate families",
            "",
            "External approved action remains outside the generic driver.",
        ),
    ),
    Scene(
        47,
        59,
        "4. ADB Is Different",
        "ADB",
        "Autonomous Database scenarios focus on cloud-service readiness, logical recovery, connectivity, IAM, wallet lifecycle, and clone/PITR evidence.",
        (
            "$ ./CrashSimulatorV2.sh --adb-readiness-report --html",
            "$ ./CrashSimulatorV2.sh --list-adb-scenarios",
            "",
            "ADB does not expose:",
            "  host files, ASM disks, redo members",
            "  control files, password files, ORACLE_HOME",
            "",
            "Use OCI metadata when OCIDs and profile are configured.",
        ),
    ),
    Scene(
        59,
        72,
        "5. Licensing-Sensitive Features",
        "Licensing",
        "Reports can detect signals for advanced features, but users must verify license entitlement and supportability separately.",
        (
            "Examples to verify:",
            "  RAC and Active Data Guard",
            "  Application Continuity / TAC",
            "  Diagnostics and Tuning evidence sources",
            "  TDE, Exadata, GoldenGate",
            "  OCI managed-service behavior",
            "",
            "CrashSimulator labels evidence; it does not grant entitlement.",
        ),
    ),
    Scene(
        72,
        86,
        "6. Evidence-Based Claims",
        "Evidence",
        "MAA and resilience claims should be based on measured evidence, not just installed components.",
        (
            "Do not claim zero data loss without:",
            "  synchronous protection and commit behavior evidence",
            "  standby receive/apply state",
            "  tested transition transcript",
            "",
            "Do not claim near-zero downtime without:",
            "  services, FAN/ONS, AC/TAC or retry behavior",
            "  measured client outage or brownout evidence",
        ),
    ),
    Scene(
        86,
        98,
        "7. How To Revisit The Page",
        "Review",
        "The page is also accessible later through artifact review and the Public Readiness menu.",
        (
            "$ ./CrashSimulatorV2.sh --show-artifact latest:public-limitations",
            "$ ./CrashSimulatorV2.sh --render-html latest:public-limitations",
            "",
            "Guided Workflow",
            " 22. Public readiness and safety checks",
            "  8. Generate public limitations page",
            "",
            "Keep it with release and training materials.",
        ),
    ),
)


def main() -> None:
    renderer.SCENES = LIMITATIONS_SCENES
    renderer.TOTAL_SECONDS = 98
    renderer.VIDEO_PATH = renderer.OUT_DIR / "crashsimulator_public_limitations_tutorial.mp4"
    renderer.SUBTITLE_PATH = renderer.OUT_DIR / "crashsimulator_public_limitations_tutorial_subtitles.vtt"
    renderer.TAGLINE = "Set clear expectations for plan-only, provider-specific, ADB, licensing, and destructive drills"
    renderer.FOOTER_TEXT = "CrashSimulator | Public limitations and safety expectations"
    renderer.main()


if __name__ == "__main__":
    main()
