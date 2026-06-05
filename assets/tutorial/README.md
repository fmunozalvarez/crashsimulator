# CrashSimulator CLI Tutorial Video

Generated assets:

- `crashsimulator_cli_tutorial.mp4`: short 1080p CLI tutorial with burned-in subtitles.
- `crashsimulator_cli_tutorial_subtitles.vtt`: WebVTT subtitle sidecar.

Regenerate from the repository root with:

```bash
python3 -m pip install pillow imageio imageio-ffmpeg
python3 tools/render_cli_tutorial_video.py
```

The tutorial demonstrates the normal CLI flow:

1. Install CrashSimulator from the ZIP/repository.
2. Set the Oracle software owner environment.
3. Discover the database topology and run health checks.
4. Validate a scenario and review the dry-run plan.
5. Protect the target, execute the drill, recover from the manifest, and validate the outcome.
