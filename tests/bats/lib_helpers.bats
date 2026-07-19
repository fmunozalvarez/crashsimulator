#!/usr/bin/env bats
# Unit tests for the pure helper functions in lib/*.sh.
# Run: bats tests/bats/   (hermetic; no Oracle needed)

load test_helper

# --- format_seconds --------------------------------------------------------
@test "format_seconds renders days/hours/mins/secs" {
  run format_seconds 90061
  [ "$status" -eq 0 ]
  [ "$output" = "1d 1h 1m 1s" ]
}

@test "format_seconds drops leading zero units" {
  run format_seconds 61
  [ "$output" = "1m 1s" ]
}

@test "format_seconds shows bare seconds under a minute" {
  run format_seconds 5
  [ "$output" = "5s" ]
}

@test "format_seconds passes non-numeric input through unchanged" {
  run format_seconds "n/a"
  [ "$output" = "n/a" ]
}

# --- duration_to_seconds ---------------------------------------------------
@test "duration_to_seconds converts hours" {
  run duration_to_seconds "2 hours"
  [ "$status" -eq 0 ]
  [ "$output" = "7200" ]
}

@test "duration_to_seconds converts minutes and days" {
  run duration_to_seconds "30 min"; [ "$output" = "1800" ]
  run duration_to_seconds "1 day"; [ "$output" = "86400" ]
}

@test "duration_to_seconds treats zero/near-zero as 0" {
  run duration_to_seconds "zero"; [ "$output" = "0" ]
  run duration_to_seconds "near zero"; [ "$output" = "0" ]
}

@test "duration_to_seconds fails on empty input" {
  run duration_to_seconds ""
  [ "$status" -ne 0 ]
}

# --- normalize_bool / normalize_auto_bool ----------------------------------
@test "normalize_bool maps truthy and falsy words" {
  run normalize_bool "YES"; [ "$output" = "1" ]
  run normalize_bool "on";  [ "$output" = "1" ]
  run normalize_bool "off"; [ "$output" = "0" ]
  run normalize_bool "";    [ "$output" = "0" ]
}

@test "normalize_bool rejects garbage" {
  run normalize_bool "maybe"
  [ "$status" -ne 0 ]
}

@test "normalize_auto_bool preserves auto and empty as auto" {
  run normalize_auto_bool "auto"; [ "$output" = "auto" ]
  run normalize_auto_bool "";     [ "$output" = "auto" ]
  run normalize_auto_bool "no";   [ "$output" = "0" ]
}

# --- normalize_name / validate_oracle_name / validate_tempfile_size --------
@test "normalize_name uppercases" {
  run normalize_name "crashone_db"
  [ "$output" = "CRASHONE_DB" ]
}

@test "validate_oracle_name accepts valid identifiers, rejects bad ones" {
  run validate_oracle_name "CRASH_DB1"; [ "$status" -eq 0 ]
  run validate_oracle_name "1bad";      [ "$status" -ne 0 ]
  run validate_oracle_name "has space"; [ "$status" -ne 0 ]
}

@test "validate_tempfile_size accepts size units, rejects junk" {
  run validate_tempfile_size "512M"; [ "$status" -eq 0 ]
  run validate_tempfile_size "100";  [ "$status" -eq 0 ]
  run validate_tempfile_size "big";  [ "$status" -ne 0 ]
}

# --- redact_config_value ---------------------------------------------------
@test "redact_config_value redacts sensitive keys with a value" {
  run redact_config_value "DB_PASSWORD" "s3cret"
  [ "$output" = "<redacted>" ]
}

@test "redact_config_value shows 'not set' for an empty sensitive value" {
  run redact_config_value "RMAN_CATALOG" ""
  [ "$output" = "not set" ]
}

@test "redact_config_value passes non-sensitive values through" {
  run redact_config_value "ORACLE_SID" "CRASH1"
  [ "$output" = "CRASH1" ]
}

# --- maa_tier_rank / maa_duration_le ---------------------------------------
@test "maa_tier_rank ranks known tiers and defaults unknown to 0" {
  run maa_tier_rank "Gold";    [ "$output" = "3" ]
  run maa_tier_rank "Diamond"; [ "$output" = "5" ]
  run maa_tier_rank "Mystery"; [ "$output" = "0" ]
}

@test "maa_duration_le compares a duration against a threshold" {
  run maa_duration_le "1 min" 3600;  [ "$status" -eq 0 ]
  run maa_duration_le "2 hours" 3600; [ "$status" -ne 0 ]
}
