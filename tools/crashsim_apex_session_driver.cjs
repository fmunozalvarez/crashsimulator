#!/usr/bin/env node
/*
 * CrashSimulator seeded APEX browser-session driver.
 *
 * Optional scenario 80 helper. It requires Playwright to be installed on the
 * host where the driver runs. The APEX test password is read from
 * CRASHSIM_APEX_SESSION_PASSWORD so it does not have to appear in process args.
 */

const fs = require("fs");
const path = require("path");

function usage() {
  console.error(`Usage:
  crashsim_apex_session_driver.cjs --url <apex-url> --output-dir <dir> [options]

Options:
  --username <user>                 Optional APEX test user.
  --success-selector <css>          Selector that proves the seeded app is open.
  --username-selector <css>         Login username selector override.
  --password-selector <css>         Login password selector override.
  --submit-selector <css>           Login submit selector override.
  --duration <sec>                  Polling duration. Default: 90.
  --interval <sec>                  Polling interval. Default: 10.
  --headless <true|false>           Browser headless mode. Default: true.
  --label <text>                    Evidence label. Default: apex-session.

Environment:
  CRASHSIM_APEX_SESSION_PASSWORD    Optional APEX test password.
`);
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith("--")) {
      throw new Error(`Unexpected argument: ${arg}`);
    }
    const key = arg.slice(2);
    if (key === "self-check") {
      args[key] = "1";
      continue;
    }
    const next = argv[i + 1];
    if (next === undefined || next.startsWith("--")) {
      throw new Error(`Missing value for ${arg}`);
    }
    args[key] = next;
    i += 1;
  }
  return args;
}

function parseBool(value, fallback) {
  if (value === undefined || value === "") return fallback;
  const normalized = String(value).toLowerCase();
  if (["1", "true", "yes", "y", "on"].includes(normalized)) return true;
  if (["0", "false", "no", "n", "off"].includes(normalized)) return false;
  throw new Error(`Invalid boolean value: ${value}`);
}

function parsePositiveInt(value, fallback, label) {
  if (value === undefined || value === "") return fallback;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${label} must be a positive integer: ${value}`);
  }
  return parsed;
}

function mdEscape(value) {
  return String(value ?? "").replace(/\\/g, "\\\\").replace(/`/g, "\\`");
}

function nowIso() {
  return new Date().toISOString();
}

async function firstVisible(page, selectors, timeoutMs = 1000) {
  for (const selector of selectors.filter(Boolean)) {
    const locator = page.locator(selector).first();
    try {
      await locator.waitFor({ state: "visible", timeout: timeoutMs });
      return selector;
    } catch {
      // Try the next selector.
    }
  }
  return null;
}

async function isVisible(page, selector, timeoutMs = 750) {
  if (!selector) return false;
  try {
    await page.locator(selector).first().waitFor({ state: "visible", timeout: timeoutMs });
    return true;
  } catch {
    return false;
  }
}

async function checkSession(page, options, label) {
  const check = {
    label,
    checkedAtUTC: nowIso(),
    url: page.url(),
    title: "",
    status: "OK",
    messages: [],
  };

  try {
    check.title = await page.title();
  } catch (error) {
    check.status = "FAIL";
    check.messages.push(`Could not read page title: ${error.message}`);
  }

  const passwordVisible = await isVisible(page, "input[type='password']");
  if (options.username && passwordVisible) {
    check.status = "FAIL";
    check.messages.push("Password field is visible after login; session likely returned to login page.");
  }

  if (options.successSelector) {
    const successVisible = await isVisible(page, options.successSelector, 2500);
    if (!successVisible) {
      check.status = "FAIL";
      check.messages.push(`Success selector was not visible: ${options.successSelector}`);
    }
  }

  return check;
}

async function safeScreenshot(page, file) {
  try {
    await page.screenshot({ path: file, fullPage: true });
    return file;
  } catch {
    return null;
  }
}

function writeReport(result, reportFile) {
  const lines = [];
  lines.push("# CrashSimulator APEX Browser Session Driver Evidence");
  lines.push("");
  lines.push(`- Generated UTC: \`${nowIso()}\``);
  lines.push(`- Label: \`${mdEscape(result.label)}\``);
  lines.push(`- Start URL: \`${mdEscape(result.startUrl)}\``);
  lines.push(`- Final URL: \`${mdEscape(result.finalUrl || "")}\``);
  lines.push(`- Username supplied: \`${result.usernameSupplied ? "yes" : "no"}\``);
  lines.push(`- Success selector: \`${mdEscape(result.successSelector || "not supplied")}\``);
  lines.push(`- Duration seconds: \`${result.durationSeconds}\``);
  lines.push(`- Interval seconds: \`${result.intervalSeconds}\``);
  lines.push(`- Status: \`${result.status}\``);
  lines.push("");
  lines.push("## Screenshots");
  lines.push("");
  for (const [name, file] of Object.entries(result.screenshots)) {
    if (file) lines.push(`- ${name}: \`${mdEscape(file)}\``);
  }
  lines.push("");
  lines.push("## Checks");
  lines.push("");
  lines.push("| Check | Status | URL | Title | Messages |");
  lines.push("| --- | --- | --- | --- | --- |");
  for (const check of result.checks) {
    lines.push(
      `| ${mdEscape(check.label)} | ${mdEscape(check.status)} | ${mdEscape(check.url)} | ${mdEscape(check.title)} | ${mdEscape(check.messages.join("; ") || "OK")} |`,
    );
  }
  if (result.warnings.length > 0) {
    lines.push("");
    lines.push("## Warnings");
    lines.push("");
    for (const warning of result.warnings) {
      lines.push(`- ${warning}`);
    }
  }
  fs.writeFileSync(reportFile, `${lines.join("\n")}\n`);
}

async function main() {
  let chromium;
  try {
    ({ chromium } = require("playwright"));
  } catch (error) {
    throw new Error("Playwright is not available. Install it on the driver host or run scenario 80 without --apex-session-driver.");
  }

  const args = parseArgs(process.argv.slice(2));
  if (args["self-check"]) {
    const executablePath = chromium.executablePath();
    const result = {
      status: fs.existsSync(executablePath) ? "OK" : "FAIL",
      playwright: "available",
      chromiumExecutable: executablePath,
      completedAtUTC: nowIso(),
    };
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    process.exit(result.status === "OK" ? 0 : 1);
  }

  if (!args.url || !args["output-dir"]) {
    usage();
    process.exit(2);
  }

  const outputDir = path.resolve(args["output-dir"]);
  fs.mkdirSync(outputDir, { recursive: true });

  const options = {
    url: args.url,
    username: args.username || "",
    password: process.env.CRASHSIM_APEX_SESSION_PASSWORD || "",
    successSelector: args["success-selector"] || "",
    usernameSelector: args["username-selector"] || "",
    passwordSelector: args["password-selector"] || "",
    submitSelector: args["submit-selector"] || "",
    durationSeconds: parsePositiveInt(args.duration, 90, "duration"),
    intervalSeconds: parsePositiveInt(args.interval, 10, "interval"),
    headless: parseBool(args.headless, true),
    label: args.label || "apex-session",
  };

  if (options.username && !options.password) {
    throw new Error("A username was supplied but CRASHSIM_APEX_SESSION_PASSWORD is empty.");
  }

  const result = {
    label: options.label,
    startUrl: options.url,
    finalUrl: "",
    usernameSupplied: Boolean(options.username),
    successSelector: options.successSelector,
    durationSeconds: options.durationSeconds,
    intervalSeconds: options.intervalSeconds,
    status: "PASS",
    startedAtUTC: nowIso(),
    completedAtUTC: "",
    checks: [],
    warnings: [],
    screenshots: {},
    artifacts: {
      report: path.join(outputDir, "apex_session_driver_report.md"),
      json: path.join(outputDir, "apex_session_driver_result.json"),
    },
  };

  if (!options.username && !options.successSelector) {
    result.status = "WARN";
    result.warnings.push("No username or success selector was supplied; driver can prove URL continuity but not authenticated APEX session continuity.");
  }

  const browser = await chromium.launch({ headless: options.headless });
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    viewport: { width: 1440, height: 1000 },
  });
  const page = await context.newPage();

  page.on("pageerror", (error) => {
    result.warnings.push(`Browser page error: ${error.message}`);
  });
  page.on("console", (message) => {
    if (["error", "warning"].includes(message.type())) {
      result.warnings.push(`Browser console ${message.type()}: ${message.text()}`);
    }
  });

  try {
    await page.goto(options.url, { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForLoadState("networkidle", { timeout: 10000 }).catch(() => {});

    if (options.username) {
      const userSelector = await firstVisible(page, [
        options.usernameSelector,
        "input[name*='USERNAME' i]",
        "input[id*='USERNAME' i]",
        "input[type='email']",
        "input[type='text']",
      ]);
      const passwordSelector = await firstVisible(page, [
        options.passwordSelector,
        "input[type='password']",
        "input[name*='PASSWORD' i]",
        "input[id*='PASSWORD' i]",
      ]);
      if (!userSelector || !passwordSelector) {
        throw new Error("Could not find visible APEX login username/password fields.");
      }
      await page.locator(userSelector).first().fill(options.username);
      await page.locator(passwordSelector).first().fill(options.password);

      const submitSelector = await firstVisible(page, [
        options.submitSelector,
        "button[type='submit']",
        "input[type='submit']",
        "button:has-text('Sign In')",
        "button:has-text('Log In')",
        "button:has-text('Login')",
      ]);
      if (submitSelector) {
        await Promise.all([
          page.waitForLoadState("domcontentloaded", { timeout: 15000 }).catch(() => {}),
          page.locator(submitSelector).first().click(),
        ]);
      } else {
        await page.locator(passwordSelector).first().press("Enter");
        await page.waitForLoadState("domcontentloaded", { timeout: 15000 }).catch(() => {});
      }
      await page.waitForLoadState("networkidle", { timeout: 10000 }).catch(() => {});
    }

    result.screenshots.baseline = await safeScreenshot(page, path.join(outputDir, "baseline.png"));
    result.checks.push(await checkSession(page, options, "baseline"));

    const deadline = Date.now() + options.durationSeconds * 1000;
    let iteration = 0;
    while (Date.now() < deadline) {
      iteration += 1;
      await page.waitForTimeout(options.intervalSeconds * 1000);
      try {
        await page.reload({ waitUntil: "domcontentloaded", timeout: 30000 });
        await page.waitForLoadState("networkidle", { timeout: 10000 }).catch(() => {});
        result.checks.push(await checkSession(page, options, `poll-${iteration}`));
      } catch (error) {
        const failureShot = await safeScreenshot(page, path.join(outputDir, `poll-${iteration}-failure.png`));
        result.checks.push({
          label: `poll-${iteration}`,
          checkedAtUTC: nowIso(),
          url: page.url(),
          title: "",
          status: "FAIL",
          messages: [`Reload/check failed: ${error.message}`, failureShot ? `screenshot=${failureShot}` : ""].filter(Boolean),
        });
      }
    }

    result.screenshots.final = await safeScreenshot(page, path.join(outputDir, "final.png"));
    result.finalUrl = page.url();
  } finally {
    await context.close().catch(() => {});
    await browser.close().catch(() => {});
  }

  if (result.checks.some((check) => check.status === "FAIL")) {
    result.status = "FAIL";
  }
  result.completedAtUTC = nowIso();
  writeReport(result, result.artifacts.report);
  fs.writeFileSync(result.artifacts.json, `${JSON.stringify(result, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);

  if (result.status === "FAIL") {
    process.exit(1);
  }
}

main().catch((error) => {
  const failure = {
    status: "FAIL",
    error: error.message,
    completedAtUTC: nowIso(),
  };
  process.stdout.write(`${JSON.stringify(failure, null, 2)}\n`);
  process.exit(1);
});
