#!/usr/bin/env bats
# Unit tests for parse_listener_endpoint_from_address / discover_listener_endpoint
# (lib/16_topology.sh). Remote SYSDBA validation used to hardcode
# localhost:1521 and failed ORA-12541 on labs with non-default listeners
# (field-tested 2026-07-18: listener on testone:1522); the endpoint now comes
# from the database's local_listener, with an env override and a default.
# Run: bats tests/bats/   (hermetic; no Oracle needed)

load test_helper

# shellcheck disable=SC1090,SC1091
source "$REPO_ROOT/lib/16_topology.sh"

@test "parses a standard local_listener ADDRESS" {
  run parse_listener_endpoint_from_address "(ADDRESS=(PROTOCOL=TCP)(HOST=testone)(PORT=1522))"
  [ "$status" -eq 0 ]
  [ "$output" = "testone:1522" ]
}

@test "parses spacing and lowercase keywords" {
  run parse_listener_endpoint_from_address "(address = (protocol = tcp)(host = db01.example.com)(port = 1526))"
  [ "$status" -eq 0 ]
  [ "$output" = "db01.example.com:1526" ]
}

@test "parses an IP-address host" {
  run parse_listener_endpoint_from_address "(ADDRESS=(PROTOCOL=TCP)(HOST=10.0.0.5)(PORT=1521))"
  [ "$output" = "10.0.0.5:1521" ]
}

@test "fails on a TNS alias value (no ADDRESS to parse)" {
  run parse_listener_endpoint_from_address "LISTENER_TESTDBONE"
  [ "$status" -eq 1 ]
}

@test "fails on empty input" {
  run parse_listener_endpoint_from_address ""
  [ "$status" -eq 1 ]
}

@test "fails when the port is missing" {
  run parse_listener_endpoint_from_address "(ADDRESS=(PROTOCOL=IPC)(KEY=EXTPROC)(HOST=box))"
  [ "$status" -eq 1 ]
}

@test "discover_listener_endpoint honors the CRASHSIM_LISTENER_ENDPOINT override" {
  CRASHSIM_LISTENER_ENDPOINT="standby-a:1600"
  run discover_listener_endpoint
  [ "$status" -eq 0 ]
  [ "$output" = "standby-a:1600" ]
  unset CRASHSIM_LISTENER_ENDPOINT
}
