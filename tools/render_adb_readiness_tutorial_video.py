#!/usr/bin/env python3
"""Render a CrashSimulator Autonomous Database readiness tutorial video."""

from __future__ import annotations

import render_cli_tutorial_video as renderer
from render_cli_tutorial_video import Scene


BASE_WRITE_README = renderer.write_readme


ADB_READINESS_SCENES: tuple[Scene, ...] = (
    Scene(
        0,
        7,
        "Autonomous Database Readiness",
        "Overview",
        "This tutorial shows how CrashSimulator validates an Autonomous Database target without requiring database-host access.",
        (
            "$ ./CrashSimulatorV2.sh --adb-readiness-report --help",
            "",
            "ADB coverage focuses on:",
            "  logical recovery, clone and PITR readiness",
            "  wallet and connectivity, private endpoint paths",
            "  service limits, Autonomous Data Guard, IAM, Object Storage",
        ),
    ),
    Scene(
        7,
        17,
        "1. Prepare The Client Host",
        "Client",
        "Run the report from a bastion or client host that can reach the ADB endpoint and has the wallet and python-oracledb available.",
        (
            "$ python3 -m venv ~/crashsim_adb/venv",
            "$ ~/crashsim_adb/venv/bin/pip install oracledb",
            "$ unzip Wallet_myadb.zip -d ~/crashsim_adb/wallet",
            "",
            "No local sqlplus, RMAN, ASM, Grid Infrastructure,",
            "or Oracle OS account is required for ADB readiness.",
        ),
    ),
    Scene(
        17,
        27,
        "2. Set Non-Secret Context",
        "Context",
        "Use crashsimulator.conf for ADB wallet path, alias, URLs, and OCI metadata hints while keeping passwords outside the file.",
        (
            "CRASHSIM_ADB_WALLET_DIR=/home/opc/crashsim_adb/wallet",
            "CRASHSIM_ADB_CONNECT_ALIAS=crashautonomous_low",
            "CRASHSIM_ADB_USER=ADMIN",
            "CRASHSIM_ADB_TLS_MODE=mTLS",
            "CRASHSIM_ADB_APEX_URL=https://example.adb.region/ords/apex",
            "CRASHSIM_ADB_DATABASE_ACTIONS_URL=https://example.adb.region/ords/sql-developer",
        ),
    ),
    Scene(
        27,
        37,
        "3. Keep Passwords In Env Vars",
        "Secrets",
        "Provide database and wallet passwords with environment variables so generated reports can reference the variable names without exposing values.",
        (
            "$ export CRASHSIM_ADB_PASSWORD='stored securely'",
            "$ export CRASHSIM_ADB_WALLET_PASSWORD='stored securely'",
            "",
            "The report records:",
            "  Password env var: CRASHSIM_ADB_PASSWORD",
            "  Wallet password env var: CRASHSIM_ADB_WALLET_PASSWORD",
            "",
            "It does not print the secret values.",
        ),
    ),
    Scene(
        37,
        49,
        "4. Generate The Report",
        "Report",
        "Run the ADB readiness report with HTML output to collect connection, SQL, APEX, logical recovery, and scenario coverage evidence.",
        (
            "$ ./CrashSimulatorV2.sh --adb-readiness-report --html",
            "",
            "Autonomous Database readiness report generated:",
            "  crashsim_adb_readiness_<run_id>.md",
            "Latest Autonomous Database readiness report:",
            "  crashsim_adb_readiness_latest.md",
            "HTML copy:",
            "  crashsim_adb_readiness_<run_id>.md.html",
        ),
    ),
    Scene(
        49,
        60,
        "5. Read The Live Evidence",
        "Evidence",
        "The report separates client configuration from live SQL evidence, so users can see what was proven and what still needs OCI metadata.",
        (
            "Live SQL Evidence Summary",
            "",
            "SQL connection: OK",
            "Database role: PRIMARY",
            "Open mode: READ WRITE",
            "APEX registry: 24.2.17:VALID",
            "Flashback archive retention: 60 days",
            "Invalid objects: 0",
        ),
    ),
    Scene(
        60,
        72,
        "6. Review Readiness Checks",
        "Checks",
        "Use the readiness score and checks to identify gaps before logical, clone, wallet, Data Guard, or Object Storage drills.",
        (
            "Readiness Summary",
            "",
            "Readiness score: 85%",
            "OK checks: 6",
            "Warnings: 1",
            "Gaps: 0",
            "",
            "Typical warning: OCI control-plane metadata not configured.",
        ),
    ),
    Scene(
        72,
        84,
        "7. Use The Guided Menu",
        "Menu",
        "The Guided Workflow Reports menu can set ADB report context, generate the readiness report, and browse generated artifacts.",
        (
            "$ ./CrashSimulatorV2.sh --menu",
            "",
            "Reports",
            " 12. Set Autonomous Database report context",
            " 13. Generate Autonomous Database readiness report",
            " 14. Browse generated reports and inspect contents",
            " 15. List Autonomous Database scenarios with readiness status",
            " 18. Open Autonomous Database scenarios submenu",
        ),
    ),
    Scene(
        84,
        96,
        "8. Preserve And Share",
        "Review",
        "Finish by saving the Markdown, HTML, raw evidence, and audit record so the ADB posture can be compared over time.",
        (
            "$ ./CrashSimulatorV2.sh --show-artifact latest:adb",
            "$ ./CrashSimulatorV2.sh --show-artifact latest:adb --html",
            "$ ./CrashSimulatorV2.sh --review --html",
            "",
            "Evidence to keep:",
            "  readiness report, evidence file, config context,",
            "  APEX URL smoke result, OCI metadata when configured.",
        ),
    ),
)


def write_adb_readiness_readme() -> None:
    BASE_WRITE_README()


def main() -> None:
    renderer.SCENES = ADB_READINESS_SCENES
    renderer.TOTAL_SECONDS = 96
    renderer.VIDEO_PATH = renderer.OUT_DIR / "crashsimulator_adb_readiness_tutorial.mp4"
    renderer.SUBTITLE_PATH = renderer.OUT_DIR / "crashsimulator_adb_readiness_tutorial_subtitles.vtt"
    renderer.TAGLINE = "Generate Autonomous Database readiness evidence from a client or bastion host"
    renderer.FOOTER_TEXT = "CrashSimulator | Autonomous Database readiness reporting"
    renderer.write_readme = write_adb_readiness_readme
    renderer.main()


if __name__ == "__main__":
    main()
