#!/usr/bin/env bats
# Unit tests for menu_warn_sys_password_for_scenario (lib/80_menu.sh).
#
# Scenario 16 (password-file loss) recovers by recreating the file with orapwd,
# which needs the SYS password. The guard warns at scenario time (menu options
# 5/8, non-blocking) and fails early at execute-mode recovery (option 10)
# instead of letting the child die after the typed confirmation gates.
# Run: bats tests/bats/   (hermetic; no Oracle needed)

load test_helper

# shellcheck disable=SC1090,SC1091
source "$REPO_ROOT/lib/80_menu.sh"

setup() {
  SCENARIO_ID=16
  SYS_PASSWORD=""
  export SCENARIO_ID SYS_PASSWORD
}

@test "helper: scenario 16 needs the SYS password for recovery" {
  run menu_scenario_recovery_needs_sys_password 16
  [ "$status" -eq 0 ]
}

@test "helper: other scenarios do not" {
  run menu_scenario_recovery_needs_sys_password 1
  [ "$status" -eq 1 ]
  run menu_scenario_recovery_needs_sys_password 26
  [ "$status" -eq 1 ]
}

@test "scenario action (options 5/8) warns but does not block when password unset" {
  run menu_warn_sys_password_for_scenario "scenario" "dry-run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SYS password"* ]]
  [[ "$output" == *"option 12"* ]]
  run menu_warn_sys_password_for_scenario "scenario" "execute"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SYS password"* ]]
}

@test "scenario action is silent when the password is set" {
  SYS_PASSWORD="secret"
  run menu_warn_sys_password_for_scenario "scenario" "execute"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "execute-mode recovery (option 10) fails early with the fix when password unset" {
  run menu_warn_sys_password_for_scenario "recover" "execute"
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires the SYS password"* ]]
  [[ "$output" == *"option 12"* ]]
}

@test "dry-run recovery (option 9) is not blocked" {
  run menu_warn_sys_password_for_scenario "recover" "dry-run"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "execute-mode recovery passes silently when the password is set" {
  SYS_PASSWORD="secret"
  run menu_warn_sys_password_for_scenario "recover" "execute"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "guard is silent for scenarios that do not need the password" {
  SCENARIO_ID=1
  run menu_warn_sys_password_for_scenario "scenario" "execute"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run menu_warn_sys_password_for_scenario "recover" "execute"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "guard is a no-op when no scenario is selected" {
  SCENARIO_ID=""
  run menu_warn_sys_password_for_scenario "scenario" "execute"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
