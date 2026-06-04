#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const { chromium } = require("playwright");

const root = path.resolve(__dirname, "..");
const htmlDir = path.join(root, "captures", "html");
const outDir = path.join(root, "assets", "screenshots");

fs.mkdirSync(htmlDir, { recursive: true });
fs.mkdirSync(outDir, { recursive: true });

function escapeHtml(value) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function stripAnsi(value) {
  return value.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "").replace(/\r/g, "");
}

function wrapLine(line, width) {
  if (line.length <= width) {
    return [line];
  }

  const lines = [];
  let rest = line;
  while (rest.length > width) {
    let cut = rest.lastIndexOf(" ", width);
    if (cut < Math.floor(width * 0.55)) {
      cut = width;
    }
    lines.push(rest.slice(0, cut));
    rest = rest.slice(cut).replace(/^\s+/, "  ");
  }
  lines.push(rest);
  return lines;
}

function lineClass(line) {
  if (/^(CrashSimulator V2|Aleatory scenario|Reports|Guided Workflow)/.test(line)) {
    return "accent";
  }
  if (/^(Database:|Instance:|Topology:|PDB target context:|Mode:|Manifest:)/.test(line)) {
    return "info";
  }
  if (/^(Scenario|Group:|Scope:|Impact:|Requires:|Notes:)/.test(line)) {
    return "strong";
  }
  if (/DRY-RUN|Recovery runbook|Planned actions|Generate target/.test(line)) {
    return "success";
  }
  if (/destructive|requires|abort|external/.test(line)) {
    return "warn";
  }
  if (/Choice:/.test(line)) {
    return "choice";
  }
  return "";
}

function fileUrl(filePath) {
  return `file://${filePath.replace(/ /g, "%20")}`;
}

function writePage(config) {
  const text = fs.readFileSync(path.join(root, config.input), "utf8");
  const rawLines = [config.prompt, "", ...stripAnsi(text).split("\n")];
  let lines = [];
  for (const line of rawLines) {
    lines.push(...wrapLine(line, config.wrap || 116));
  }
  lines = lines.filter((line, index) => index < lines.length - 1 || line.trim() !== "");
  if (config.lineLimit) {
    lines = lines.slice(0, config.lineLimit);
  }

  const maxLines = Math.floor((config.height - 235) / 32);
  if (lines.length > maxLines) {
    lines = lines.slice(0, maxLines - 1).concat(["..."]);
  }

  const terminalLines = lines
    .map((line) => `<div class="line ${lineClass(line)}">${escapeHtml(line) || "&nbsp;"}</div>`)
    .join("\n");

  const html = `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>${escapeHtml(config.title)}</title>
  <style>
    :root { color-scheme: dark; }
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      width: 2400px;
      min-height: ${config.height}px;
      background: #061826;
    }
    body {
      font-family: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: #e2e8f0;
    }
    .canvas {
      position: relative;
      width: 2400px;
      min-height: ${config.height}px;
      padding: 70px;
      background: linear-gradient(135deg, #061826 0%, #101827 56%, #182033 100%);
    }
    .window {
      min-height: ${config.height - 140}px;
      border: 2px solid #334155;
      border-radius: 18px;
      background: #0b1120;
      overflow: hidden;
      box-shadow: 0 28px 48px rgba(0, 0, 0, .42);
    }
    .titlebar {
      height: 82px;
      display: flex;
      align-items: center;
      gap: 18px;
      padding: 0 50px;
      background: #111827;
      border-bottom: 1px solid #1e293b;
    }
    .dot {
      width: 26px;
      height: 26px;
      border-radius: 999px;
      flex: none;
    }
    .red { background: #ef4444; }
    .yellow { background: #f59e0b; }
    .green { background: #22c55e; }
    .title {
      margin-left: 12px;
      font-size: 28px;
      font-weight: 750;
      color: #f8fafc;
    }
    .subtitle {
      margin-left: auto;
      font-size: 22px;
      color: #94a3b8;
    }
    .terminal {
      padding: 34px 50px 66px;
      font: 25px/32px SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;
      letter-spacing: 0;
      white-space: pre;
    }
    .line { height: 32px; color: #cbd5e1; }
    .accent { color: #7dd3fc; font-weight: 700; }
    .info { color: #c4b5fd; }
    .strong { color: #f8fafc; }
    .success { color: #bef264; }
    .warn { color: #fdba74; }
    .choice { color: #fef08a; }
    .brand {
      position: absolute;
      right: 120px;
      bottom: 92px;
      color: #64748b;
      font-size: 22px;
    }
  </style>
</head>
<body>
  <main class="canvas">
    <section class="window">
      <div class="titlebar">
        <span class="dot red"></span>
        <span class="dot yellow"></span>
        <span class="dot green"></span>
        <div class="title">${escapeHtml(config.title)}</div>
        <div class="subtitle">${escapeHtml(config.subtitle)}</div>
      </div>
      <div class="terminal">${terminalLines}</div>
    </section>
    <div class="brand">CrashSimulator for Oracle Database resilience validation</div>
  </main>
</body>
</html>`;

  const htmlPath = path.join(htmlDir, config.html);
  fs.writeFileSync(htmlPath, html);
  return htmlPath;
}

async function render(config, browser) {
  const htmlPath = writePage(config);
  const page = await browser.newPage({
    viewport: { width: 2400, height: config.height },
    deviceScaleFactor: 1,
  });
  await page.goto(fileUrl(htmlPath), { waitUntil: "load" });
  await page.screenshot({
    path: path.join(outDir, config.output),
    fullPage: true,
  });
  await page.close();
}

(async () => {
  const chromePath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
  const executablePath =
    process.env.CRASHSIM_BROWSER_EXECUTABLE ||
    (fs.existsSync(chromePath) ? chromePath : undefined);
  const browser = await chromium.launch({
    headless: true,
    executablePath,
  });
  try {
    const configs = [
      {
        input: "captures/cli_aleatory_dry_run.txt",
        html: "cli_aleatory_dry_run.html",
        output: "crashsim_cli_aleatory_dry_run.png",
        title: "Aleatory Scenario Dry-Run",
        subtitle: "CLI mode | RAC/GI/ASM lab",
        prompt: "$ ./CrashSimulatorV2.sh --random-scenario --pdb CRASHPDB --dry-run",
        height: 1600,
      },
      {
        input: "captures/guided_workflow_menu.txt",
        html: "guided_workflow_menu.html",
        output: "crashsim_guided_workflow_menu.png",
        title: "Guided Workflow Menu",
        subtitle: "Menu mode | topology-aware workflow",
        prompt: "$ ./CrashSimulatorV2.sh --menu",
        height: 1500,
      },
      {
        input: "captures/guided_reports_menu.txt",
        html: "guided_reports_menu.html",
        output: "crashsim_guided_reports_menu.png",
        title: "Reports Workflow",
        subtitle: "Guided menu | configuration and recoverability reports",
        prompt: "$ ./CrashSimulatorV2.sh --menu",
        height: 1700,
        lineLimit: 42,
      },
    ];

    for (const config of configs) {
      await render(config, browser);
      console.log(path.join(outDir, config.output));
    }
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
