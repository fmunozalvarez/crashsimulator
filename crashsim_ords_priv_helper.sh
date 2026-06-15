#!/usr/bin/env bash
#
# Restricted ORDS helper for CrashSimulator lab drills.
#
# Install as root-owned /usr/local/bin/crashsim_ords_priv and grant only this
# helper through sudoers to the Oracle software owner. The helper intentionally
# permits only ORDS service control and reversible ORDS config rename flows for
# the standard OS package path and the CrashSimulator lab install path.

set -euo pipefail

SYSTEMCTL="/usr/bin/systemctl"
[[ -x "$SYSTEMCTL" ]] || SYSTEMCTL="/bin/systemctl"
MV="/bin/mv"
[[ -x "$MV" ]] || MV="/usr/bin/mv"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

validate_service_name() {
  local service="$1"
  [[ "$service" =~ ^[A-Za-z0-9_.@-]+$ ]] || die "Invalid service name: $service"
}

validate_config_original() {
  local path="$1"
  case "$path" in
    /etc/ords/config|/u01/app/oracle/product/crashsim_apex_ords/ords_config)
      ;;
    *)
      die "Only approved ORDS config paths are allowed"
      ;;
  esac
}

validate_config_backup() {
  local path="$1"
  [[ "$path" =~ ^/etc/ords/config\.[0-9]{8}_[0-9]{6}\.crashsim\.bak$ || "$path" =~ ^/u01/app/oracle/product/crashsim_apex_ords/ords_config\.[0-9]{8}_[0-9]{6}\.crashsim\.bak$ ]] ||
    die "Backup path is not an approved CrashSimulator ORDS config backup: $path"
}

cmd="${1:-}"
shift || true

case "$cmd" in
  service)
    action="${1:-}"
    service="${2:-}"
    [[ -n "$action" && -n "$service" ]] || die "Usage: service <start|stop|restart|status|is-active> <service>"
    validate_service_name "$service"
    case "$action" in
      start|stop|restart|status|is-active)
        exec "$SYSTEMCTL" "$action" "$service"
        ;;
      *)
        die "Unsupported service action: $action"
        ;;
    esac
    ;;
  config-check)
    original="${1:-}"
    validate_config_original "$original"
    [[ -d "$original" ]] || die "ORDS config directory not found: $original"
    ;;
  config-rename)
    original="${1:-}"
    backup="${2:-}"
    validate_config_original "$original"
    validate_config_backup "$backup"
    [[ -d "$original" ]] || die "ORDS config directory not found: $original"
    [[ ! -e "$backup" ]] || die "Backup path already exists: $backup"
    exec "$MV" -- "$original" "$backup"
    ;;
  config-restore)
    backup="${1:-}"
    original="${2:-}"
    validate_config_backup "$backup"
    validate_config_original "$original"
    [[ -d "$backup" ]] || die "ORDS config backup not found: $backup"
    [[ ! -e "$original" ]] || die "Original path already exists: $original"
    exec "$MV" -- "$backup" "$original"
    ;;
  *)
    die "Usage: $0 service|config-check|config-rename|config-restore ..."
    ;;
esac
