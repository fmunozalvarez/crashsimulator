# CrashSimulator Tutorial Videos

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
