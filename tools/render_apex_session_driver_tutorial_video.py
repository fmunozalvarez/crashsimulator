#!/usr/bin/env python3
"""Render a CrashSimulator APEX/ORDS session-continuity tutorial video.

Generated assets:
  - assets/tutorial/crashsimulator_apex_session_driver_tutorial.mp4
  - assets/tutorial/crashsimulator_apex_session_driver_tutorial_subtitles.vtt
  - assets/tutorial/README.md

Dependencies:
  python3 -m pip install pillow imageio imageio-ffmpeg
"""

from __future__ import annotations

import render_cli_tutorial_video as renderer
from render_cli_tutorial_video import Scene


BASE_WRITE_README = renderer.write_readme


APEX_SCENES: tuple[Scene, ...] = (
    Scene(
        0,
        7,
        "APEX / ORDS Resilience Tutorial",
        "Overview",
        "This tutorial shows how to collect APEX and ORDS readiness evidence, then run scenario 80 with browser-session evidence.",
        (
            "$ ./CrashSimulatorV2.sh --list | grep 'APEX/ORDS'",
            "73 ORDS service unavailable",
            "78 APEX application availability validation after recovery",
            "80 APEX session continuity test",
            "81 APEX mail queue and configuration validation",
        ),
    ),
    Scene(
        7,
        16,
        "1. Verify The Access Path",
        "Readiness",
        "Start with the APEX and ORDS readiness report so database recovery is tied to the application path users actually depend on.",
        (
            "$ ./CrashSimulatorV2.sh --apex-ords-report \\",
            "    --pdb CRASHDB_PDB1 \\",
            "    --ords-url http://localhost:8080/ords/ \\",
            "    --html",
            "",
            "Checks: APEX version, runtime accounts, invalid objects,",
            "ORDS service, config directory, static files, and smoke URL.",
        ),
    ),
    Scene(
        16,
        26,
        "2. Prepare A Disposable APEX App",
        "Seed",
        "Use a small seeded APEX page with a stable success marker so the browser driver can prove the session is still alive.",
        (
            "Page marker:",
            "<span id=\"CRASHSIM_SESSION_OK\">session active</span>",
            "",
            "Best practice:",
            "  use a lab workspace and test account",
            "  avoid production user credentials",
            "  keep the page simple and deterministic",
        ),
    ),
    Scene(
        26,
        36,
        "3. Self-Check The Driver",
        "Driver",
        "Run the optional Playwright driver self-check before a live drill so missing Node.js, Chromium, or permissions fail early.",
        (
            "$ tools/crashsim_apex_session_driver.cjs --self-check",
            "CrashSimulator APEX session driver self-check OK",
            "",
            "$ export CRASHSIM_APEX_SESSION_DRIVER=tools/crashsim_apex_session_driver.cjs",
            "$ export CRASHSIM_APEX_SESSION_SUCCESS_SELECTOR='#CRASHSIM_SESSION_OK'",
        ),
    ),
    Scene(
        36,
        47,
        "4. Validate Scenario 80",
        "Validate",
        "Validate target readiness before execution. Without a driver, scenario 80 still collects read-only ORDS and continuity evidence.",
        (
            "$ ./CrashSimulatorV2.sh --validate-scenario 80 \\",
            "    --pdb CRASHDB_PDB1 \\",
            "    --ords-url http://localhost:8080/ords/",
            "",
            "Result: RUNNABLE",
            "Reason: ORDS smoke URL and APEX target evidence are available.",
        ),
    ),
    Scene(
        47,
        58,
        "5. Run Read-Only Continuity Evidence",
        "Execute",
        "Execute scenario 80 to create the base continuity report before adding a browser session or while testing only ORDS reachability.",
        (
            "$ ./CrashSimulatorV2.sh --scenario 80 \\",
            "    --pdb CRASHDB_PDB1 \\",
            "    --execute --yes --html",
            "",
            "Generated:",
            "  crashsim_apex_session_continuity_s80_<run_id>.md",
            "  crashsim_apex_session_continuity_s80_<run_id>.md.html",
        ),
    ),
    Scene(
        58,
        70,
        "6. Run With Browser Evidence",
        "Session",
        "For a full user-experience drill, keep the browser driver polling while you restart ORDS, relocate a RAC service, or perform a recovery step.",
        (
            "$ ./CrashSimulatorV2.sh --scenario 80 --execute --yes \\",
            "    --pdb CRASHDB_PDB1 \\",
            "    --apex-session-driver tools/crashsim_apex_session_driver.cjs \\",
            "    --apex-session-url https://lab.example.com/ords/r/app/session \\",
            "    --apex-session-success-selector '#CRASHSIM_SESSION_OK' \\",
            "    --apex-session-duration 120",
        ),
    ),
    Scene(
        70,
        82,
        "7. Capture The Event Window",
        "Drill",
        "Trigger the planned event from another terminal while the driver keeps checking the active APEX page.",
        (
            "Examples during the 120-second window:",
            "",
            "$ sudo systemctl restart ords",
            "$ srvctl relocate service -db CRASHDB -service APP_SVC",
            "$ ./CrashSimulatorV2.sh --recover 30 --execute",
            "",
            "Record whether the user sees retry, relogin, lost state, or seamless continuation.",
        ),
    ),
    Scene(
        82,
        93,
        "8. Review Evidence",
        "Evidence",
        "Finish by reviewing Markdown, HTML, JSON, and screenshots, then feed the result into service, pool, AC/TAC, and ORDS design.",
        (
            "Evidence bundle:",
            "  APEX/ORDS readiness report",
            "  scenario 80 runbook and continuity report",
            "  apex_session_driver_report.md",
            "  apex_session_driver_result.json",
            "  baseline.png and final.png",
        ),
    ),
    Scene(
        93,
        102,
        "9. Keep It Auditable",
        "Audit",
        "Preserve the scenario manifest, audit log, screenshots, and HTML report so the drill can support training and compliance review.",
        (
            "$ ./CrashSimulatorV2.sh --show-artifact latest:apex-ords --html",
            "$ ./CrashSimulatorV2.sh --show-artifact latest:scenario --html",
            "",
            "Outcome:",
            "  application access-path evidence",
            "  user-session behavior",
            "  recovery objective timestamps",
        ),
    ),
)


def write_apex_readme() -> None:
    BASE_WRITE_README()


def main() -> None:
    renderer.SCENES = APEX_SCENES
    renderer.TOTAL_SECONDS = 102
    renderer.VIDEO_PATH = renderer.OUT_DIR / "crashsimulator_apex_session_driver_tutorial.mp4"
    renderer.SUBTITLE_PATH = renderer.OUT_DIR / "crashsimulator_apex_session_driver_tutorial_subtitles.vtt"
    renderer.TAGLINE = "Validate APEX/ORDS readiness and capture scenario 80 browser-session evidence"
    renderer.FOOTER_TEXT = "CrashSimulator | APEX/ORDS readiness and scenario 80 session continuity"
    renderer.write_readme = write_apex_readme
    renderer.main()


if __name__ == "__main__":
    main()
