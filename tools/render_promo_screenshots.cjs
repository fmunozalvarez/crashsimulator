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

function parseScenarios() {
  const text = fs.readFileSync(path.join(root, "captures", "scenarios_available.txt"), "utf8");
  return text
    .split("\n")
    .map((line) => line.match(/^\s*(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)$/))
    .filter((match) => match && match[1] !== "ID")
    .map((match) => ({
      id: Number(match[1]),
      group: match[2],
      scope: match[3],
      impact: match[4],
      title: match[5].trim(),
    }));
}

function scenarioAccent(group) {
  const colors = {
    Core: "#38bdf8",
    Logical: "#a78bfa",
    Config: "#fbbf24",
    Corrupt: "#fb7185",
    Backup: "#bef264",
    PDB: "#22d3ee",
    ASM: "#f97316",
    GI: "#f59e0b",
    DataGuard: "#60a5fa",
    ADG: "#818cf8",
    RAC: "#34d399",
    Network: "#2dd4bf",
    Security: "#f472b6",
  };
  return colors[group] || "#94a3b8";
}

function impactClass(impact) {
  return impact === "logical" ? "logical" : "destructive";
}

function writeScenarioCatalogPage() {
  const scenarios = parseScenarios();
  const byGroup = new Map();
  for (const scenario of scenarios) {
    if (!byGroup.has(scenario.group)) {
      byGroup.set(scenario.group, []);
    }
    byGroup.get(scenario.group).push(scenario);
  }

  const groupCounts = [...byGroup.entries()]
    .map(([group, rows]) => `<span class="pill" style="--accent:${scenarioAccent(group)}">${escapeHtml(group)} <b>${rows.length}</b></span>`)
    .join("");

  const logicalCount = scenarios.filter((scenario) => scenario.impact === "logical").length;
  const destructiveCount = scenarios.length - logicalCount;

  function renderGroupCard(group, rows) {
      const scenarioRows = rows
        .map((scenario) => `<div class="scenario-row" style="--accent:${scenarioAccent(group)}">
          <div class="id">${String(scenario.id).padStart(2, "0")}</div>
          <div class="scenario-main">
            <div class="scenario-title">${escapeHtml(scenario.title)}</div>
            <div class="scenario-meta">
              <span>${escapeHtml(scenario.scope)}</span>
              <span class="${impactClass(scenario.impact)}">${escapeHtml(scenario.impact)}</span>
            </div>
          </div>
        </div>`)
        .join("");
      return `<section class="group-card">
        <header style="--accent:${scenarioAccent(group)}">
          <h2>${escapeHtml(group)}</h2>
          <span>${rows.length} scenarios</span>
        </header>
        ${scenarioRows}
      </section>`;
  }

  const leftGroups = ["Core", "Config", "Backup", "ASM", "DataGuard", "RAC", "Security"];
  const rightGroups = ["PDB", "Logical", "Corrupt", "GI", "ADG", "Network"];
  const leftCards = leftGroups
    .filter((group) => byGroup.has(group))
    .map((group) => renderGroupCard(group, byGroup.get(group)))
    .join("");
  const rightCards = rightGroups
    .filter((group) => byGroup.has(group))
    .map((group) => renderGroupCard(group, byGroup.get(group)))
    .join("");

  const html = `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>CrashSimulator Scenario Catalog</title>
  <style>
    :root { color-scheme: dark; }
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      width: 2400px;
      background: #061826;
    }
    body {
      font-family: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: #e2e8f0;
    }
    .canvas {
      position: relative;
      width: 2400px;
      min-height: 3300px;
      padding: 86px;
      background:
        radial-gradient(circle at 15% 12%, rgba(56, 189, 248, .16), transparent 28%),
        radial-gradient(circle at 88% 8%, rgba(190, 242, 100, .12), transparent 24%),
        linear-gradient(135deg, #061826 0%, #101827 56%, #182033 100%);
    }
    .hero {
      border: 2px solid #334155;
      border-radius: 22px;
      background: rgba(15, 23, 42, .82);
      box-shadow: 0 28px 48px rgba(0, 0, 0, .38);
      padding: 54px 58px;
      margin-bottom: 34px;
    }
    .kicker {
      color: #7dd3fc;
      font-size: 24px;
      font-weight: 760;
      letter-spacing: .08em;
      text-transform: uppercase;
    }
    h1 {
      margin: 14px 0 12px;
      color: #f8fafc;
      font-size: 70px;
      line-height: 1.05;
      letter-spacing: 0;
    }
    .summary {
      max-width: 1680px;
      color: #cbd5e1;
      font-size: 30px;
      line-height: 1.42;
      margin: 0;
    }
    .stats {
      display: flex;
      gap: 18px;
      margin-top: 32px;
      flex-wrap: wrap;
    }
    .stat {
      border: 1px solid #334155;
      border-radius: 12px;
      background: #0b1120;
      padding: 18px 22px;
      min-width: 240px;
    }
    .stat b {
      color: #f8fafc;
      display: block;
      font-size: 44px;
      line-height: 1;
    }
    .stat span {
      color: #94a3b8;
      font-size: 20px;
    }
    .pills {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      margin-top: 28px;
    }
    .pill {
      color: #e2e8f0;
      background: color-mix(in srgb, var(--accent) 15%, #0b1120);
      border: 1px solid color-mix(in srgb, var(--accent) 45%, #334155);
      border-radius: 999px;
      padding: 9px 14px;
      font-size: 19px;
    }
    .pill b { color: var(--accent); }
    .columns {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 24px;
      align-items: start;
    }
    .column {
      display: flex;
      flex-direction: column;
      gap: 24px;
    }
    .group-card {
      break-inside: avoid;
      border: 1px solid #334155;
      border-radius: 18px;
      background: rgba(11, 17, 32, .96);
      overflow: hidden;
      box-shadow: 0 14px 26px rgba(0, 0, 0, .22);
    }
    .group-card header {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      padding: 20px 24px;
      background: color-mix(in srgb, var(--accent) 14%, #111827);
      border-bottom: 1px solid #1e293b;
    }
    .group-card h2 {
      margin: 0;
      color: var(--accent);
      font-size: 28px;
      letter-spacing: 0;
    }
    .group-card header span {
      color: #94a3b8;
      font-size: 18px;
    }
    .scenario-row {
      display: grid;
      grid-template-columns: 58px 1fr;
      gap: 14px;
      padding: 14px 22px;
      border-bottom: 1px solid rgba(51, 65, 85, .55);
    }
    .scenario-row:last-child { border-bottom: 0; }
    .id {
      width: 48px;
      height: 34px;
      border-radius: 9px;
      display: grid;
      place-items: center;
      color: #0b1120;
      background: var(--accent);
      font-weight: 800;
      font-size: 18px;
      font-variant-numeric: tabular-nums;
      margin-top: 2px;
    }
    .scenario-title {
      color: #f8fafc;
      font-size: 22px;
      line-height: 1.28;
      letter-spacing: 0;
    }
    .scenario-meta {
      display: flex;
      gap: 10px;
      margin-top: 8px;
      flex-wrap: wrap;
    }
    .scenario-meta span {
      color: #cbd5e1;
      border: 1px solid #334155;
      border-radius: 999px;
      padding: 5px 10px;
      font-size: 15px;
      line-height: 1;
      background: #0f172a;
    }
    .scenario-meta .logical {
      color: #c4b5fd;
      border-color: rgba(196, 181, 253, .45);
    }
    .scenario-meta .destructive {
      color: #fdba74;
      border-color: rgba(253, 186, 116, .45);
    }
    .brand {
      position: absolute;
      right: 116px;
      bottom: 68px;
      color: #64748b;
      font-size: 22px;
    }
  </style>
</head>
<body>
  <main class="canvas">
    <section class="hero">
      <div class="kicker">Current Scenario Registry</div>
      <h1>CrashSimulator Scenario Catalog</h1>
      <p class="summary">Controlled Oracle Database failure and recovery drills across CDB/non-CDB, PDB, backup/recovery, configuration, ASM/Grid Infrastructure, RAC, Data Guard, Active Data Guard, network, and security domains.</p>
      <div class="stats">
        <div class="stat"><b>${scenarios.length}</b><span>registered scenarios</span></div>
        <div class="stat"><b>${destructiveCount}</b><span>destructive drills</span></div>
        <div class="stat"><b>${logicalCount}</b><span>logical drills</span></div>
        <div class="stat"><b>${byGroup.size}</b><span>coverage groups</span></div>
      </div>
      <div class="pills">${groupCounts}</div>
    </section>
    <section class="columns">
      <div class="column">${leftCards}</div>
      <div class="column">${rightCards}</div>
    </section>
    <div class="brand">Generated from ./CrashSimulatorV2.sh --list</div>
  </main>
</body>
</html>`;

  const htmlPath = path.join(htmlDir, "scenario_catalog.html");
  fs.writeFileSync(htmlPath, html);
  return htmlPath;
}

async function renderScenarioCatalog(browser) {
  const htmlPath = writeScenarioCatalogPage();
  const page = await browser.newPage({
    viewport: { width: 2400, height: 3300 },
    deviceScaleFactor: 1,
  });
  await page.goto(fileUrl(htmlPath), { waitUntil: "load" });
  await page.screenshot({
    path: path.join(outDir, "crashsim_scenario_catalog.png"),
    fullPage: true,
  });
  await page.close();
  console.log(path.join(outDir, "crashsim_scenario_catalog.png"));
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
    await renderScenarioCatalog(browser);
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
