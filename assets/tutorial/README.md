# CrashSimulator Tutorial Videos

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
