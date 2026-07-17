#!/usr/bin/env bats
# Unit tests for menu_recovery_manifest_is_recoverable (lib/80_menu.sh).
#
# A dry-run scenario records no restore point, so recovery against that manifest
# can only fail ("Manifest is missing ... restore paths"). The guided menu used
# to surface that as a bare "Command exited with status 1"; the guard catches it
# up front. These tests pin both the trip and the no-false-positive cases.
# Run: bats tests/bats/   (hermetic; no Oracle needed)

load test_helper

# 14_audit.sh (manifest_get) and 80_menu.sh are declaration-only (verified: no
# top-level code), so sourcing them just defines the functions under test.
# shellcheck disable=SC1090,SC1091
source "$REPO_ROOT/lib/14_audit.sh"
# shellcheck disable=SC1090,SC1091
source "$REPO_ROOT/lib/80_menu.sh"

setup() {
  MANIFEST_TMP="$(mktemp -d)"
  MANIFEST_FILE="${MANIFEST_TMP}/scenario.manifest"
  SCENARIO_ID=1
  export MANIFEST_FILE SCENARIO_ID
}

teardown() {
  rm -rf "$MANIFEST_TMP"
}

write_dry_run_scenario_manifest() {
  cat >"$MANIFEST_FILE" <<'EOF'
version=2.0.3-test
run_id=20260717_050441
mode=scenario
scenario_id=1
scenario_title=Loss of one control file
planned_action_count=1
action_1_kind=fs_rename
action_1_target=/u02/fra/TESTDBON/control02.ctl
action_1_detail=
scenario_completed_at_utc=2026-07-17T05:05:05Z
EOF
}

write_executed_scenario_manifest() {
  cat >"$MANIFEST_FILE" <<'EOF'
version=2.0.3-test
run_id=20260717_050655
mode=scenario
scenario_id=1
scenario_title=Loss of one control file
planned_action_count=1
action_1_kind=fs_rename
action_1_target=/u02/fra/TESTDBON/control02.ctl
action_1_detail=
rename_1_original=/u02/fra/TESTDBON/control02.ctl
rename_1_backup=/u02/fra/TESTDBON/control02.ctl.20260717_050655.crashsim.bak
rename_1_method=rename
scenario_completed_at_utc=2026-07-17T05:07:43Z
EOF
}

@test "guard trips on a dry-run scenario manifest (fs_rename plan, no restore point)" {
  write_dry_run_scenario_manifest
  run menu_recovery_manifest_is_recoverable
  [ "$status" -eq 1 ]
}

@test "guard explains the cause and points at Execute selected scenario" {
  write_dry_run_scenario_manifest
  run menu_recovery_manifest_is_recoverable
  [[ "$output" == *"dry-run scenario preview"* ]]
  [[ "$output" == *"option 8"* ]]
}

@test "guard allows an executed scenario manifest (restore pair present)" {
  write_executed_scenario_manifest
  run menu_recovery_manifest_is_recoverable
  [ "$status" -eq 0 ]
}

@test "guard allows a manifest whose restore pair has only the original recorded" {
  # load_manifest_restore_pairs treats this as an incomplete pair and reports its
  # own precise error; the menu guard must not pre-empt that with the dry-run text.
  write_dry_run_scenario_manifest
  printf 'rename_1_original=/u02/fra/TESTDBON/control02.ctl\n' >>"$MANIFEST_FILE"
  run menu_recovery_manifest_is_recoverable
  [ "$status" -eq 0 ]
}

@test "guard ignores scenarios that do not recover by rename+backup" {
  cat >"$MANIFEST_FILE" <<'EOF'
mode=scenario
scenario_id=31
scenario_title=ASM disk group loss
planned_action_count=1
action_1_kind=asm_rm
action_1_target=+DATA/CRASHPDB/DATAFILE/scratch.dbf
EOF
  run menu_recovery_manifest_is_recoverable
  [ "$status" -eq 0 ]
}

@test "guard ignores a non-scenario manifest" {
  cat >"$MANIFEST_FILE" <<'EOF'
mode=protect
action_1_kind=fs_rename
action_1_target=/u02/fra/TESTDBON/control02.ctl
EOF
  run menu_recovery_manifest_is_recoverable
  [ "$status" -eq 0 ]
}

@test "guard is a no-op when no manifest is selected" {
  MANIFEST_FILE=""
  run menu_recovery_manifest_is_recoverable
  [ "$status" -eq 0 ]
}

@test "guard is a no-op when the manifest path does not exist" {
  MANIFEST_FILE="${MANIFEST_TMP}/absent.manifest"
  run menu_recovery_manifest_is_recoverable
  [ "$status" -eq 0 ]
}
