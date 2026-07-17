# CrashSimulator Private Labs Workflow

This guide explains how to work privately on CrashSimulator improvements while
keeping the public community repository clean, intentional, and safe.

## Recommended Repository Model

Use separate repositories instead of private branches inside the public
repository.

| Repository | Visibility | Purpose |
| --- | --- | --- |
| `fmunozalvarez/crashsimulator` | Public | Stable community code, sanitized docs, public releases, community issues, and public pull requests. |
| `fmunozalvarez/crashsimulator-labs` | Private | Experimental community features, prototypes, private validation, roadmap work, and pre-release evidence review. |
| `fmunozalvarez/crashsimulator-enterprise` | Private future option | Enterprise-only controller, dashboards, agents, commercial packaging, connectors, and license-sensitive integrations. |

Do not create `crashsimulator-labs` as a fork. Create it as a normal private
repository so private work, branches, Actions output, and future enterprise
work are clearly separated from the public community repository.

## Laptop Layout

Recommended local folders:

```text
/Users/franciscomunozalvarez/Downloads/Crashsimulator/source
/Users/franciscomunozalvarez/Downloads/CrashSimulator_Labs/source
/Users/franciscomunozalvarez/Downloads/CrashSimulator_Enterprise/source
```

The current laptop setup uses:

```text
/Users/franciscomunozalvarez/Downloads/Crashsimulator/source
  origin -> public crashsimulator

/Users/franciscomunozalvarez/Downloads/CrashSimulator_Labs/source
  origin    -> private crashsimulator-labs
  community -> public crashsimulator fetch-only, push disabled
```

## Create The Private GitHub Repository

On GitHub:

1. Create a new repository.
2. Owner: `fmunozalvarez`.
3. Repository name: `crashsimulator-labs`.
4. Visibility: `Private`.
5. Do not initialize with README, `.gitignore`, or license.
6. Use this description:

```text
Private R&D repository for CrashSimulator experimental community features, future roadmap, prototypes, and pre-release validation.
```

## Create The Local Labs Working Copy

Clone public CrashSimulator into a separate Labs folder:

```bash
mkdir -p /Users/franciscomunozalvarez/Downloads/CrashSimulator_Labs
git clone https://github.com/fmunozalvarez/crashsimulator.git \
  /Users/franciscomunozalvarez/Downloads/CrashSimulator_Labs/source
cd /Users/franciscomunozalvarez/Downloads/CrashSimulator_Labs/source
```

Rename the public remote to `community`:

```bash
git remote rename origin community
```

Disable accidental pushes to the public repository from the Labs checkout:

```bash
git remote set-url --push community DISABLED
```

Add the private Labs repository as `origin`:

```bash
git remote add origin https://github.com/fmunozalvarez/crashsimulator-labs.git
```

Verify:

```bash
git remote -v
```

Expected result:

```text
community  https://github.com/fmunozalvarez/crashsimulator.git (fetch)
community  DISABLED (push)
origin     https://github.com/fmunozalvarez/crashsimulator-labs.git (fetch)
origin     https://github.com/fmunozalvarez/crashsimulator-labs.git (push)
```

Seed the private repository:

```bash
git switch main
git push -u origin main
git push origin --tags
```

## Branch Strategy

Use simple branch names.

| Branch pattern | Location | Purpose |
| --- | --- | --- |
| `main` | Private Labs | Mirror public `main` unless private baseline changes are intentional. |
| `labs/<feature-name>` | Private Labs | Experimental work and prototypes. |
| `publish/<feature-name>` | Local only | Clean staging branch used to prepare selected public contributions. |
| `feature/<feature-name>` | Public repo only | Public pull-request branch after private work is cleaned. |

Examples:

```text
labs/adb-oci-control-plane
labs/dbsat-import-engine
labs/maa-sla-advisor
labs/apex-session-driver-v2
labs/patch-gap-assessment

publish/maa-report-improvements
publish/adb-readiness-docs
publish/service-ha-review
```

Do not push `labs/*` branches to the public repository.

## Daily Private Development Workflow

Start from current public code:

```bash
cd /Users/franciscomunozalvarez/Downloads/CrashSimulator_Labs/source
git switch main
git fetch community
git merge --ff-only community/main
git push origin main
```

Create a private feature branch:

```bash
git switch -c labs/dbsat-import-engine
```

Work normally:

```bash
git status
git add .
git commit -m "Prototype DBSAT report import engine"
git push -u origin labs/dbsat-import-engine
```

## Keep Labs Updated With Public Changes

When public `crashsimulator` changes:

```bash
cd /Users/franciscomunozalvarez/Downloads/CrashSimulator_Labs/source
git switch main
git fetch community
git merge --ff-only community/main
git push origin main
```

Then update private branches:

```bash
git switch labs/dbsat-import-engine
git rebase main
git push --force-with-lease
```

Use `--force-with-lease`, not plain `--force`.

## Publish Selected Private Work To Public

Never push a private Labs branch directly to public. Create a clean public
candidate branch from public `main`:

```bash
cd /Users/franciscomunozalvarez/Downloads/CrashSimulator_Labs/source
git fetch community
git switch -c publish/dbsat-docs community/main
```

Cherry-pick only safe commits:

```bash
git cherry-pick <commit_sha_1>
git cherry-pick <commit_sha_2>
```

Or squash a private branch into a clean public commit:

```bash
git merge --squash labs/dbsat-import-engine
git commit -m "Add DBSAT import documentation and sanitized parser foundation"
```

Review exactly what would go public:

```bash
git diff --stat community/main..HEAD
git diff community/main..HEAD
git log --oneline community/main..HEAD
```

Run a basic secret check:

```bash
git grep -nE "password|secret|token|BEGIN PRIVATE KEY|wallet|ocid1|credential" -- .
```

Push intentionally to the public repository using an explicit URL:

```bash
git push https://github.com/fmunozalvarez/crashsimulator.git \
  HEAD:feature/dbsat-import-foundation
```

Open a public pull request:

```text
feature/dbsat-import-foundation -> main
```

After the pull request is merged, sync Labs:

```bash
git switch main
git fetch community
git merge --ff-only community/main
git push origin main
```

## What Goes Where

Public `crashsimulator`:

- Stable community features.
- Open-source scenario engine.
- Documentation and sanitized examples.
- Community issues and releases.
- Reference screenshots.
- Safe sample reports.
- Apache 2.0 code.

Private `crashsimulator-labs`:

- Experimental features.
- Roadmap prototypes.
- Unfinished MAA scoring and SLA advisor work.
- DBSAT import experiments.
- CVE/patch-gap analysis prototypes.
- ADB OCI control-plane helpers.
- APEX/ORDS experiments.
- AI/MCP research.
- Private design notes.
- Unreleased screenshots.

Future private `crashsimulator-enterprise`:

- Central controller.
- Agents.
- Web UI.
- Enterprise dashboards.
- Multi-target repository.
- AI advisor.
- Customer connectors.
- Commercial packaging.
- License enforcement.
- Enterprise-only integrations.

## Files That Must Not Be Committed

Do not commit real:

- ADB wallets.
- TDE wallets or keystores.
- DBSAT customer reports.
- RMAN catalog credentials.
- OCI API keys.
- Private SSH keys.
- Customer topology reports.
- Real audit evidence.
- Real CrashSimulator logs, manifests, and recovery transcripts.
- Customer screenshots or hostnames unless sanitized.

Keep only sanitized examples in the public repository.

## Commands To Avoid From Labs

Never run these from the Labs checkout:

```bash
git push --all community
git push --mirror community
git push community --tags
git push community labs/*
```

Those commands can expose private branches, internal tags, or experimental
work. The `community` push URL is intentionally set to `DISABLED` in the Labs
checkout so accidental public pushes fail.

## Recommended Public Release Process

For community releases:

1. Develop privately in Labs.
2. Publish selected changes to a public feature branch.
3. Merge through a public pull request.
4. Tag from public `main`.
5. Build the community runtime ZIP from public `main`.
6. Attach release assets to the public GitHub release.

Example:

```bash
git switch main
git fetch community
git merge --ff-only community/main

git tag -a v2.0.2-beta -m "CrashSimulator v2.0.2 beta"
git push https://github.com/fmunozalvarez/crashsimulator.git v2.0.2-beta
```

Build public releases from public repository state, not from Labs, unless the
release is explicitly private.

## Operating Rules

1. Labs can be messy; public cannot.
2. Labs branches never go directly public.
3. Public changes are cherry-picked or squash-merged.
4. Real wallets, DBSAT reports, audit evidence, logs, and customer data never
   go public.
5. Public releases are built only from public `main` or public release
   branches.
6. Labs `main` mirrors public `main` unless a private baseline change is
   intentional.
7. Enterprise-only code belongs in `crashsimulator-enterprise`, not public
   `crashsimulator`.

## Codex / AI-Assisted Development

Use Codex against the private Labs checkout for experiments:

```text
public issue -> private Labs prototype -> clean publish branch -> public PR
```

This gives the project private experimentation, controlled public release, no
unfinished roadmap exposure, and lower risk of leaking customer or
enterprise-only material.
