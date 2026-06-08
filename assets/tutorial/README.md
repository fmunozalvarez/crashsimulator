# CrashSimulator Tutorial Videos

Generated assets:

- `crashsimulator_cli_tutorial.mp4`: short 1080p CLI setup and scenario tutorial with burned-in subtitles.
- `crashsimulator_cli_tutorial_with_audio.mp4`: narrated CLI setup and scenario tutorial generated from the subtitles.
- `crashsimulator_cli_tutorial_subtitles.vtt`: CLI tutorial WebVTT subtitle sidecar.
- `crashsimulator_guided_workflow_tutorial.mp4`: short 1080p Guided Workflow menu scenario tutorial with burned-in subtitles.
- `crashsimulator_guided_workflow_tutorial_with_audio.mp4`: narrated Guided Workflow menu scenario tutorial generated from the subtitles.
- `crashsimulator_guided_workflow_tutorial_subtitles.vtt`: Guided Workflow tutorial WebVTT subtitle sidecar.
- `crashsimulator_audit_retention_tutorial.mp4`: short 1080p audit retention tutorial for CLI and Guided Workflow menu modes with burned-in subtitles.
- `crashsimulator_audit_retention_tutorial_with_audio.mp4`: narrated audit retention tutorial generated from the subtitles.
- `crashsimulator_audit_retention_tutorial_subtitles.vtt`: audit retention tutorial WebVTT subtitle sidecar.
- `crashsimulator_scenario_readiness_tutorial.mp4`: short 1080p scenario readiness tutorial for CLI and Guided Workflow menu modes with burned-in subtitles.
- `crashsimulator_scenario_readiness_tutorial_with_audio.mp4`: narrated scenario readiness tutorial generated from the subtitles.
- `crashsimulator_scenario_readiness_tutorial_subtitles.vtt`: scenario readiness tutorial WebVTT subtitle sidecar.
- `crashsimulator_guided_reports_menu_tutorial.mp4`: short 1080p Guided Workflow Reports menu tutorial with burned-in subtitles.
- `crashsimulator_guided_reports_menu_tutorial_with_audio.mp4`: narrated Guided Workflow Reports menu tutorial generated from the subtitles.
- `crashsimulator_guided_reports_menu_tutorial_subtitles.vtt`: Guided Workflow Reports menu tutorial WebVTT subtitle sidecar.
- `crashsimulator_apex_session_driver_tutorial.mp4`: short 1080p APEX/ORDS readiness and scenario 80 browser-session tutorial with burned-in subtitles.
- `crashsimulator_apex_session_driver_tutorial_with_audio.mp4`: narrated APEX/ORDS scenario 80 tutorial generated from the subtitles.
- `crashsimulator_apex_session_driver_tutorial_subtitles.vtt`: APEX/ORDS tutorial WebVTT subtitle sidecar.
- `crashsimulator_config_review_tutorial.mp4`: short 1080p configuration, file selection, and Review Center tutorial with burned-in subtitles.
- `crashsimulator_config_review_tutorial_with_audio.mp4`: narrated configuration and review tutorial generated from the subtitles.
- `crashsimulator_config_review_tutorial_subtitles.vtt`: configuration and review tutorial WebVTT subtitle sidecar.
- `crashsimulator_adb_readiness_tutorial.mp4`: short 1080p Autonomous Database readiness report tutorial with burned-in subtitles.
- `crashsimulator_adb_readiness_tutorial_with_audio.mp4`: narrated ADB readiness tutorial generated from the subtitles.
- `crashsimulator_adb_readiness_tutorial_subtitles.vtt`: ADB readiness tutorial WebVTT subtitle sidecar.
- `crashsimulator_adb_scenario_tutorial.mp4`: short 1080p ADB scenario selection and validation tutorial with burned-in subtitles.
- `crashsimulator_adb_scenario_tutorial_with_audio.mp4`: narrated ADB scenario tutorial generated from the subtitles.
- `crashsimulator_adb_scenario_tutorial_subtitles.vtt`: ADB scenario tutorial WebVTT subtitle sidecar.
- `crashsimulator_best_practices_tutorial.mp4`: short 1080p CrashSimulator best-practice operating model tutorial with burned-in subtitles.
- `crashsimulator_best_practices_tutorial_with_audio.mp4`: narrated best-practices tutorial generated from the subtitles.
- `crashsimulator_best_practices_tutorial_subtitles.vtt`: best-practices tutorial WebVTT subtitle sidecar.

Regenerate from the repository root with:

```bash
python3 -m pip install pillow imageio imageio-ffmpeg
python3 tools/render_cli_tutorial_video.py
python3 tools/render_guided_workflow_tutorial_video.py
python3 tools/render_audit_retention_tutorial_video.py
python3 tools/render_scenario_readiness_tutorial_video.py
python3 tools/render_guided_reports_menu_tutorial_video.py
python3 tools/render_apex_session_driver_tutorial_video.py
python3 tools/render_config_review_tutorial_video.py
python3 tools/render_adb_readiness_tutorial_video.py
python3 tools/render_adb_scenario_tutorial_video.py
python3 tools/render_best_practices_tutorial_video.py
```

On macOS, regenerate the narrated copies from the subtitle scripts with:

```bash
python3 tools/add_tutorial_audio.py --voice Samantha --rate 175
```

The tutorial set demonstrates direct CLI execution, the menu-driven
best-practice scenario workflow, audit-retention operations, topology-aware
scenario readiness reporting, and Guided Workflow Reports menu evidence. The
readiness tutorial covers generating the environment-versus-scenario report,
reading the runnable/blocked buckets, using `latest:scenario-readiness`, and
launching the same capability from the Guided Workflow menu. The Reports menu
tutorial covers configuration, MAA best practices, Oracle service HA review,
backup strategy/recoverability, baseline backups, lifecycle coverage, and HTML
evidence review. The configuration and review tutorial covers saved defaults,
target prompts, FILE# selection, and inspecting retained audit/report/manifest
artifacts. The ADB tutorials cover ADB readiness reporting, report context,
ADB01-ADB15 browsing, and ADB scenario validation posture. The APEX/ORDS
tutorial covers readiness reporting, seeded scenario 80 browser-session
evidence, and preserving user-facing artifacts. The best-practices tutorial
summarizes the recommended operating model from discovery to post-drill
stabilization and evidence retention.
