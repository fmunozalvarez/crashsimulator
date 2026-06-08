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
  if (/^(CrashSimulator V2|Aleatory scenario|Reports|Guided Workflow|Autonomous Database Scenarios|# CrashSimulator Oracle MAA|# CrashSimulator Scenario Readiness|# CrashSimulator Autonomous Database|CrashSimulator Best-Practice|MAA readiness)/.test(line)) {
    return "accent";
  }
  if (/^(Database:|DB unique name:|Instance:|Topology:|PDB target context:|Mode:|Manifest:|Detected MAA posture:|Readiness status:)/.test(line)) {
    return "info";
  }
  if (/^(Scenario|Group:|Scope:|Impact:|Requires:|Notes:)/.test(line)) {
    return "strong";
  }
  if (/DRY-RUN|RUNNABLE|Recovery runbook|Planned actions|Generate target|Oracle MAA readiness|MAA readiness report generated|Baseline checks passed|Oracle AI Database 26ai/.test(line)) {
    return "success";
  }
  if (/PLAN-ONLY|NOT-RUNNABLE|destructive|requires|abort|external|GAP|WARN/.test(line)) {
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
  const rawLines = config.prompt
    ? [config.prompt, "", ...stripAnsi(text).split("\n")]
    : stripAnsi(text).split("\n");
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
    Compliance: "#facc15",
    "APEX/ORDS": "#fb7185",
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
  const rightGroups = ["PDB", "Logical", "Corrupt", "GI", "ADG", "Network", "Compliance", "APEX/ORDS"];
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

function splitMarkdownRow(line) {
  return line
    .trim()
    .replace(/^\|/, "")
    .replace(/\|$/, "")
    .split("|")
    .map((part) => part.trim().replace(/^`([^`]*)`$/, "$1"));
}

function cleanMarkdownText(value) {
  return value
    .replace(/`([^`]*)`/g, "$1")
    .replace(/\s+/g, " ")
    .trim();
}

function parseMaaReport() {
  const text = fs.readFileSync(path.join(root, "captures", "maa_report_latest.md"), "utf8");
  const lines = text.split("\n");
  const meta = {};
  const evidence = [];
  const checks = [];
  const sla = [];

  for (const line of lines) {
    const metaMatch = line.match(/^- ([^:]+): `([^`]*)`/);
    if (metaMatch) {
      meta[metaMatch[1]] = metaMatch[2];
    }
  }

  let section = "";
  for (const line of lines) {
    if (line.startsWith("## ")) {
      section = line.replace(/^##\s+/, "").trim();
      continue;
    }
    if (!line.startsWith("|") || line.includes("| ---")) {
      continue;
    }
    const row = splitMarkdownRow(line);
    if (section === "Evidence Summary" && row[0] !== "Area" && row.length >= 2) {
      evidence.push({ area: cleanMarkdownText(row[0]), detail: cleanMarkdownText(row[1]) });
    }
    if (section === "Best-Practice Checks" && row[0] !== "Status" && row.length >= 5) {
      checks.push({
        status: cleanMarkdownText(row[0]),
        area: cleanMarkdownText(row[1]),
        check: cleanMarkdownText(row[2]),
        evidence: cleanMarkdownText(row[3]),
        recommendation: cleanMarkdownText(row[4]),
      });
    }
    if (section === "SLA / RTO / RPO Planning Context" && row[0] !== "Requirement" && row.length >= 2) {
      sla.push({ requirement: cleanMarkdownText(row[0]), value: cleanMarkdownText(row[1]) });
    }
  }

  const hintMatch = text.match(/Preliminary recommendation hint:\s+(.+)/);
  return {
    meta,
    evidence,
    checks,
    sla,
    hint: hintMatch ? cleanMarkdownText(hintMatch[1]) : "",
  };
}

function statusClass(status) {
  const normalized = status.replace(/`/g, "").toLowerCase();
  if (normalized === "ok") return "ok";
  if (normalized === "warn") return "warn";
  if (normalized === "gap") return "gap";
  return "info";
}

function writeMaaSummaryPage() {
  const report = parseMaaReport();
  const detected = report.meta["Detected MAA posture"] || "Unknown";
  const readiness = report.meta["Readiness status"] || "Unknown";
  const levels = ["Bronze", "Silver", "Gold", "Platinum", "Diamond"];
  const levelIndex = Math.max(0, levels.indexOf(detected));
  const evidenceCards = report.evidence
    .slice(0, 7)
    .map((row) => `<article class="evidence-card">
      <h3>${escapeHtml(row.area)}</h3>
      <p>${escapeHtml(row.detail)}</p>
    </article>`)
    .join("");
  const checkRows = report.checks
    .slice(0, 11)
    .map((row) => `<div class="check-row">
      <span class="status ${statusClass(row.status)}">${escapeHtml(row.status)}</span>
      <div>
        <b>${escapeHtml(row.check)}</b>
        <p>${escapeHtml(row.recommendation)}</p>
        <small>${escapeHtml(row.evidence)}</small>
      </div>
    </div>`)
    .join("");
  const slaRows = report.sla
    .slice(0, 7)
    .map((row) => `<div class="sla-row"><span>${escapeHtml(row.requirement)}</span><b>${escapeHtml(row.value)}</b></div>`)
    .join("");
  const levelCards = levels
    .map((level, index) => `<div class="level ${index <= levelIndex ? "active" : ""} ${level === detected ? "current" : ""}">
      <span>${escapeHtml(level)}</span>
      <small>${index <= levelIndex ? "detected path" : "next capability"}</small>
    </div>`)
    .join("");

  const html = `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>CrashSimulator MAA Readiness Summary</title>
  <style>
    :root { color-scheme: dark; }
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      width: 2400px;
      min-height: 1800px;
      background: #061826;
    }
    body {
      font-family: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: #e2e8f0;
    }
    .canvas {
      position: relative;
      width: 2400px;
      min-height: 1800px;
      padding: 76px 76px 54px;
      background: linear-gradient(135deg, #061826 0%, #0f172a 54%, #182033 100%);
    }
    .top {
      display: grid;
      grid-template-columns: 1.18fr .82fr;
      gap: 34px;
      align-items: stretch;
      margin-bottom: 34px;
    }
    .hero,
    .panel {
      border: 2px solid #334155;
      border-radius: 20px;
      background: rgba(11, 17, 32, .94);
      box-shadow: 0 28px 48px rgba(0, 0, 0, .34);
    }
    .hero {
      padding: 54px 58px;
      min-height: 414px;
    }
    .kicker {
      color: #7dd3fc;
      font-size: 25px;
      font-weight: 780;
      letter-spacing: .08em;
      text-transform: uppercase;
    }
    h1 {
      margin: 16px 0 14px;
      color: #f8fafc;
      font-size: 74px;
      line-height: 1.02;
      letter-spacing: 0;
    }
    .summary {
      margin: 0;
      max-width: 1350px;
      color: #cbd5e1;
      font-size: 30px;
      line-height: 1.4;
    }
    .badges {
      display: flex;
      gap: 18px;
      margin-top: 34px;
      flex-wrap: wrap;
    }
    .badge {
      border: 1px solid #334155;
      border-radius: 14px;
      background: #0f172a;
      min-width: 255px;
      padding: 18px 22px;
    }
    .badge span {
      display: block;
      color: #94a3b8;
      font-size: 19px;
    }
    .badge b {
      display: block;
      margin-top: 6px;
      color: #f8fafc;
      font-size: 34px;
      line-height: 1;
    }
    .badge .bronze { color: #fdba74; }
    .badge .green { color: #bef264; }
    .levels {
      padding: 34px;
    }
    .panel h2 {
      margin: 0 0 24px;
      color: #f8fafc;
      font-size: 34px;
      letter-spacing: 0;
    }
    .level {
      display: flex;
      align-items: center;
      justify-content: space-between;
      border: 1px solid #334155;
      background: #0f172a;
      border-radius: 12px;
      padding: 19px 22px;
      margin-bottom: 14px;
    }
    .level span {
      font-size: 28px;
      font-weight: 760;
      color: #94a3b8;
    }
    .level small {
      color: #64748b;
      font-size: 18px;
    }
    .level.active {
      border-color: rgba(125, 211, 252, .5);
      background: rgba(14, 165, 233, .11);
    }
    .level.active span { color: #7dd3fc; }
    .level.current {
      border-color: rgba(253, 186, 116, .85);
      background: rgba(253, 186, 116, .15);
    }
    .level.current span { color: #fdba74; }
    .grid {
      display: grid;
      grid-template-columns: .92fr 1.08fr;
      gap: 34px;
      align-items: start;
    }
    .evidence-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 18px;
    }
    .panel-inner {
      padding: 34px;
    }
    .evidence-card {
      border: 1px solid #334155;
      border-radius: 14px;
      background: #0f172a;
      padding: 20px 22px;
      min-height: 152px;
    }
    .evidence-card h3 {
      margin: 0 0 10px;
      color: #c4b5fd;
      font-size: 24px;
      letter-spacing: 0;
    }
    .evidence-card p {
      margin: 0;
      color: #dbeafe;
      font-size: 20px;
      line-height: 1.36;
    }
    .check-row {
      display: grid;
      grid-template-columns: 96px 1fr;
      gap: 16px;
      padding: 15px 0;
      border-bottom: 1px solid rgba(51, 65, 85, .64);
    }
    .check-row:last-child { border-bottom: 0; }
    .status {
      display: inline-grid;
      place-items: center;
      height: 36px;
      border-radius: 10px;
      font-size: 16px;
      font-weight: 800;
      color: #0b1120;
      margin-top: 3px;
    }
    .ok { background: #bef264; }
    .warn { background: #fdba74; }
    .gap { background: #fb7185; }
    .info { background: #7dd3fc; }
    .check-row b {
      display: block;
      color: #f8fafc;
      font-size: 22px;
      line-height: 1.2;
    }
    .check-row p {
      margin: 6px 0;
      color: #cbd5e1;
      font-size: 19px;
      line-height: 1.32;
    }
    .check-row small {
      color: #94a3b8;
      font-size: 16px;
      line-height: 1.3;
    }
    .sla {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 14px;
      margin-top: 20px;
    }
    .sla-row {
      border: 1px solid #334155;
      border-radius: 12px;
      background: #0f172a;
      padding: 14px 16px;
    }
    .sla-row span {
      display: block;
      color: #94a3b8;
      font-size: 16px;
    }
    .sla-row b {
      display: block;
      color: #f8fafc;
      font-size: 19px;
      margin-top: 5px;
    }
    .hint {
      margin-top: 20px;
      border-left: 6px solid #fbbf24;
      padding: 16px 20px;
      color: #fef3c7;
      background: rgba(251, 191, 36, .10);
      border-radius: 8px;
      font-size: 22px;
      line-height: 1.35;
    }
    .brand {
      margin-top: 28px;
      text-align: right;
      color: #64748b;
      font-size: 22px;
    }
  </style>
</head>
<body>
  <main class="canvas">
    <section class="top">
      <div class="hero">
        <div class="kicker">Oracle MAA Readiness</div>
        <h1>CrashSimulator MAA Report</h1>
        <p class="summary">Read-only posture assessment that maps observable Oracle Database evidence to MAA levels and links HA/DR gaps to practical recovery drills.</p>
        <div class="badges">
          <div class="badge"><span>Detected posture</span><b class="bronze">${escapeHtml(detected)}</b></div>
          <div class="badge"><span>Readiness</span><b class="green">${escapeHtml(readiness)}</b></div>
          <div class="badge"><span>Application</span><b>${escapeHtml(report.meta["Application context"] || "not supplied")}</b></div>
        </div>
      </div>
      <aside class="panel levels">
        <h2>MAA Level Path</h2>
        ${levelCards}
      </aside>
    </section>
    <section class="grid">
      <div class="panel panel-inner">
        <h2>Evidence Summary</h2>
        <div class="evidence-grid">${evidenceCards}</div>
        <div class="hint">${escapeHtml(report.hint)}</div>
        <div class="sla">${slaRows}</div>
      </div>
      <div class="panel panel-inner">
        <h2>Best-Practice Checks</h2>
        ${checkRows}
      </div>
    </section>
    <div class="brand">Generated from ./CrashSimulatorV2.sh --maa-report</div>
  </main>
</body>
</html>`;

  const htmlPath = path.join(htmlDir, "maa_readiness_summary.html");
  fs.writeFileSync(htmlPath, html);
  return htmlPath;
}

async function renderMaaSummary(browser) {
  const htmlPath = writeMaaSummaryPage();
  const page = await browser.newPage({
    viewport: { width: 2400, height: 1800 },
    deviceScaleFactor: 1,
  });
  await page.goto(fileUrl(htmlPath), { waitUntil: "load" });
  await page.screenshot({
    path: path.join(outDir, "crashsim_maa_readiness_summary.png"),
    fullPage: true,
  });
  await page.close();
  console.log(path.join(outDir, "crashsim_maa_readiness_summary.png"));
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
        title: "Data Guard Recovery Dry-Run",
        subtitle: "CLI mode | DG/RAC/ASM scenario layer",
        prompt: "$ ./CrashSimulatorV2.sh --recover 67 --dry-run",
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
      {
        input: "captures/maa_guided_reports_menu.txt",
        html: "maa_guided_reports_menu.html",
        output: "crashsim_maa_guided_reports_menu.png",
        title: "MAA Readiness In Guided Workflow",
        subtitle: "Reports menu | MAA and SLA planning",
        prompt: "$ ./CrashSimulatorV2.sh --menu",
        height: 1700,
        lineLimit: 44,
      },
      {
        input: "captures/maa_cli_report.txt",
        html: "maa_cli_report.html",
        output: "crashsim_maa_cli_report.png",
        title: "MAA Readiness Report",
        subtitle: "CLI mode | RTO/RPO context",
        prompt: "",
        height: 1900,
        lineLimit: 52,
        wrap: 120,
      },
      {
        input: "captures/26ai/26ai_topology_latest.txt",
        html: "26ai_topology_latest.html",
        output: "crashsim_26ai_topology.png",
        title: "Oracle AI Database 26ai RAC/ASM",
        subtitle: "Validated lab | CDB, RAC, ASM, PDB",
        prompt: "$ ./CrashSimulatorV2.sh --discover --pdb CRASHDB_PDB1 --html",
        height: 1600,
        lineLimit: 36,
      },
      {
        input: "docs/reference/26ai/26ai_scenario_readiness_reference.md",
        html: "26ai_scenario_readiness.html",
        output: "crashsim_26ai_scenario_readiness.png",
        title: "26ai Scenario Readiness",
        subtitle: "44 runnable checks | 82-scenario registry",
        prompt: "$ ./CrashSimulatorV2.sh --scenario-readiness-report --pdb CRASHDB_PDB1 --html",
        height: 1900,
        lineLimit: 56,
        wrap: 120,
      },
      {
        input: "docs/reference/26ai/26ai_apex_ords_readiness_reference.md",
        html: "26ai_apex_ords_readiness.html",
        output: "crashsim_26ai_apex_ords_readiness.png",
        title: "APEX / ORDS Readiness",
        subtitle: "26ai lab | application access-path evidence",
        prompt: "$ ./CrashSimulatorV2.sh --apex-ords-report --pdb CRASHDB_PDB1 --html",
        height: 1900,
        lineLimit: 54,
        wrap: 120,
      },
      {
        input: "docs/reference/26ai/26ai_apex_session_continuity_s80_reference.md",
        html: "26ai_apex_session_continuity_s80.html",
        output: "crashsim_apex_session_continuity_s80.png",
        title: "Scenario 80 APEX Session Continuity",
        subtitle: "Read-only continuity evidence | ORDS and peer URL",
        prompt: "$ ./CrashSimulatorV2.sh --scenario 80 --pdb CRASHDB_PDB1 --execute --html",
        height: 1300,
        lineLimit: 34,
        wrap: 120,
      },
      {
        input: "docs/reference/apex_session_driver_example.md",
        html: "apex_session_driver_example.html",
        output: "crashsim_apex_session_driver_example.png",
        title: "APEX Browser Session Driver",
        subtitle: "Scenario 80 | screenshots, JSON, and Markdown evidence",
        prompt: "$ tools/crashsim_apex_session_driver.cjs --url <seeded-apex-url> --success-selector '#CRASHSIM_SESSION_OK'",
        height: 1500,
        lineLimit: 42,
        wrap: 118,
      },
      {
        input: "captures/config_review_workflow.txt",
        html: "config_review_workflow.html",
        output: "crashsim_config_review_workflow.png",
        title: "Configuration And Evidence Review",
        subtitle: "Guided menu | config, target selection, reports, logs",
        prompt: "$ ./CrashSimulatorV2.sh --menu",
        height: 1750,
        lineLimit: 48,
        wrap: 120,
      },
      {
        input: "captures/adb_readiness_report.txt",
        html: "adb_readiness_report.html",
        output: "crashsim_adb_readiness_report.png",
        title: "Autonomous Database Readiness",
        subtitle: "ADB report | wallet, SQL evidence, APEX, scenario coverage",
        prompt: "$ ./CrashSimulatorV2.sh --adb-readiness-report --html",
        height: 1700,
        lineLimit: 44,
        wrap: 118,
      },
      {
        input: "captures/adb_scenario_menu.txt",
        html: "adb_scenario_menu.html",
        output: "crashsim_adb_scenario_menu.png",
        title: "Autonomous Database Scenarios",
        subtitle: "Guided menu | ADB01-ADB15 readiness and scenario detail",
        prompt: "$ ./CrashSimulatorV2.sh --menu",
        height: 1650,
        lineLimit: 43,
        wrap: 118,
      },
      {
        input: "captures/best_practices_workflow.txt",
        html: "best_practices_workflow.html",
        output: "crashsim_best_practices_workflow.png",
        title: "CrashSimulator Best Practices",
        subtitle: "Operate every drill through readiness, protection, recovery, evidence",
        prompt: "",
        height: 1750,
        lineLimit: 48,
        wrap: 120,
      },
    ];

    for (const config of configs) {
      await render(config, browser);
      console.log(path.join(outDir, config.output));
    }
    await renderScenarioCatalog(browser);
    await renderMaaSummary(browser);
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
