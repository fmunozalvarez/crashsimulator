maa_value() {
  local key="$1"
  local default_value="${2:-UNKNOWN}"
  local value="${MAA_EVIDENCE[$key]:-}"
  if [[ -n "$value" ]]; then
    printf "%s" "$value"
  else
    printf "%s" "$default_value"
  fi
}

maa_positive() {
  local key="$1"
  local value
  value="$(maa_value "$key" "0")"
  [[ "$value" =~ ^[0-9]+$ && "$value" -gt 0 ]]
}

maa_zero() {
  local key="$1"
  local value
  value="$(maa_value "$key" "0")"
  [[ "$value" =~ ^[0-9]+$ && "$value" -eq 0 ]]
}

maa_append_check() {
  local report_file="$1"
  local status="$2"
  local area="$3"
  local check_name="$4"
  local evidence="$5"
  local recommendation="$6"

  printf '| `%s` | %s | %s | %s | %s |\n' \
    "$(md_escape "$status")" \
    "$(md_escape "$area")" \
    "$(md_escape "$check_name")" \
    "$(md_escape "$evidence")" \
    "$(md_escape "$recommendation")" >>"$report_file"
}

maa_promote_count_from_srvctl() {
  local target_key="$1"
  shift
  local current source_key source_value promoted=0

  current="$(maa_value "$target_key" "0")"
  [[ "$current" =~ ^[0-9]+$ ]] || current=0
  for source_key in "$@"; do
    source_value="$(maa_value "$source_key" "0")"
    [[ "$source_value" =~ ^[0-9]+$ ]] || source_value=0
    promoted=$((promoted + source_value))
  done

  if [[ "$promoted" -gt "$current" ]]; then
    MAA_EVIDENCE["$target_key"]="$promoted"
  fi
}

collect_srvctl_service_evidence() {
  local output_file="$1"
  local summary_file="${output_file}.summary"
  local status="UNAVAILABLE"

  MAA_EVIDENCE["srvctl_available"]="NO"
  MAA_EVIDENCE["srvctl_service_status"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_role_based_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_primary_role_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_standby_role_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_all_role_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_automatic_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_singleton_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_uniform_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_ac_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_tac_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_fan_notification_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_commit_outcome_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_runtime_load_balancing_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_drain_timeout_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_session_state_consistency_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_failover_restore_service_count"]="UNAVAILABLE"

  if ! grid_tool_available srvctl || [[ -z "$DB_UNIQUE_NAME" ]]; then
    {
      printf "srvctl unavailable or DB_UNIQUE_NAME not discovered.\n"
      printf "srvctl=%s\n" "$(discover_grid_home_for_tool srvctl 2>/dev/null || printf not-found)"
      printf "DB_UNIQUE_NAME=%s\n" "${DB_UNIQUE_NAME:-unknown}"
    } >"$output_file" || true
    return "$SUCCESS"
  fi

  MAA_EVIDENCE["srvctl_available"]="YES"
  if run_grid_tool srvctl config service -d "$DB_UNIQUE_NAME" >"$output_file" 2>&1; then
    status="OK"
  else
    status="ERROR_OR_NO_SERVICES"
  fi
  MAA_EVIDENCE["srvctl_service_status"]="$status"

  awk '
    BEGIN {
      service_count=0
      role_based=0
      primary_role=0
      standby_role=0
      all_role=0
      automatic=0
      singleton=0
      uniform=0
      ac=0
      tac=0
      fan=0
      commit=0
      rlb=0
      drain=0
      session_state=0
      failover_restore=0
      in_service=0
    }
    function trim(v) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      return v
    }
    function field_value(line) {
      sub(/^[^:]+:[[:space:]]*/, "", line)
      return trim(line)
    }
    function flush_service() {
      if (!in_service) return
      if (svc_role != "" && svc_role != "none" && svc_role != "null") role_based++
      if (svc_role ~ /primary/) primary_role++
      if (svc_role ~ /standby|physical_standby|logical_standby|snapshot_standby/) standby_role++
      if (svc_role ~ /all/) all_role++
      if (svc_policy ~ /automatic/) automatic++
      if (svc_cardinality ~ /singleton/) singleton++
      if (svc_cardinality ~ /uniform/) uniform++
      if (svc_failover_type == "transaction") ac++
      if (svc_failover_type == "auto") tac++
      if (svc_fan ~ /true|yes/) fan++
      if (svc_commit ~ /true|yes/) commit++
      if (svc_rlb !~ /^$|none/) rlb++
      if (svc_drain + 0 > 0) drain++
      if (svc_session_state !~ /^$|none|static/) session_state++
      if (svc_failover_restore !~ /^$|none|no/) failover_restore++
    }
    function reset_service() {
      svc_role=""
      svc_policy=""
      svc_cardinality=""
      svc_failover_type=""
      svc_fan=""
      svc_commit=""
      svc_rlb=""
      svc_drain=0
      svc_session_state=""
      svc_failover_restore=""
    }
    /^Service name:/ {
      flush_service()
      reset_service()
      in_service=1
      service_count++
      next
    }
    /^(Service )?[Rr]ole:/ {
      svc_role=tolower(field_value($0))
      next
    }
    /^Management policy:/ {
      svc_policy=tolower(field_value($0))
      next
    }
    /^Cardinality:/ {
      svc_cardinality=tolower(field_value($0))
      next
    }
    /^Failover type:/ {
      svc_failover_type=tolower(field_value($0))
      next
    }
    /^AQ HA notifications:/ {
      svc_fan=tolower(field_value($0))
      next
    }
    /^Commit Outcome:/ {
      svc_commit=tolower(field_value($0))
      next
    }
    /^Runtime Load Balancing Goal:/ {
      svc_rlb=tolower(field_value($0))
      next
    }
    /^Drain timeout:/ {
      value=tolower(field_value($0))
      gsub(/[^0-9]/, "", value)
      svc_drain=value + 0
      next
    }
    /^Session State Consistency:/ {
      svc_session_state=tolower(field_value($0))
      next
    }
    /^Failover restore:/ {
      svc_failover_restore=tolower(field_value($0))
      next
    }
    END {
      flush_service()
      print "srvctl_service_count=" service_count
      print "srvctl_role_based_service_count=" role_based
      print "srvctl_primary_role_service_count=" primary_role
      print "srvctl_standby_role_service_count=" standby_role
      print "srvctl_all_role_service_count=" all_role
      print "srvctl_automatic_service_count=" automatic
      print "srvctl_singleton_service_count=" singleton
      print "srvctl_uniform_service_count=" uniform
      print "srvctl_ac_service_count=" ac
      print "srvctl_tac_service_count=" tac
      print "srvctl_fan_notification_service_count=" fan
      print "srvctl_commit_outcome_service_count=" commit
      print "srvctl_runtime_load_balancing_service_count=" rlb
      print "srvctl_drain_timeout_service_count=" drain
      print "srvctl_session_state_consistency_service_count=" session_state
      print "srvctl_failover_restore_service_count=" failover_restore
    }
  ' "$output_file" >"$summary_file" 2>/dev/null || true

  while IFS='=' read -r key value; do
    [[ -n "$key" ]] || continue
    MAA_EVIDENCE["$key"]="${value:-0}"
  done <"$summary_file"

  maa_promote_count_from_srvctl "ac_service_count" "srvctl_ac_service_count"
  maa_promote_count_from_srvctl "tac_service_count" "srvctl_tac_service_count"
  maa_promote_count_from_srvctl "application_continuity_service_count" "srvctl_ac_service_count" "srvctl_tac_service_count"
  maa_promote_count_from_srvctl "commit_outcome_service_count" "srvctl_commit_outcome_service_count"
  maa_promote_count_from_srvctl "fan_notification_service_count" "srvctl_fan_notification_service_count"
  maa_promote_count_from_srvctl "runtime_load_balancing_service_count" "srvctl_runtime_load_balancing_service_count"
  maa_promote_count_from_srvctl "drain_timeout_service_count" "srvctl_drain_timeout_service_count"
  maa_promote_count_from_srvctl "session_state_consistency_service_count" "srvctl_session_state_consistency_service_count"
  maa_promote_count_from_srvctl "failover_restore_service_count" "srvctl_failover_restore_service_count"
}

maa_observer_csv_add_unique() {
  local csv="$1"
  local value="$2"

  value="$(strip_config_quotes "$value")"
  value="${value%%[[:space:]](*}"
  value="${value%%[[:space:]]-*}"
  value="$(trim_value "$value")"
  [[ -n "$value" ]] || printf "%s" "$csv"
  [[ -n "$value" ]] || return "$SUCCESS"
  [[ "$value" == "(none)" || "$value" == "none" || "$value" == "UNKNOWN" ]] && {
    printf "%s" "$csv"
    return "$SUCCESS"
  }

  case ",${csv}," in
    *,"${value}",*) printf "%s" "$csv" ;;
    *)
      if [[ -n "$csv" ]]; then
        printf "%s,%s" "$csv" "$value"
      else
        printf "%s" "$value"
      fi
      ;;
  esac
}

maa_count_csv_values() {
  local csv="$1"
  local old_ifs count=0 item
  [[ -n "$csv" ]] || {
    printf "0"
    return "$SUCCESS"
  }
  old_ifs="$IFS"
  IFS=','
  for item in $csv; do
    item="$(trim_value "$item")"
    [[ -n "$item" ]] && count=$((count + 1))
  done
  IFS="$old_ifs"
  printf "%s" "$count"
}

maa_reset_fsfo_observer_evidence() {
  MAA_EVIDENCE["dgmgrl_available"]="NO"
  MAA_EVIDENCE["dgmgrl_fsfo_status"]="UNAVAILABLE"
  MAA_EVIDENCE["dgmgrl_fsfo_evidence_file"]="UNAVAILABLE"
  MAA_EVIDENCE["dgmgrl_bin"]="UNAVAILABLE"
  MAA_EVIDENCE["dgmgrl_fsfo_state"]="UNKNOWN"
  MAA_EVIDENCE["fsfo_active_observer"]="UNKNOWN"
  MAA_EVIDENCE["fsfo_observer_names"]="NONE"
  MAA_EVIDENCE["fsfo_observer_count"]="0"
  MAA_EVIDENCE["fsfo_preferred_observer_hosts"]="NONE"
  MAA_EVIDENCE["fsfo_preferred_observer_hosts_configured"]="NO"
}

parse_maa_dgmgrl_fsfo_evidence() {
  local output_file="$1"
  local line normalized lower value observer_names="" active_observer=""
  local observer_count=0 in_observers=0 preferred_lines="" preferred_configured="NO"
  local preferred_entry preferred_value
  local observer_list_re='^"?([^"[:space:]]+)"?[[:space:]]*[-(]'

  [[ -f "$output_file" ]] || return "$SUCCESS"

  while IFS= read -r line; do
    line="${line//$'\r'/}"
    normalized="$(trim_value "$line")"
    if [[ -z "$normalized" ]]; then
      in_observers=0
      continue
    fi

    if [[ "$normalized" =~ ^Fast-Start[[:space:]]+Failover:[[:space:]]*(.*)$ ]]; then
      MAA_EVIDENCE["dgmgrl_fsfo_state"]="$(trim_value "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ "$normalized" =~ ^Observers:[[:space:]]*$ ]]; then
      in_observers=1
      continue
    fi

    if [[ "$normalized" =~ ^Observer:[[:space:]]*(.*)$ ]]; then
      value="$(strip_config_quotes "${BASH_REMATCH[1]}")"
      value="$(trim_value "$value")"
      if [[ -n "$value" && "$value" != "(none)" && "$value" != "NONE" ]]; then
        active_observer="$value"
        observer_names="$(maa_observer_csv_add_unique "$observer_names" "$value")"
      fi
      continue
    fi

    if [[ "$in_observers" -eq 1 && "$normalized" =~ $observer_list_re ]]; then
      value="${BASH_REMATCH[1]}"
      observer_names="$(maa_observer_csv_add_unique "$observer_names" "$value")"
      if [[ "$normalized" =~ [Mm]aster|[Aa]ctive ]] && [[ -z "$active_observer" ]]; then
        active_observer="$(strip_config_quotes "$value")"
      fi
      continue
    fi

    if [[ "$normalized" =~ Preferred[[:space:]_]*Observer[[:space:]_]*Hosts ]]; then
      preferred_entry="$normalized"
      if [[ "$normalized" == *"="* ]]; then
        preferred_value="$(strip_config_quotes "${normalized#*=}")"
        preferred_value="$(trim_value "$preferred_value")"
        [[ -n "$preferred_value" ]] || preferred_value="EMPTY"
        preferred_entry="$preferred_value"
      fi
      if [[ -z "$preferred_lines" ]]; then
        preferred_lines="$preferred_entry"
      elif [[ "; ${preferred_lines}; " != *"; ${preferred_entry}; "* ]]; then
        preferred_lines="${preferred_lines}; ${preferred_entry}"
      fi
      lower="$(printf "%s" "$normalized" | tr '[:upper:]' '[:lower:]')"
      if [[ ! "$lower" =~ "''" &&
            ! "$lower" =~ "\(none\)" &&
            ! "$lower" =~ "not set" &&
            ! "$lower" =~ "null" &&
            ! "$lower" =~ "unknown" &&
            ! "$lower" =~ =[[:space:]]*$ &&
            ! "$lower" =~ :[[:space:]]*$ ]]; then
        preferred_configured="YES"
      fi
      continue
    fi
  done <"$output_file"

  observer_count="$(maa_count_csv_values "$observer_names")"
  MAA_EVIDENCE["fsfo_active_observer"]="${active_observer:-UNKNOWN}"
  MAA_EVIDENCE["fsfo_observer_names"]="${observer_names:-NONE}"
  MAA_EVIDENCE["fsfo_observer_count"]="$observer_count"
  MAA_EVIDENCE["fsfo_preferred_observer_hosts"]="${preferred_lines:-NONE}"
  MAA_EVIDENCE["fsfo_preferred_observer_hosts_configured"]="$preferred_configured"
}

collect_maa_dgmgrl_fsfo_evidence() {
  local output_file="$1"
  local status target current_db target_db dgmgrl_bin

  maa_reset_fsfo_observer_evidence
  MAA_EVIDENCE["dgmgrl_fsfo_evidence_file"]="$output_file"

  dgmgrl_bin="$(find_dgmgrl_bin)"
  if [[ -z "$dgmgrl_bin" || ! -x "$dgmgrl_bin" ]]; then
    printf "dgmgrl not found in ORACLE_HOME/bin or PATH.\n" >"$output_file" || true
    return "$SUCCESS"
  fi

  MAA_EVIDENCE["dgmgrl_available"]="YES"
  MAA_EVIDENCE["dgmgrl_bin"]="$dgmgrl_bin"
  current_db="${DB_UNIQUE_NAME:-$(maa_value db_unique_name "")}"
  target="$(maa_value fsfo_target NONE)"
  case "$target" in
    NONE|UNKNOWN|"") target_db="" ;;
    *) target_db="$target" ;;
  esac

  {
    printf 'show configuration verbose;\n'
    printf 'show fast_start failover;\n'
    if [[ -n "$current_db" ]]; then
      printf 'show database verbose "%s";\n' "$current_db"
    fi
    if [[ -n "$target_db" && "$target_db" != "$current_db" ]]; then
      printf 'show database verbose "%s";\n' "$target_db"
    fi
    printf 'exit\n'
  } | "$dgmgrl_bin" -silent / >"$output_file" 2>&1
  status=$?

  if [[ "$status" -eq 0 ]]; then
    MAA_EVIDENCE["dgmgrl_fsfo_status"]="OK"
  else
    MAA_EVIDENCE["dgmgrl_fsfo_status"]="ERROR"
    printf "\n[dgmgrl exited with status %s]\n" "$status" >>"$output_file" || true
  fi

  parse_maa_dgmgrl_fsfo_evidence "$output_file"
  return "$SUCCESS"
}

append_service_awareness_sections() {
  local report_file="$1"
  local dg_detected=0
  local adg_standby=0
  local ac_count tac_count replay_gap user_services role_services
  local fan_count rlb_count drain_count commit_count state_count restore_count
  local dml_redirect fsfo_status fsfo_observer db_role open_mode
  local fsfo_observer_count fsfo_observer_names fsfo_active_observer
  local fsfo_pref_hosts fsfo_pref_configured dgmgrl_fsfo_status dgmgrl_available
  local fsfo_enabled=0

  db_role="$(maa_value db_role UNKNOWN)"
  open_mode="$(maa_value open_mode UNKNOWN)"

  if [[ "$db_role" != "PRIMARY" && "$db_role" != "UNKNOWN" ]] || maa_positive remote_standby_dest_count; then
    dg_detected=1
  fi
  if [[ "$db_role" == *"STANDBY"* && "$open_mode" == *"READ ONLY WITH APPLY"* ]]; then
    adg_standby=1
  fi

  ac_count="$(maa_value ac_service_count "$(maa_value application_continuity_service_count 0)")"
  tac_count="$(maa_value tac_service_count 0)"
  replay_gap="$(maa_value service_without_ac_tac_count UNKNOWN)"
  user_services="$(maa_value service_user_count UNKNOWN)"
  role_services="$(maa_value srvctl_role_based_service_count UNKNOWN)"
  fan_count="$(maa_value fan_notification_service_count 0)"
  rlb_count="$(maa_value runtime_load_balancing_service_count 0)"
  drain_count="$(maa_value drain_timeout_service_count 0)"
  commit_count="$(maa_value commit_outcome_service_count 0)"
  state_count="$(maa_value session_state_consistency_service_count 0)"
  restore_count="$(maa_value failover_restore_service_count 0)"
  dml_redirect="$(maa_value adg_redirect_dml UNAVAILABLE)"
  fsfo_status="$(maa_value fsfo_status UNKNOWN)"
  fsfo_observer="$(maa_value fsfo_observer_present UNKNOWN)"
  fsfo_observer_count="$(maa_value fsfo_observer_count 0)"
  fsfo_observer_names="$(maa_value fsfo_observer_names NONE)"
  fsfo_active_observer="$(maa_value fsfo_active_observer UNKNOWN)"
  fsfo_pref_hosts="$(maa_value fsfo_preferred_observer_hosts NONE)"
  fsfo_pref_configured="$(maa_value fsfo_preferred_observer_hosts_configured NO)"
  dgmgrl_fsfo_status="$(maa_value dgmgrl_fsfo_status UNAVAILABLE)"
  dgmgrl_available="$(maa_value dgmgrl_available NO)"
  if [[ "$fsfo_status" =~ SYNCHRONIZED|TARGET|PRIMARY|READY|ENABLED ]] ||
     [[ "$fsfo_observer" == "YES" ]] ||
     [[ "$(maa_value dgmgrl_fsfo_state UNKNOWN)" =~ Enabled|enabled ]]; then
    fsfo_enabled=1
  fi

  append_report_section "$report_file" "Application Continuity, TAC, FSFO, DML Redirection, And Services Review"
  {
    printf '| Area | Evidence |\n'
    printf '| --- | --- |\n'
    printf '| SQL service dictionary | Source `%s`, services `%s`, application services `%s`, PDB services `%s` |\n' \
      "$(md_escape "$(maa_value service_attribute_source UNKNOWN)")" \
      "$(md_escape "$(maa_value service_total_count UNKNOWN)")" \
      "$(md_escape "$user_services")" \
      "$(md_escape "$(maa_value pdb_service_count UNKNOWN)")"
    printf '| Application Continuity / TAC | AC `%s`, TAC `%s`, Commit Outcome `%s`, missing AC/TAC `%s` |\n' \
      "$(md_escape "$ac_count")" "$(md_escape "$tac_count")" \
      "$(md_escape "$commit_count")" "$(md_escape "$replay_gap")"
    printf '| Client HA service attributes | FAN/AQ `%s`, RLB goals `%s`, drain timeout `%s`, session state consistency `%s`, failover restore `%s` |\n' \
      "$(md_escape "$fan_count")" "$(md_escape "$rlb_count")" \
      "$(md_escape "$drain_count")" "$(md_escape "$state_count")" "$(md_escape "$restore_count")"
    printf '| Data Guard / FSFO | DG detected `%s`, FSFO status `%s`, FSFO target `%s`, observer `%s`, threshold `%s` |\n' \
      "$(md_escape "$dg_detected")" "$(md_escape "$fsfo_status")" \
      "$(md_escape "$(maa_value fsfo_target NONE)")" "$(md_escape "$fsfo_observer")" \
      "$(md_escape "$(maa_value fsfo_threshold UNKNOWN)")"
    printf '| FSFO observer best-practice evidence | DGMGRL `%s/%s` from `%s`, active observer `%s`, observer count `%s`, observers `%s`, PreferredObserverHosts `%s` |\n' \
      "$(md_escape "$dgmgrl_available")" "$(md_escape "$dgmgrl_fsfo_status")" \
      "$(md_escape "$(maa_value dgmgrl_bin UNAVAILABLE)")" \
      "$(md_escape "$fsfo_active_observer")" "$(md_escape "$fsfo_observer_count")" \
      "$(md_escape "$fsfo_observer_names")" "$(md_escape "$fsfo_pref_configured")"
    printf '| Active Data Guard DML redirection | adg_redirect_dml `%s`, ADG standby context `%s` |\n' \
      "$(md_escape "$dml_redirect")" "$(md_escape "$adg_standby")"
    printf '| srvctl service metadata | srvctl `%s`, status `%s`, services `%s`, role-based `%s`, primary-role `%s`, standby-role `%s`, automatic `%s` |\n' \
      "$(md_escape "$(maa_value srvctl_available NO)")" \
      "$(md_escape "$(maa_value srvctl_service_status UNAVAILABLE)")" \
      "$(md_escape "$(maa_value srvctl_service_count UNKNOWN)")" \
      "$(md_escape "$role_services")" \
      "$(md_escape "$(maa_value srvctl_primary_role_service_count UNKNOWN)")" \
      "$(md_escape "$(maa_value srvctl_standby_role_service_count UNKNOWN)")" \
      "$(md_escape "$(maa_value srvctl_automatic_service_count UNKNOWN)")"
  } >>"$report_file"

  append_report_section "$report_file" "Service Best-Practice Checks"
  {
    printf '| Status | Area | Check | Evidence | Recommendation |\n'
    printf '| --- | --- | --- | --- | --- |\n'
  } >>"$report_file"

  if [[ "$user_services" =~ ^[0-9]+$ && "$user_services" -eq 0 ]]; then
    maa_append_check "$report_file" "INFO" "Services" "Application services visible" "application_services=${user_services}" "Create dedicated application services instead of relying on default database services."
  elif [[ "$user_services" =~ ^[0-9]+$ ]]; then
    maa_append_check "$report_file" "OK" "Services" "Application services visible" "application_services=${user_services}" "Keep services workload-specific so HA, DR, and maintenance policies can differ by application."
  else
    maa_append_check "$report_file" "INFO" "Services" "Application services visible" "application_services=${user_services}" "Service dictionary columns could not be fully inspected on this release/session."
  fi

  if [[ "$tac_count" =~ ^[0-9]+$ && "$tac_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "AC/TAC" "Transparent Application Continuity services" "tac_services=${tac_count}" "Validate request replay with planned relocation, instance abort, and application smoke tests."
  elif [[ "$ac_count" =~ ^[0-9]+$ && "$ac_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "AC/TAC" "Application Continuity services" "ac_services=${ac_count}, tac_services=${tac_count}" "Consider TAC where supported; confirm Transaction Guard, replay boundaries, and driver settings."
  else
    maa_append_check "$report_file" "INFO" "AC/TAC" "Replay-capable services" "ac_services=${ac_count}, tac_services=${tac_count}" "For user-facing services, evaluate TAC or AC with FAN/ONS and compatible drivers before HA drills."
  fi

  if [[ "$commit_count" =~ ^[0-9]+$ && "$commit_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "AC/TAC" "Commit Outcome / Transaction Guard" "commit_outcome_services=${commit_count}" "Keep retention aligned with application replay windows and failure detection."
  else
    maa_append_check "$report_file" "INFO" "AC/TAC" "Commit Outcome / Transaction Guard" "commit_outcome_services=${commit_count}" "Enable Commit Outcome for AC/TAC candidate services where the application is replay-safe."
  fi

  if [[ "$fan_count" =~ ^[0-9]+$ && "$fan_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "Client HA" "FAN/AQ notification services" "fan_services=${fan_count}" "Confirm ONS/FAN delivery with client pools during RAC/Data Guard failover drills."
  else
    maa_append_check "$report_file" "WARN" "Client HA" "FAN/AQ notification services" "fan_services=${fan_count}" "Enable HA notifications for application services and validate client-side failover behavior."
  fi

  if [[ "$rlb_count" =~ ^[0-9]+$ && "$rlb_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "Client HA" "Runtime/client load balancing goals" "rlb_services=${rlb_count}" "Validate service-time or throughput goals with connection pools and service relocation."
  else
    maa_append_check "$report_file" "INFO" "Client HA" "Runtime/client load balancing goals" "rlb_services=${rlb_count}" "Define CLB/RLB goals for services that need predictable RAC load balancing."
  fi

  if [[ "$drain_count" =~ ^[0-9]+$ && "$drain_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "Planned maintenance" "Service drain timeout" "drain_timeout_services=${drain_count}" "Use drain timeout and stop options during rolling maintenance and service relocation drills."
  else
    maa_append_check "$report_file" "INFO" "Planned maintenance" "Service drain timeout" "drain_timeout_services=${drain_count}" "Set drain timeout for services that need graceful planned maintenance."
  fi

  if [[ "$state_count" =~ ^[0-9]+$ && "$state_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "AC/TAC" "Session state consistency" "session_state_services=${state_count}" "Validate whether dynamic or auto session state handling matches application replay assumptions."
  else
    maa_append_check "$report_file" "INFO" "AC/TAC" "Session state consistency" "session_state_services=${state_count}" "Review session-state consistency before enabling AC/TAC for stateful applications."
  fi

  if [[ "$restore_count" =~ ^[0-9]+$ && "$restore_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "AC/TAC" "Failover restore" "failover_restore_services=${restore_count}" "Test restored session state with planned and unplanned outages."
  else
    maa_append_check "$report_file" "INFO" "AC/TAC" "Failover restore" "failover_restore_services=${restore_count}" "For TAC/AC candidates, review failover restore behavior with the application team."
  fi

  if [[ "$dg_detected" -eq 1 ]]; then
    if [[ "$role_services" =~ ^[0-9]+$ && "$role_services" -gt 0 ]]; then
      maa_append_check "$report_file" "OK" "Data Guard services" "Role-based services" "role_based_services=${role_services}, primary=$(maa_value srvctl_primary_role_service_count UNKNOWN), standby=$(maa_value srvctl_standby_role_service_count UNKNOWN)" "Keep primary write services and ADG read-only services role-scoped; validate after switchover and failover."
    elif [[ "$(maa_value srvctl_available NO)" == "YES" ]]; then
      maa_append_check "$report_file" "GAP" "Data Guard services" "Role-based services" "role_based_services=${role_services}" "Configure srvctl role-based services for PRIMARY and PHYSICAL_STANDBY/ADG workloads before DG/ADG drills."
    else
      maa_append_check "$report_file" "INFO" "Data Guard services" "Role-based services" "srvctl_available=$(maa_value srvctl_available NO)" "Run the review on a GI-managed host or provide srvctl evidence to validate role-based services."
    fi
  else
    maa_append_check "$report_file" "INFO" "Data Guard services" "Role-based services" "dg_detected=0" "Role-based services become critical once Data Guard or Active Data Guard is configured."
  fi

  if [[ "$dg_detected" -eq 1 ]]; then
    if [[ "$fsfo_enabled" -eq 1 ]]; then
      maa_append_check "$report_file" "OK" "FSFO" "Fast-Start Failover awareness" "fsfo=${fsfo_status}, observer=${fsfo_observer}, threshold=$(maa_value fsfo_threshold UNKNOWN)" "Validate observer location, failover threshold, target, reinstate/failback runbook, and application service movement."
    else
      maa_append_check "$report_file" "INFO" "FSFO" "Fast-Start Failover awareness" "fsfo=${fsfo_status}, observer=${fsfo_observer}" "For low RTO Data Guard designs, evaluate FSFO and rehearse observer failure/failback handling."
    fi
  else
    maa_append_check "$report_file" "INFO" "FSFO" "Fast-Start Failover awareness" "dg_detected=0" "FSFO applies after a broker-managed Data Guard configuration is in place."
  fi

  if [[ "$dg_detected" -eq 1 && "$fsfo_enabled" -eq 1 ]]; then
    if [[ "$fsfo_observer" == "YES" || "$fsfo_active_observer" != "UNKNOWN" || ( "$fsfo_observer_count" =~ ^[0-9]+$ && "$fsfo_observer_count" -gt 0 ) ]]; then
      maa_append_check "$report_file" "OK" "FSFO observer" "Active observer present" "observer_present=${fsfo_observer}, active=${fsfo_active_observer}, count=${fsfo_observer_count}" "Keep the active observer on an external site when possible; if no external site exists, run it with the primary site and keep a secondary-site observer ready after role transition."
    else
      maa_append_check "$report_file" "GAP" "FSFO observer" "Active observer present" "observer_present=${fsfo_observer}, active=${fsfo_active_observer}, count=${fsfo_observer_count}" "Start an FSFO observer before relying on automatic failover."
    fi

    if [[ "$fsfo_observer_count" =~ ^[0-9]+$ && "$fsfo_observer_count" -ge 2 ]]; then
      maa_append_check "$report_file" "OK" "FSFO observer" "Multiple observers configured" "observers=${fsfo_observer_names}" "Use multiple observers for observer high availability and validate master/backup observer behavior."
    else
      maa_append_check "$report_file" "WARN" "FSFO observer" "Multiple observers configured" "observer_count=${fsfo_observer_count}, observers=${fsfo_observer_names}" "Configure at least two observers when possible so observer availability does not become a single operational dependency."
    fi

    if [[ "$fsfo_pref_configured" == "YES" ]]; then
      maa_append_check "$report_file" "OK" "FSFO observer" "PreferredObserverHosts configured" "preferred_hosts=${fsfo_pref_hosts}" "Use PreferredObserverHosts to prefer external/primary-site observer hosts and avoid running the observer with the standby database."
    else
      maa_append_check "$report_file" "WARN" "FSFO observer" "PreferredObserverHosts configured" "preferred_hosts=${fsfo_pref_hosts}, dgmgrl=${dgmgrl_available}/${dgmgrl_fsfo_status}" "Configure PreferredObserverHosts on Data Guard members so the active observer is not placed with the standby database after role transitions."
    fi

    if [[ "$fsfo_pref_configured" == "YES" ]]; then
      maa_append_check "$report_file" "INFO" "FSFO observer" "Observer site placement" "active=${fsfo_active_observer}, preferred_hosts_configured=YES" "Confirm the preferred-host list maps to an external site first, primary site second, and does not prefer the standby database site."
    else
      maa_append_check "$report_file" "WARN" "FSFO observer" "Observer site placement" "active=${fsfo_active_observer}, preferred_hosts_configured=NO" "CrashSimulator cannot prove external/primary/standby site placement without PreferredObserverHosts or site metadata; never intentionally place the active observer with the standby database."
    fi
  elif [[ "$dg_detected" -eq 1 ]]; then
    maa_append_check "$report_file" "INFO" "FSFO observer" "Observer best-practice placement" "fsfo_enabled=${fsfo_enabled}, observer=${fsfo_observer}" "When FSFO is enabled, prefer external-site observers, avoid standby-site placement, configure multiple observers, and set PreferredObserverHosts."
  else
    maa_append_check "$report_file" "INFO" "FSFO observer" "Observer best-practice placement" "dg_detected=0" "Observer placement checks become applicable after Data Guard Broker and FSFO are configured."
  fi

  if [[ "$adg_standby" -eq 1 ]]; then
    if [[ "$(printf "%s" "$dml_redirect" | tr '[:lower:]' '[:upper:]')" =~ TRUE|YES|AUTO ]]; then
      maa_append_check "$report_file" "OK" "ADG DML redirection" "DML redirection configuration" "adg_redirect_dml=${dml_redirect}" "Validate redirected DML latency, application semantics, and primary impact before exposing ADG write-capable sessions."
    else
      maa_append_check "$report_file" "INFO" "ADG DML redirection" "DML redirection configuration" "adg_redirect_dml=${dml_redirect}" "Enable only for approved ADG services that require occasional DML; keep read-only services strictly read-only by default."
    fi
  elif [[ "$dg_detected" -eq 1 ]]; then
    maa_append_check "$report_file" "INFO" "ADG DML redirection" "DML redirection configuration" "role=${db_role}, open_mode=${open_mode}, adg_redirect_dml=${dml_redirect}" "Run this review on an ADG standby to confirm DML redirection posture for standby read services."
  else
    maa_append_check "$report_file" "INFO" "ADG DML redirection" "DML redirection configuration" "adg_redirect_dml=${dml_redirect}" "DML redirection is relevant for Active Data Guard standby services."
  fi
}

maa_sla_hint() {
  local local_rto local_rpo dr_rto dr_rpo planned_rto combined
  local_rto="$(printf "%s" "$MAA_LOCAL_RTO" | tr '[:upper:]' '[:lower:]')"
  local_rpo="$(printf "%s" "$MAA_LOCAL_RPO" | tr '[:upper:]' '[:lower:]')"
  dr_rto="$(printf "%s" "$MAA_DR_RTO" | tr '[:upper:]' '[:lower:]')"
  dr_rpo="$(printf "%s" "$MAA_DR_RPO" | tr '[:upper:]' '[:lower:]')"
  planned_rto="$(printf "%s" "$MAA_PLANNED_RTO" | tr '[:upper:]' '[:lower:]')"
  combined="${local_rto} ${local_rpo} ${dr_rto} ${dr_rpo} ${planned_rto}"

  if [[ -z "${combined// }" ]]; then
    printf "No SLA objectives supplied yet. Provide CRASHSIM_MAA_* values or --maa-* options in a future run to compare target objectives against detected posture."
  elif [[ "$combined" =~ zero|near.zero|seconds|sub.minute|subminute ]]; then
    printf "Supplied objectives appear very aggressive. Expect at least Gold for site protection, and Platinum/Diamond patterns when application-visible downtime must approach zero."
  elif [[ "$combined" =~ minute|min|hour ]]; then
    printf "Supplied objectives suggest Silver may cover local instance/server events, while Gold is normally required for low-RTO/low-RPO disaster recovery."
  else
    printf "Supplied objectives may be compatible with Bronze or Silver if backup/restore testing proves the required recovery windows. Validate with timed CrashSimulator drills."
  fi
}

maa_normalized_yes_no() {
  local raw="$1"
  raw="$(printf "%s" "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    y|yes|true|1|required|enabled|enable) printf "yes" ;;
    n|no|false|0|not|required|disabled|disable|none) printf "no" ;;
    *) printf "unknown" ;;
  esac
}

maa_duration_le() {
  local value="$1"
  local threshold="$2"
  local seconds
  seconds="$(duration_to_seconds "$value" 2>/dev/null)" || return "$FAIL"
  [[ "$seconds" -le "$threshold" ]]
}

maa_tier_rank() {
  case "$1" in
    Below\ Bronze) printf "0" ;;
    Bronze) printf "1" ;;
    Silver) printf "2" ;;
    Gold) printf "3" ;;
    Platinum) printf "4" ;;
    Diamond) printf "5" ;;
    *) printf "0" ;;
  esac
}

maa_rank_tier() {
  case "$1" in
    5) printf "Diamond" ;;
    4) printf "Platinum" ;;
    3) printf "Gold" ;;
    2) printf "Silver" ;;
    1) printf "Bronze" ;;
    *) printf "Below Bronze" ;;
  esac
}

maa_latest_manifest_for_ids() {
  local ids_csv="$1"
  local manifest scenario_id
  while IFS= read -r manifest; do
    scenario_id="$(awk -F= '$1=="scenario_id"{print $2; exit}' "$manifest" 2>/dev/null || true)"
    [[ -n "$scenario_id" ]] || continue
    case ",${ids_csv}," in
      *,"${scenario_id}",*) printf "%s\n" "$manifest"; return "$SUCCESS" ;;
    esac
  done < <(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_*s*.manifest' 2>/dev/null | sort -r)
  return "$FAIL"
}

maa_target_tier_from_context() {
  local criticality local_ha dr_required auto_failover active_active platform
  local target="Unknown" reason="Business RTO/RPO and outage-class context is incomplete."
  local gaps=""

  criticality="$(printf "%s" "$MAA_CRITICALITY" | tr '[:upper:]' '[:lower:]')"
  local_ha="$(maa_normalized_yes_no "$MAA_LOCAL_HA_TARGET")"
  dr_required="$(maa_normalized_yes_no "$MAA_DR_REQUIRED")"
  auto_failover="$(maa_normalized_yes_no "$MAA_AUTOMATIC_FAILOVER_REQUIRED")"
  active_active="$(maa_normalized_yes_no "$MAA_ACTIVE_ACTIVE_REQUIRED")"
  platform="$(printf "%s" "$MAA_PLATFORM_HINT" | tr '[:upper:]' '[:lower:]')"

  [[ -n "$MAA_CRITICALITY" ]] || gaps="${gaps}criticality; "
  [[ -n "$MAA_LOCAL_RTO" || -n "$MAA_DR_RTO" || -n "$MAA_PLANNED_RTO" ]] || gaps="${gaps}RTO objectives; "
  [[ -n "$MAA_LOCAL_RPO" || -n "$MAA_DR_RPO" || -n "$MAA_PLANNED_RPO" ]] || gaps="${gaps}RPO objectives; "
  [[ "$local_ha" != "unknown" ]] || gaps="${gaps}local HA target; "
  [[ "$dr_required" != "unknown" ]] || gaps="${gaps}DR requirement; "

  if [[ "$active_active" == "yes" ]] ||
     [[ "$criticality" =~ ultra|extreme ]] ||
     { maa_duration_le "$MAA_DR_RTO" 60 && maa_duration_le "$MAA_DR_RPO" 60; }; then
    target="Diamond"
    reason="Business context indicates active-active/extreme availability or very-low-seconds DR RTO/RPO."
  elif [[ "$platform" =~ exadata|engineered ]] &&
       { maa_duration_le "$MAA_PLANNED_RTO" 60 || maa_duration_le "$MAA_DR_RTO" 300; }; then
    target="Platinum"
    reason="Business context indicates near-zero interruption on an Exadata or engineered-platform strategy."
  elif [[ "$dr_required" == "yes" || "$auto_failover" == "yes" ]] ||
       maa_duration_le "$MAA_DR_RTO" 900 ||
       [[ "$(printf "%s" "$MAA_DR_RPO" | tr '[:upper:]' '[:lower:]')" =~ ^(zero|near-zero|near\ zero)$ ]]; then
    # Gold DR RTO threshold: low-minute DR (<= 15m) or zero/near-zero DR RPO
    # maps to Gold. A 15-minute DR RTO is still a Data Guard-class objective;
    # grading it below Gold understated the required architecture.
    target="Gold"
    reason="Business context indicates low-minute disaster recovery, strong RPO, or automatic failover."
  elif [[ "$local_ha" == "yes" ]] ||
       maa_duration_le "$MAA_LOCAL_RTO" 60 ||
       [[ "$criticality" =~ production|mission ]]; then
    target="Silver"
    reason="Business context indicates production-grade local HA or sub-minute local recovery."
  elif [[ -n "$MAA_LOCAL_RTO$MAA_DR_RTO$MAA_PLANNED_RTO$MAA_LOCAL_RPO$MAA_DR_RPO$MAA_PLANNED_RPO$MAA_CRITICALITY" ]]; then
    target="Bronze"
    reason="Supplied context appears compatible with restart/restore-based recoverability."
  fi

  MAA_TARGET_LEVEL="$target"
  MAA_TARGET_REASON="$reason"
  MAA_TARGET_GAPS="${gaps%; }"
}

maa_compute_decision_model() {
  local db_role open_mode standby_scope platform version_major
  local capture_count apply_count app_continuity user_services role_services fan_count rlb_count drain_count
  local fsfo_status fsfo_observer observer_count dgmgrl_status backup_manifest
  local local_manifest dr_manifest app_manifest
  local candidate="Bronze" candidate_reason="Backup/restart posture only; no local HA, DR, or active-replication topology was confirmed."
  local evidenced_rank=0 evidenced_reason=""
  local dg_detected=0 local_ha_candidate=0 remote_dg_candidate=0

  maa_target_tier_from_context

  db_role="$(maa_value db_role UNKNOWN)"
  open_mode="$(maa_value open_mode UNKNOWN)"
  standby_scope="$(printf "%s" "${MAA_STANDBY_SCOPE:-unknown}" | tr '[:upper:]' '[:lower:]')"
  platform="$(printf "%s" "$MAA_PLATFORM_HINT $STORAGE_TYPE $(maa_value platform_name UNKNOWN)" | tr '[:upper:]' '[:lower:]')"
  version_major="$(maa_value version_major 0)"
  capture_count="$(maa_value capture_process_count 0)"
  apply_count="$(maa_value apply_process_count 0)"
  app_continuity="$(maa_value application_continuity_service_count 0)"
  user_services="$(maa_value service_user_count UNKNOWN)"
  role_services="$(maa_value srvctl_role_based_service_count UNKNOWN)"
  fan_count="$(maa_value fan_notification_service_count 0)"
  rlb_count="$(maa_value runtime_load_balancing_service_count 0)"
  drain_count="$(maa_value drain_timeout_service_count 0)"
  fsfo_status="$(maa_value fsfo_status UNKNOWN)"
  fsfo_observer="$(maa_value fsfo_observer_present UNKNOWN)"
  observer_count="$(maa_value fsfo_observer_count 0)"
  dgmgrl_status="$(maa_value dgmgrl_fsfo_status UNAVAILABLE)"

  if [[ "$db_role" != "PRIMARY" && "$db_role" != "UNKNOWN" ]] || maa_positive remote_standby_dest_count; then
    dg_detected=1
  fi
  if [[ "$CLUSTER_TYPE" =~ ^(RAC|RACONE|RACONENODE|RAC_ONE_NODE)$ ||
        "$(maa_value cluster_database FALSE)" == "TRUE" ||
        "$(maa_value instance_parallel NO)" == "YES" ]]; then
    local_ha_candidate=1
  fi
  if [[ "$dg_detected" -eq 1 && "$standby_scope" == "local" ]]; then
    local_ha_candidate=1
  fi
  if [[ "$dg_detected" -eq 1 && "$standby_scope" != "local" ]]; then
    remote_dg_candidate=1
  fi

  if [[ "$local_ha_candidate" -eq 1 ]]; then
    candidate="Silver"
    candidate_reason="RAC/RAC One Node or explicitly local Data Guard standby evidence indicates a Silver local-HA candidate."
  fi
  if [[ "$remote_dg_candidate" -eq 1 ]]; then
    candidate="Gold"
    candidate_reason="Data Guard/Active Data Guard or remote standby transport evidence indicates a Gold DR candidate."
  fi
  if [[ "$candidate" == "Gold" &&
        "$capture_count" =~ ^[0-9]+$ && "$apply_count" =~ ^[0-9]+$ &&
        ( "$capture_count" -gt 0 || "$apply_count" -gt 0 ) ]]; then
    candidate="Platinum"
    candidate_reason="Data Guard plus replication dictionary evidence indicates a Platinum candidate; GoldenGate/active-replication supportability still needs manual confirmation."
  fi
  if [[ "$candidate" == "Platinum" &&
        "$version_major" =~ ^[0-9]+$ && "$version_major" -ge 26 &&
        "$(maa_normalized_yes_no "$MAA_ACTIVE_ACTIVE_REQUIRED")" == "yes" &&
        "$platform" =~ exadata ]]; then
    candidate="Diamond"
    candidate_reason="26ai, Exadata/platform hint, and active-active requirement indicate a Diamond candidate; architecture and measured evidence require manual confirmation."
  fi

  MAA_CANDIDATE_LEVEL="$candidate"
  MAA_CANDIDATE_REASON="$candidate_reason"
  MAA_DG_DETECTED="$dg_detected"
  MAA_LOCAL_HA_CANDIDATE="$local_ha_candidate"
  MAA_REMOTE_DG_CANDIDATE="$remote_dg_candidate"

  MAA_SCORE_BUSINESS=0
  [[ -n "$MAA_LOCAL_RTO$MAA_LOCAL_RPO$MAA_DR_RTO$MAA_DR_RPO$MAA_PLANNED_RTO$MAA_PLANNED_RPO" ]] && MAA_SCORE_BUSINESS=2
  [[ -n "$MAA_CRITICALITY" && "$MAA_SCORE_BUSINESS" -gt 0 ]] && MAA_SCORE_BUSINESS=3
  [[ -n "$MAA_CRITICALITY" && -n "$MAA_LOCAL_RTO" && -n "$MAA_DR_RTO" && -n "$MAA_LOCAL_RPO" && -n "$MAA_DR_RPO" ]] && MAA_SCORE_BUSINESS=4

  MAA_SCORE_BACKUP=0
  [[ "$(maa_value log_mode UNKNOWN)" == "ARCHIVELOG" ]] && MAA_SCORE_BACKUP=1
  maa_positive recent_successful_backup_jobs_7d && MAA_SCORE_BACKUP=2
  if maa_positive recent_successful_backup_jobs_7d && maa_zero datafiles_without_backup_metadata &&
     maa_zero recover_file_count && maa_zero block_corruption_count; then
    MAA_SCORE_BACKUP=3
  fi
  backup_manifest="$(latest_completed_recovery_manifest 2>/dev/null || true)"
  [[ -n "$backup_manifest" && "$MAA_SCORE_BACKUP" -ge 3 ]] && MAA_SCORE_BACKUP=4

  MAA_SCORE_LOCAL_HA=0
  [[ "$local_ha_candidate" -eq 1 ]] && MAA_SCORE_LOCAL_HA=1
  [[ "$user_services" =~ ^[0-9]+$ && "$user_services" -gt 0 && "$MAA_SCORE_LOCAL_HA" -gt 0 ]] && MAA_SCORE_LOCAL_HA=2
  if [[ "$MAA_SCORE_LOCAL_HA" -gt 0 ]] &&
     { [[ "$role_services" =~ ^[0-9]+$ && "$role_services" -gt 0 ]] ||
       [[ "$fan_count" =~ ^[0-9]+$ && "$fan_count" -gt 0 ]] ||
       [[ "$rlb_count" =~ ^[0-9]+$ && "$rlb_count" -gt 0 ]] ||
       [[ "$drain_count" =~ ^[0-9]+$ && "$drain_count" -gt 0 ]]; }; then
    MAA_SCORE_LOCAL_HA=3
  fi
  local_manifest="$(maa_latest_manifest_for_ids "55,56,70,71" 2>/dev/null || true)"
  [[ -n "$local_manifest" && "$MAA_SCORE_LOCAL_HA" -ge 3 ]] && MAA_SCORE_LOCAL_HA=4

  MAA_SCORE_DR=0
  [[ "$dg_detected" -eq 1 ]] && MAA_SCORE_DR=1
  [[ "$dg_detected" -eq 1 && ( "$(maa_value valid_remote_standby_dest_count 0)" =~ ^[0-9]+$ || "$db_role" == *"STANDBY"* ) ]] && MAA_SCORE_DR=2
  if [[ "$dg_detected" -eq 1 ]] &&
     { [[ "$dgmgrl_status" == "OK" ]] ||
       [[ "$(maa_value dataguard_stats_count 0)" =~ ^[1-9][0-9]*$ ]] ||
       [[ "$role_services" =~ ^[0-9]+$ && "$role_services" -gt 0 ]]; }; then
    MAA_SCORE_DR=3
  fi
  dr_manifest="$(maa_latest_manifest_for_ids "50,51,52,54,66,67,68,69" 2>/dev/null || true)"
  [[ -n "$dr_manifest" && "$MAA_SCORE_DR" -ge 3 ]] && MAA_SCORE_DR=4
  if [[ "$MAA_SCORE_DR" -ge 3 &&
        ( "$fsfo_status" =~ SYNCHRONIZED|TARGET|PRIMARY|READY|ENABLED || "$fsfo_observer" == "YES" ) &&
        "$observer_count" =~ ^[0-9]+$ && "$observer_count" -gt 0 ]]; then
    MAA_SCORE_DR=4
  fi

  MAA_SCORE_APP=0
  [[ "$user_services" =~ ^[0-9]+$ && "$user_services" -gt 0 ]] && MAA_SCORE_APP=1
  if [[ "$fan_count" =~ ^[0-9]+$ && "$fan_count" -gt 0 ]] ||
     [[ "$rlb_count" =~ ^[0-9]+$ && "$rlb_count" -gt 0 ]] ||
     [[ "$drain_count" =~ ^[0-9]+$ && "$drain_count" -gt 0 ]]; then
    MAA_SCORE_APP=2
  fi
  [[ "$app_continuity" =~ ^[0-9]+$ && "$app_continuity" -gt 0 ]] && MAA_SCORE_APP=3
  app_manifest="$(maa_latest_manifest_for_ids "56,70,71,80" 2>/dev/null || true)"
  [[ -n "$app_manifest" && "$MAA_SCORE_APP" -ge 2 ]] && MAA_SCORE_APP=4

  MAA_SCORE_OPERATIONS=1
  [[ "$AUDIT_RETAIN" =~ ^(1|yes|true)$ ]] && MAA_SCORE_OPERATIONS=2
  [[ -n "$(find "$LOG_DIR" -maxdepth 1 -type f \( -name 'crashsim_scenario_lifecycle_*.md' -o -name 'crashsim_scenario_readiness_*.md' \) 2>/dev/null | head -n 1)" ]] && MAA_SCORE_OPERATIONS=3

  if [[ "$MAA_SCORE_BACKUP" -ge 3 ]]; then
    evidenced_rank=1
    evidenced_reason="Bronze evidenced: backup/recovery baseline is configured and no immediate recovery/corruption blockers were detected."
  else
    evidenced_rank=0
    evidenced_reason="Below Bronze: backup/recovery baseline lacks enough evidence for Bronze confirmation."
  fi
  if [[ "$evidenced_rank" -ge 1 && "$MAA_SCORE_LOCAL_HA" -ge 4 && "$MAA_SCORE_APP" -ge 3 ]]; then
    evidenced_rank=2
    evidenced_reason="Silver evidenced: Bronze plus local HA, application-service integration, and measured local-failure evidence were found."
  fi
  if [[ "$evidenced_rank" -ge 2 && "$MAA_SCORE_DR" -ge 4 && "$MAA_SCORE_APP" -ge 3 ]]; then
    evidenced_rank=3
    evidenced_reason="Gold evidenced: Silver plus Data Guard/ADG DR evidence, role/service integration, and measured DR/lag/failover evidence were found."
  fi
  if [[ "$evidenced_rank" -ge 3 && "$MAA_CANDIDATE_LEVEL" =~ Platinum|Diamond &&
        "$MAA_SCORE_APP" -ge 4 && "$MAA_SCORE_OPERATIONS" -ge 4 ]]; then
    evidenced_rank=4
    evidenced_reason="Platinum evidenced: Gold plus active-replication/platform and measured application-continuity evidence were found."
  fi
  if [[ "$evidenced_rank" -ge 4 && "$MAA_CANDIDATE_LEVEL" == "Diamond" &&
        "$MAA_SCORE_OPERATIONS" -ge 4 ]]; then
    evidenced_rank=5
    evidenced_reason="Diamond evidenced: extreme-availability candidate plus operational evidence was found; verify supportability manually."
  fi

  MAA_EVIDENCED_LEVEL="$(maa_rank_tier "$evidenced_rank")"
  MAA_EVIDENCED_REASON="$evidenced_reason"
  MAA_FIT_GAP_RANK=$(( $(maa_tier_rank "${MAA_TARGET_LEVEL:-Unknown}") - evidenced_rank ))
  if [[ "${MAA_TARGET_LEVEL:-Unknown}" == "Unknown" ]]; then
    MAA_FIT_GAP_SUMMARY="Target MAA level is unknown because business context is incomplete."
  elif [[ "$MAA_FIT_GAP_RANK" -le 0 ]]; then
    MAA_FIT_GAP_SUMMARY="Current evidenced level meets or exceeds the supplied target context."
  else
    MAA_FIT_GAP_SUMMARY="Current evidenced level is below the supplied target context by ${MAA_FIT_GAP_RANK} tier(s)."
  fi
}

score_clamp() {
  local value="$1"
  [[ "$value" =~ ^-?[0-9]+$ ]] || value=0
  (( value < 0 )) && value=0
  (( value > 100 )) && value=100
  printf "%s" "$value"
}

score_from_maturity() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ ]] || value=0
  score_clamp $((value * 20))
}

score_level_gap_points() {
  local target="$1"
  local evidenced="$2"
  local gap
  if [[ "$target" == "Unknown" || -z "$target" ]]; then
    printf "50"
    return "$SUCCESS"
  fi
  gap=$(( $(maa_tier_rank "$target") - $(maa_tier_rank "$evidenced") ))
  if [[ "$gap" -le 0 ]]; then
    printf "100"
  else
    score_clamp $((100 - gap * 20))
  fi
}

resilience_score_level() {
  local score="$1"
  if [[ "$score" -ge 90 ]]; then
    printf "Excellent"
  elif [[ "$score" -ge 80 ]]; then
    printf "Strong"
  elif [[ "$score" -ge 70 ]]; then
    printf "Good"
  elif [[ "$score" -ge 55 ]]; then
    printf "Developing"
  elif [[ "$score" -ge 40 ]]; then
    printf "At Risk"
  else
    printf "Critical Gaps"
  fi
}

score_badge() {
  local score="$1"
  local label
  label="$(resilience_score_level "$score")"
  printf "%s/100 (%s)" "$score" "$label"
}

resilience_domain_append() {
  local report_file="$1"
  local domain="$2"
  local score="$3"
  local weight="$4"
  local evidence="$5"
  local recommendation="$6"
  local weighted
  weighted=$((score * weight))
  RESILIENCE_TOTAL_WEIGHT=$((RESILIENCE_TOTAL_WEIGHT + weight))
  RESILIENCE_WEIGHTED_SUM=$((RESILIENCE_WEIGHTED_SUM + weighted))
  printf '| %s | `%s` | `%s%%` | %s | %s |\n' \
    "$(md_escape "$domain")" \
    "$(md_escape "$(score_badge "$score")")" \
    "$weight" \
    "$(md_escape "$evidence")" \
    "$(md_escape "$recommendation")" >>"$report_file"
}

resilience_scenario_coverage_score() {
  local id total=0 automated=0 read_only=0 plan_only=0 placeholder=0 score
  for id in "${SCENARIO_IDS[@]}"; do
    total=$((total + 1))
    if supports_recovery_automation "$id" || supports_file_recovery_automation "$id"; then
      automated=$((automated + 1))
    fi
    case "$id" in
      53|64|65|69|78|80|81|82) read_only=$((read_only + 1)) ;;
      46|47|48|49|52|54|66|70|72) plan_only=$((plan_only + 1)) ;;
    esac
    [[ "${SCENARIO_HANDLER[$id]}" == "scenario_planned" ]] && placeholder=$((placeholder + 1))
  done
  if [[ "$total" -eq 0 ]]; then
    printf "0|registered=0"
    return "$SUCCESS"
  fi
  score=$(( (automated * 70 + read_only * 55 + plan_only * 35) / total ))
  (( placeholder > 0 )) && score=$((score - placeholder * 2))
  score="$(score_clamp "$score")"
  printf "%s|registered=%s, automated=%s, read_only=%s, plan_only=%s, placeholders=%s" \
    "$score" "$total" "$automated" "$read_only" "$plan_only" "$placeholder"
}

run_resilience_scorecard() {
  discover_environment
  ensure_sqlplus

  local report_file latest_file sql_file evidence_file srvctl_service_file dgmgrl_fsfo_file generated_at
  local backup_score rac_score security_score dr_score recoverability_score maa_score scenario_score app_score
  local scenario_evidence overall score_line backup_manifest rto_manifest rpo_manifest
  local encrypted wallet_not_open wallet_open tde_config log_mode force_logging recent_jobs missing_files failed_jobs
  local recover_files corrupt_rows flashback

  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  report_file="${LOG_DIR}/crashsim_resilience_scorecard_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_resilience_scorecard_latest.md"
  sql_file="${LOG_DIR}/crashsim_resilience_scorecard_${RUN_ID}.sql"
  evidence_file="${LOG_DIR}/crashsim_resilience_scorecard_${RUN_ID}.evidence"
  srvctl_service_file="${LOG_DIR}/crashsim_resilience_scorecard_${RUN_ID}_srvctl_services.out"
  dgmgrl_fsfo_file="${LOG_DIR}/crashsim_resilience_scorecard_${RUN_ID}_dgmgrl_fsfo.out"

  write_maa_assessment_sql_file "$sql_file"
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "Resilience scorecard SQL failed: $sql_file (evidence: $evidence_file)"
  parse_maa_evidence_file "$evidence_file"
  collect_srvctl_service_evidence "$srvctl_service_file"
  collect_maa_dgmgrl_fsfo_evidence "$dgmgrl_fsfo_file"
  maa_compute_decision_model

  log_mode="$(maa_value log_mode UNKNOWN)"
  force_logging="$(maa_value force_logging UNKNOWN)"
  recent_jobs="$(maa_value recent_successful_backup_jobs_7d 0)"
  missing_files="$(maa_value datafiles_without_backup_metadata 0)"
  failed_jobs="$(maa_value recent_failed_backup_jobs_7d 0)"
  recover_files="$(maa_value recover_file_count 0)"
  corrupt_rows=$(( $(maa_value block_corruption_count 0) + $(maa_value copy_corruption_count 0) + $(maa_value backup_corruption_count 0) ))
  flashback="$(maa_value flashback_on UNKNOWN)"
  wallet_open="$(maa_value tde_wallet_open_count 0)"
  wallet_not_open="$(maa_value tde_wallet_not_open_count 0)"
  encrypted="$(maa_value encrypted_tablespace_count 0)"
  tde_config="$(maa_value tde_configuration NONE)"

  backup_score=0
  [[ "$log_mode" == "ARCHIVELOG" ]] && backup_score=$((backup_score + 20))
  [[ "$recent_jobs" =~ ^[0-9]+$ && "$recent_jobs" -gt 0 ]] && backup_score=$((backup_score + 25))
  [[ "$missing_files" =~ ^[0-9]+$ && "$missing_files" -eq 0 ]] && backup_score=$((backup_score + 25))
  [[ "$failed_jobs" =~ ^[0-9]+$ && "$failed_jobs" -eq 0 ]] && backup_score=$((backup_score + 15))
  backup_manifest="$(latest_completed_recovery_manifest 2>/dev/null || true)"
  [[ -n "$backup_manifest" ]] && backup_score=$((backup_score + 15))
  backup_score="$(score_clamp "$backup_score")"

  rac_score="$(score_from_maturity "${MAA_SCORE_LOCAL_HA:-0}")"
  app_score="$(score_from_maturity "${MAA_SCORE_APP:-0}")"
  dr_score="$(score_from_maturity "${MAA_SCORE_DR:-0}")"

  security_score=20
  [[ "$force_logging" == "YES" ]] && security_score=$((security_score + 20))
  [[ "$tde_config" != "NONE" && "$tde_config" != "UNKNOWN" ]] && security_score=$((security_score + 15))
  [[ "$wallet_not_open" =~ ^[0-9]+$ && "$wallet_not_open" -eq 0 ]] && security_score=$((security_score + 20))
  [[ "$encrypted" =~ ^[0-9]+$ && "$encrypted" -gt 0 ]] && security_score=$((security_score + 15))
  [[ "$wallet_open" =~ ^[0-9]+$ && "$wallet_open" -gt 0 ]] && security_score=$((security_score + 10))
  security_score="$(score_clamp "$security_score")"

  recoverability_score=0
  [[ "$log_mode" == "ARCHIVELOG" ]] && recoverability_score=$((recoverability_score + 20))
  [[ "$flashback" == "YES" ]] && recoverability_score=$((recoverability_score + 15))
  [[ "$recover_files" =~ ^[0-9]+$ && "$recover_files" -eq 0 ]] && recoverability_score=$((recoverability_score + 20))
  [[ "$corrupt_rows" -eq 0 ]] && recoverability_score=$((recoverability_score + 20))
  [[ -n "$backup_manifest" ]] && recoverability_score=$((recoverability_score + 15))
  rto_manifest="$(maa_latest_manifest_for_ids "64" 2>/dev/null || true)"
  rpo_manifest="$(maa_latest_manifest_for_ids "65" 2>/dev/null || true)"
  [[ -n "$rto_manifest" || -n "$rpo_manifest" ]] && recoverability_score=$((recoverability_score + 10))
  recoverability_score="$(score_clamp "$recoverability_score")"

  maa_score="$(score_level_gap_points "${MAA_TARGET_LEVEL:-Unknown}" "${MAA_EVIDENCED_LEVEL:-Below Bronze}")"
  if [[ "${MAA_TARGET_LEVEL:-Unknown}" == "Unknown" ]]; then
    maa_score=$((maa_score - 15))
  fi
  maa_score="$(score_clamp "$maa_score")"

  score_line="$(resilience_scenario_coverage_score)"
  scenario_score="${score_line%%|*}"
  scenario_evidence="${score_line#*|}"

  RESILIENCE_TOTAL_WEIGHT=0
  RESILIENCE_WEIGHTED_SUM=0

  {
    printf "# CrashSimulator Resilience Scorecard\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- Database: `%s`\n' "$(maa_value db_name "$DB_NAME")"
    printf -- '- DB unique name: `%s`\n' "$(maa_value db_unique_name "$DB_UNIQUE_NAME")"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(maa_value db_role "$DB_ROLE")" "$(maa_value open_mode "$DB_OPEN_MODE")"
    printf -- '- Cluster/storage: `%s` / `%s`\n' "$CLUSTER_TYPE" "$STORAGE_TYPE"
    printf -- '- Target MAA level: `%s`\n' "${MAA_TARGET_LEVEL:-Unknown}"
    printf -- '- Candidate MAA level: `%s`\n' "${MAA_CANDIDATE_LEVEL:-Unknown}"
    printf -- '- Current evidenced MAA level: `%s`\n' "${MAA_EVIDENCED_LEVEL:-Unknown}"
    printf -- '- SQL evidence file: `%s`\n' "$evidence_file"
    printf "\n"
    printf "This scorecard is an evidence-weighted management view. Scores are planning indicators, not Oracle certification or SLA guarantees. Re-run after topology changes, backups, recovery drills, switchover/failover tests, and scenario validations.\n\n"

    printf "## Domain Scores\n\n"
    printf '| Domain | Score | Weight | Evidence | Recommendation |\n'
    printf '| --- | ---: | ---: | --- | --- |\n'
  } >"$report_file" || die "Unable to write resilience scorecard: $report_file"

  resilience_domain_append "$report_file" "Backup" "$backup_score" 15 "ARCHIVELOG=${log_mode}, jobs_7d=${recent_jobs}, failed_7d=${failed_jobs}, missing_datafiles=${missing_files}, recovery_manifest=$([[ -n "$backup_manifest" ]] && printf yes || printf no)" "Keep backup cadence aligned to RPO and prove restore time with timed recovery drills."
  resilience_domain_append "$report_file" "RAC / Local HA" "$rac_score" 12 "candidate=${MAA_LOCAL_HA_CANDIDATE:-0}, score=${MAA_SCORE_LOCAL_HA:-0}/5, services=$(maa_value service_user_count UNKNOWN), FAN=$(maa_value fan_notification_service_count UNKNOWN), local_drill=$([[ -n "$(maa_latest_manifest_for_ids "55,56,70,71" 2>/dev/null || true)" ]] && printf yes || printf no)" "Use services, FAN/ONS, drain, AC/TAC where applicable, and measure local failure drills."
  resilience_domain_append "$report_file" "Security" "$security_score" 10 "force_logging=${force_logging}, tde_config=${tde_config}, encrypted_tbs=${encrypted}, wallet_open=${wallet_open}, wallet_not_open=${wallet_not_open}" "Validate TDE/wallet backup posture and add DBSAT/Data Safe evidence for a fuller security score."
  resilience_domain_append "$report_file" "DR / Data Guard" "$dr_score" 15 "dg_detected=${MAA_DG_DETECTED:-0}, valid_standby_dests=$(maa_value valid_remote_standby_dest_count 0), FSFO=$(maa_value fsfo_status UNKNOWN), observer=$(maa_value fsfo_observer_present UNKNOWN), score=${MAA_SCORE_DR:-0}/5" "Validate Broker, lag, role-based services, FSFO observer placement, switchover/failover, and application reconnect behavior."
  resilience_domain_append "$report_file" "Recoverability" "$recoverability_score" 15 "recover_files=${recover_files}, corruption_rows=${corrupt_rows}, flashback=${flashback}, recovery_manifest=$([[ -n "$backup_manifest" ]] && printf yes || printf no), rto_rpo_drills=$([[ -n "$rto_manifest$rpo_manifest" ]] && printf yes || printf no)" "Use scenarios 64/65 and timed recoveries to prove actual RTO/RPO, not only configuration readiness."
  resilience_domain_append "$report_file" "MAA Alignment" "$maa_score" 15 "target=${MAA_TARGET_LEVEL:-Unknown}, candidate=${MAA_CANDIDATE_LEVEL:-Unknown}, evidenced=${MAA_EVIDENCED_LEVEL:-Unknown}, gap=${MAA_FIT_GAP_SUMMARY:-Unknown}" "Close the largest target-versus-evidence gaps first; avoid claiming candidate tiers without measured evidence."
  resilience_domain_append "$report_file" "Scenario Coverage" "$scenario_score" 10 "$scenario_evidence" "Run scenario readiness/lifecycle reports and prioritize missing automation for high-value HA/DR drills."
  resilience_domain_append "$report_file" "Application Continuity" "$app_score" 8 "score=${MAA_SCORE_APP:-0}/5, AC=$(maa_value ac_service_count 0), TAC=$(maa_value tac_service_count 0), role_services=$(maa_value srvctl_role_based_service_count UNKNOWN), APEX/session_drill=$([[ -n "$(maa_latest_manifest_for_ids "80" 2>/dev/null || true)" ]] && printf yes || printf no)" "Validate client pools, FAN/ONS, AC/TAC replay safety, role-based services, and APEX/ORDS session behavior where applicable."

  if [[ "$RESILIENCE_TOTAL_WEIGHT" -gt 0 ]]; then
    overall=$((RESILIENCE_WEIGHTED_SUM / RESILIENCE_TOTAL_WEIGHT))
  else
    overall=0
  fi

  {
    printf "\n## Overall Score\n\n"
    printf '| Metric | Value |\n'
    printf '| --- | --- |\n'
    printf '| Resilience Score | `%s` |\n' "$(score_badge "$overall")"
    printf '| Total weight | `%s` |\n' "$RESILIENCE_TOTAL_WEIGHT"
    printf '| MAA fit-gap | %s |\n' "$(md_escape "${MAA_FIT_GAP_SUMMARY:-Unknown}")"

    printf "\n## How The Score Updates\n\n"
    printf -- '- New backups, RMAN validation, and recovery manifests improve Backup and Recoverability evidence.\n'
    printf -- '- RAC/service relocation, VIP/service placement, and APEX session manifests improve Local HA and Application Continuity evidence.\n'
    printf -- '- Data Guard apply/transport, FSFO, SRL, switchover/failover, and standby drill manifests improve DR evidence.\n'
    printf -- '- Updated MAA context can raise or lower the target tier; measured evidence determines the evidenced tier.\n'

    printf "\n## Recommended Next Actions\n\n"
    if [[ "$dr_score" -lt 60 ]]; then
      printf -- '- DR score is low: validate or configure Data Guard/ADG, Broker, SRLs, lag monitoring, role-based services, and FSFO where required.\n'
    fi
    if [[ "$recoverability_score" -lt 75 ]]; then
      printf -- '- Recoverability needs stronger proof: run timed restore/recovery drills and scenarios `64` and `65` for RTO/RPO validation.\n'
    fi
    if [[ "$rac_score" -lt 70 && "${MAA_LOCAL_HA_TARGET:-}" =~ ^(yes|YES|true|TRUE|1)$ ]]; then
      printf -- '- Local HA target is set but score is below target: validate service relocation, FAN/ONS, drain, AC/TAC, and instance failure behavior.\n'
    fi
    if [[ "$security_score" -lt 75 ]]; then
      printf -- '- Security score is partial: add DBSAT/Data Safe evidence and validate TDE wallet backup/open behavior across RAC/DG sites.\n'
    fi
    if [[ "$scenario_score" -lt 70 ]]; then
      printf -- '- Scenario coverage can improve: run `--scenario-lifecycle-report` and prioritize lifecycle helpers for high-risk HA/DR scenarios.\n'
    fi
    printf -- '- Save this report as audit evidence before and after major resilience improvements.\n'

    printf "\n## Raw Evidence References\n\n"
    printf -- '- MAA SQL evidence: `%s`\n' "$evidence_file"
    printf -- '- srvctl service evidence: `%s`\n' "$srvctl_service_file"
    printf -- '- DGMGRL/FSFO evidence: `%s`\n' "$dgmgrl_fsfo_file"
  } >>"$report_file"

  cp "$report_file" "$latest_file" || die "Unable to update latest resilience scorecard: $latest_file"
  echo "Resilience scorecard generated: ${report_file}"
  echo "Latest resilience scorecard: ${latest_file}"
  echo "Resilience Score: $(score_badge "$overall")"
  maybe_render_html "$report_file"
  if [[ "$HTML_OUTPUT" -eq 1 ]]; then
    render_artifact_html "$latest_file"
  fi
}

maybe_refresh_resilience_scorecard() {
  local trigger="$1"
  local id="${2:-}"
  local probe_sql probe_out refresh_out

  [[ "${AUTO_SCORECARD:-0}" -eq 1 ]] || return "$SUCCESS"
  [[ "${AUTO_SCORECARD_REFRESHING:-0}" -eq 0 ]] || return "$SUCCESS"

  case "$trigger" in
    scenario|random|protect|recover|validate|validate_all|scenario_readiness_report|scenario_lifecycle_report|health|baseline_backup)
      ;;
    *)
      return "$SUCCESS"
      ;;
  esac

  if ! ensure_sqlplus >/dev/null 2>&1; then
    warn "Resilience scorecard auto-refresh skipped after ${trigger}: SQL*Plus is not available."
    return "$SUCCESS"
  fi

  mkdir -p "$WORK_DIR" 2>/dev/null || return "$SUCCESS"
  probe_sql="${WORK_DIR}/crashsim_resilience_scorecard_probe_${RUN_ID}.sql"
  probe_out="${WORK_DIR}/crashsim_resilience_scorecard_probe_${RUN_ID}.out"
  refresh_out="${WORK_DIR}/crashsim_resilience_scorecard_refresh_${RUN_ID}.out"
  {
    printf "set heading off feedback off pages 0 verify off echo off termout on\n"
    printf "whenever sqlerror exit failure\n"
    printf "select 'OK' from dual;\n"
    printf "exit\n"
  } >"$probe_sql" || return "$SUCCESS"

  if ! "$SQLPLUS_BIN" -L -s "$SQLPLUS_LOGON" @"$probe_sql" >"$probe_out" 2>&1 </dev/null; then
    warn "Resilience scorecard auto-refresh skipped after ${trigger}: target database is not ready for SQL evidence collection."
    return "$SUCCESS"
  fi

  if (
    AUTO_SCORECARD_REFRESHING=1
    HTML_OUTPUT=0
    run_resilience_scorecard >"$refresh_out" 2>&1
  ); then
    if [[ -n "$id" ]]; then
      echo "Resilience scorecard auto-refreshed after ${trigger} ${id}: ${LOG_DIR}/crashsim_resilience_scorecard_latest.md"
    else
      echo "Resilience scorecard auto-refreshed after ${trigger}: ${LOG_DIR}/crashsim_resilience_scorecard_latest.md"
    fi
  else
    warn "Resilience scorecard auto-refresh skipped after ${trigger}; details: ${refresh_out}"
  fi
}

write_maa_report_sqlplus_blocked_stub() {
  local report_file="$1"
  local generated_at="$2"
  {
    printf "# CrashSimulator Oracle MAA Readiness Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Application context: `%s`\n' "${MAA_APP_NAME:-not supplied}"
    printf -- '- Database evidence: `blocked (SQL*Plus not available)`\n'
    printf -- '- Target MAA level: `Unknown`\n'
    printf -- '- Candidate MAA level: `Unknown`\n'
    printf -- '- Current evidenced MAA level: `Unknown`\n'
    printf -- '- Readiness status: `BLOCKED`\n'
    printf "\n"
    printf "This report is a best-effort posture assessment, not an Oracle certification. SQL*Plus was not found on this host, so no live database, Grid Infrastructure, or Data Guard evidence could be collected. Every database-derived section is therefore reported as a blocker rather than an assessed result.\n\n"
  } >"$report_file" || die "Unable to write MAA report file: $report_file"

  append_report_section "$report_file" "Database Evidence Blockers"
  {
    printf '| Evidence domain | Status | Unblock action |\n'
    printf '| --- | --- | --- |\n'
    printf '| Database topology (role, open mode, CDB) | `blocked` | Set ORACLE_HOME or SQLPLUS on a host with a created, open database, then re-run `--maa-report`. |\n'
    printf '| Backup and recovery (ARCHIVELOG, RMAN) | `blocked` | Provide SQL*Plus access to the target database and re-run the report. |\n'
    printf '| Local HA (RAC / services) | `blocked` | Provide SQL*Plus and Grid Infrastructure access on the database host and re-run the report. |\n'
    printf '| Data Guard / ADG / FSFO | `blocked` | Provide SQL*Plus and Data Guard Broker access and re-run the report. |\n'
    printf '| Application continuity (services, FAN/AC) | `blocked` | Provide SQL*Plus access to the target database and re-run the report. |\n'
  } >>"$report_file"

  append_report_section "$report_file" "How To Unblock"
  {
    printf -- '- Set `ORACLE_HOME` so that `$ORACLE_HOME/bin/sqlplus` exists, or set `SQLPLUS` to the sqlplus binary.\n'
    printf -- '- Run this report on a host where the target database has been created and is open.\n'
    printf -- '- Re-run `./%s --maa-report` once SQL*Plus can reach the database to replace these blockers with assessed evidence.\n' "$PROGRAM"
  } >>"$report_file"

  append_report_section "$report_file" "References"
  {
    printf -- '- Oracle MAA Reference Architectures Overview: https://docs.oracle.com/en/database/oracle/oracle-database/26/haiad/maa_overview.html\n'
    printf -- '- Oracle HA requirements, RTO/RPO, and MAA architecture mapping: https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/ha-requirements-architecture.html\n'
  } >>"$report_file"
}

run_maa_report() {
  local report_file sql_file evidence_file srvctl_service_file dgmgrl_fsfo_file generated_at
  local readiness_status sla_hint baseline_gap=0
  local app_continuity capture_count apply_count

  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  report_file="${LOG_DIR}/crashsim_maa_report_${RUN_ID}.md"

  if ! find_sqlplus_if_available; then
    warn "SQL*Plus was not found. The MAA readiness report will still be generated, with all database evidence marked as blockers until ORACLE_HOME or SQLPLUS is set on a host with a created database."
    write_maa_report_sqlplus_blocked_stub "$report_file" "$generated_at"
    echo "MAA readiness report generated with blockers: ${report_file}"
    echo "Target MAA level: Unknown (database evidence blocked: SQL*Plus not available)"
    maybe_render_html "$report_file"
    return "$SUCCESS"
  fi

  discover_environment
  ensure_sqlplus

  sql_file="${LOG_DIR}/crashsim_maa_report_${RUN_ID}.sql"
  evidence_file="${LOG_DIR}/crashsim_maa_report_${RUN_ID}.evidence"
  srvctl_service_file="${LOG_DIR}/crashsim_maa_report_${RUN_ID}_srvctl_services.out"
  dgmgrl_fsfo_file="${LOG_DIR}/crashsim_maa_report_${RUN_ID}_dgmgrl_fsfo.out"
  write_maa_assessment_sql_file "$sql_file"

  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "MAA assessment SQL failed: $sql_file (evidence: $evidence_file)"
  parse_maa_evidence_file "$evidence_file"
  collect_srvctl_service_evidence "$srvctl_service_file"
  collect_maa_dgmgrl_fsfo_evidence "$dgmgrl_fsfo_file"

  capture_count="$(maa_value capture_process_count 0)"
  apply_count="$(maa_value apply_process_count 0)"
  app_continuity="$(maa_value application_continuity_service_count 0)"

  [[ "$(maa_value log_mode UNKNOWN)" == "ARCHIVELOG" ]] || baseline_gap=1
  [[ "$(maa_value force_logging UNKNOWN)" == "YES" ]] || baseline_gap=1
  maa_positive recent_successful_backup_jobs_7d || baseline_gap=1
  maa_zero datafiles_without_backup_metadata || baseline_gap=1
  maa_zero recover_file_count || baseline_gap=1
  maa_zero block_corruption_count || baseline_gap=1

  readiness_status="Baseline checks passed"
  [[ "$baseline_gap" -eq 0 ]] || readiness_status="Baseline gaps detected"
  sla_hint="$(maa_sla_hint)"
  maa_compute_decision_model

  {
    printf "# CrashSimulator Oracle MAA Readiness Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Application context: `%s`\n' "${MAA_APP_NAME:-not supplied}"
    printf -- '- Database: `%s`\n' "$(maa_value db_name "$DB_NAME")"
    printf -- '- DB unique name: `%s`\n' "$(maa_value db_unique_name "$DB_UNIQUE_NAME")"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(maa_value db_role "$DB_ROLE")" "$(maa_value open_mode "$DB_OPEN_MODE")"
    printf -- '- CDB: `%s`\n' "$(maa_value cdb "$DB_CDB")"
    printf -- '- Cluster type: `%s`\n' "$CLUSTER_TYPE"
    printf -- '- Storage type: `%s`\n' "$STORAGE_TYPE"
    printf -- '- Target MAA level: `%s`\n' "${MAA_TARGET_LEVEL:-Unknown}"
    printf -- '- Candidate MAA level: `%s`\n' "${MAA_CANDIDATE_LEVEL:-Unknown}"
    printf -- '- Current evidenced MAA level: `%s`\n' "${MAA_EVIDENCED_LEVEL:-Unknown}"
    printf -- '- Readiness status: `%s`\n' "$readiness_status"
    printf -- '- Raw SQL evidence file: `%s`\n' "$evidence_file"
    printf -- '- Data Guard Broker FSFO evidence file: `%s`\n' "$dgmgrl_fsfo_file"
    printf "\n"
    printf "This report is a best-effort posture assessment, not an Oracle certification. It separates business target, topology candidate, and current evidenced MAA level so product presence alone does not overclaim HA/DR maturity.\n\n"
  } >"$report_file" || die "Unable to write MAA report file: $report_file"

  append_report_section "$report_file" "MAA Decision-Tree Result"
  {
    printf '| Field | Value |\n'
    printf '| --- | --- |\n'
    printf '| Target MAA level | `%s` |\n' "$(md_escape "${MAA_TARGET_LEVEL:-Unknown}")"
    printf '| Target basis | %s |\n' "$(md_escape "${MAA_TARGET_REASON:-Unknown}")"
    printf '| Target gaps to verify | %s |\n' "$(md_escape "${MAA_TARGET_GAPS:-none}")"
    printf '| Candidate MAA level | `%s` |\n' "$(md_escape "${MAA_CANDIDATE_LEVEL:-Unknown}")"
    printf '| Candidate basis | %s |\n' "$(md_escape "${MAA_CANDIDATE_REASON:-Unknown}")"
    printf '| Current evidenced MAA level | `%s` |\n' "$(md_escape "${MAA_EVIDENCED_LEVEL:-Unknown}")"
    printf '| Evidenced basis | %s |\n' "$(md_escape "${MAA_EVIDENCED_REASON:-Unknown}")"
    printf '| Fit-gap summary | %s |\n' "$(md_escape "${MAA_FIT_GAP_SUMMARY:-Unknown}")"
    printf '| Baseline readiness | `%s` |\n' "$(md_escape "$readiness_status")"
    printf '| Detection confidence | %s |\n' "$(md_escape "Medium: based on target-host SQL/GI evidence; application failover behavior, external monitoring, and measured business outage need confirmation.")"
  } >>"$report_file"

  append_report_section "$report_file" "Evidence Maturity Scorecard"
  {
    printf '| Domain | Score | Meaning |\n'
    printf '| --- | ---: | --- |\n'
    printf '| Business requirements | `%s` | RTO/RPO, criticality, outage class, and target context completeness. |\n' "${MAA_SCORE_BUSINESS:-0}"
    printf '| Backup and recovery | `%s` | ARCHIVELOG, RMAN coverage, corruption/recovery blockers, and measured recovery manifest evidence. |\n' "${MAA_SCORE_BACKUP:-0}"
    printf '| Local HA | `%s` | RAC/RAC One/local standby, service placement, client HA attributes, and measured local-failure drills. |\n' "${MAA_SCORE_LOCAL_HA:-0}"
    printf '| Data Guard / ADG / FSFO | `%s` | DG configuration, Broker/lag/role services, FSFO observer, and measured role/lag/failover drills. |\n' "${MAA_SCORE_DR:-0}"
    printf '| Application continuity | `%s` | Dedicated services, FAN/RLB/drain, AC/TAC/replay, and application/session validation evidence. |\n' "${MAA_SCORE_APP:-0}"
    printf '| Operations and evidence | `%s` | Audit retention, readiness/lifecycle evidence, runbook/report evidence, and repeatability. |\n' "${MAA_SCORE_OPERATIONS:-0}"
  } >>"$report_file"

  append_report_section "$report_file" "MAA Reference Model Used"
  {
    printf '| MAA level | Observable capabilities used by this report |\n'
    printf '| --- | --- |\n'
    printf '| Bronze | Single-instance or Oracle Restart style database with ARCHIVELOG, RMAN backup/recovery evidence, corruption checks, and basic restart/restore readiness. |\n'
    printf '| Silver | Bronze plus strong local HA using RAC/RAC One Node or explicitly local Data Guard standby, with service/client failover and application-aware continuity evidence. |\n'
    printf '| Gold | Silver plus Data Guard/Active Data Guard DR evidence, Broker/lag/role-services/FSFO where applicable, and measured role-transition/application behavior. |\n'
    printf '| Platinum | Gold plus Exadata/optimized platform and/or supported active replication patterns with seconds-class measured service behavior. |\n'
    printf '| Diamond | Extreme-availability active/global architecture such as 26ai/Exadata/GoldenGate or distributed patterns; supportability and measured evidence require manual confirmation. |\n'
  } >>"$report_file"

  append_report_section "$report_file" "Evidence Summary"
  {
    printf '| Area | Evidence |\n'
    printf '| --- | --- |\n'
    printf '| Database | Role `%s`, open mode `%s`, log mode `%s`, force logging `%s`, flashback `%s` |\n' \
      "$(md_escape "$(maa_value db_role)")" "$(md_escape "$(maa_value open_mode)")" \
      "$(md_escape "$(maa_value log_mode)")" "$(md_escape "$(maa_value force_logging)")" \
      "$(md_escape "$(maa_value flashback_on)")"
    printf '| Local HA | Cluster `%s`, cluster_database `%s`, instance parallel `%s`, GI managed `%s`, storage `%s` |\n' \
      "$(md_escape "$CLUSTER_TYPE")" "$(md_escape "$(maa_value cluster_database)")" \
      "$(md_escape "$(maa_value instance_parallel)")" "$(md_escape "$GI_MANAGED")" "$(md_escape "$STORAGE_TYPE")"
    printf '| Backup | Recent successful jobs 7d `%s`, failed jobs 7d `%s`, last success `%s`, datafiles without backup metadata `%s`, devices `%s` |\n' \
      "$(md_escape "$(maa_value recent_successful_backup_jobs_7d)")" \
      "$(md_escape "$(maa_value recent_failed_backup_jobs_7d)")" \
      "$(md_escape "$(maa_value last_successful_backup_time)")" \
      "$(md_escape "$(maa_value datafiles_without_backup_metadata)")" \
      "$(md_escape "$(maa_value backup_device_types)")"
    printf '| Data Guard | Remote standby destinations `%s`, valid destinations `%s`, FSFO `%s`, observer `%s`, transport lag `%s`, apply lag `%s` |\n' \
      "$(md_escape "$(maa_value remote_standby_dest_count)")" \
      "$(md_escape "$(maa_value valid_remote_standby_dest_count)")" \
      "$(md_escape "$(maa_value fsfo_status)")" "$(md_escape "$(maa_value fsfo_observer_present)")" \
      "$(md_escape "$(maa_value dataguard_transport_lag)")" "$(md_escape "$(maa_value dataguard_apply_lag)")"
    printf '| Storage/config | Control files `%s`, redo min members `%s`, redo groups with <2 members `%s`, FRA configured `%s`, FRA used `%s%%` |\n' \
      "$(md_escape "$(maa_value control_file_count)")" "$(md_escape "$(maa_value redo_min_members)")" \
      "$(md_escape "$(maa_value redo_groups_less_than_two_members)")" \
      "$(md_escape "$(maa_value fra_configured)")" "$(md_escape "$(maa_value fra_used_pct)")"
    printf '| Security | Wallet open rows `%s`, wallet not-open rows `%s`, encrypted tablespaces `%s`, TDE config `%s` |\n' \
      "$(md_escape "$(maa_value tde_wallet_open_count)")" \
      "$(md_escape "$(maa_value tde_wallet_not_open_count)")" \
      "$(md_escape "$(maa_value encrypted_tablespace_count)")" \
      "$(md_escape "$(maa_value tde_configuration)")"
    printf '| Application continuity / services | Replay-capable services `%s`, AC `%s`, TAC `%s`, missing AC/TAC `%s`, role-based srvctl services `%s` |\n' \
      "$(md_escape "$app_continuity")" \
      "$(md_escape "$(maa_value ac_service_count "$app_continuity")")" \
      "$(md_escape "$(maa_value tac_service_count 0)")" \
      "$(md_escape "$(maa_value service_without_ac_tac_count UNKNOWN)")" \
      "$(md_escape "$(maa_value srvctl_role_based_service_count UNKNOWN)")"
    printf '| ADG DML redirection | adg_redirect_dml `%s`, modifiable `%s` |\n' \
      "$(md_escape "$(maa_value adg_redirect_dml UNAVAILABLE)")" \
      "$(md_escape "$(maa_value adg_redirect_dml_modifiable UNAVAILABLE)")"
    printf '| Replication dictionary | capture processes `%s`, apply processes `%s` |\n' \
      "$(md_escape "$capture_count")" "$(md_escape "$apply_count")"
  } >>"$report_file"

  append_report_section "$report_file" "Best-Practice Checks"
  {
    printf '| Status | Area | Check | Evidence | Recommendation |\n'
    printf '| --- | --- | --- | --- | --- |\n'
  } >>"$report_file"

  if [[ "$(maa_value log_mode UNKNOWN)" == "ARCHIVELOG" ]]; then
    maa_append_check "$report_file" "OK" "Recoverability" "ARCHIVELOG enabled" "LOG_MODE=$(maa_value log_mode)" "Keep validating archived-log backup, restore, and gap handling."
  else
    maa_append_check "$report_file" "GAP" "Recoverability" "ARCHIVELOG enabled" "LOG_MODE=$(maa_value log_mode)" "Enable ARCHIVELOG before expecting meaningful point-in-time or DR recovery."
  fi
  if [[ "$(maa_value force_logging UNKNOWN)" == "YES" ]]; then
    maa_append_check "$report_file" "OK" "Data protection" "FORCE LOGGING enabled" "FORCE_LOGGING=$(maa_value force_logging)" "Keep FORCE LOGGING enabled for Data Guard/readiness unless an exception is explicitly approved."
  else
    maa_append_check "$report_file" "WARN" "Data protection" "FORCE LOGGING enabled" "FORCE_LOGGING=$(maa_value force_logging)" "Enable FORCE LOGGING before Data Guard or strict RPO validation."
  fi
  if maa_positive recent_successful_backup_jobs_7d && maa_zero datafiles_without_backup_metadata; then
    maa_append_check "$report_file" "OK" "Backup" "Recent complete RMAN backup coverage" "jobs_7d=$(maa_value recent_successful_backup_jobs_7d), no_backup_files=$(maa_value datafiles_without_backup_metadata)" "Continue scheduled restore preview/validate drills and retain off-host copies."
  else
    maa_append_check "$report_file" "GAP" "Backup" "Recent complete RMAN backup coverage" "jobs_7d=$(maa_value recent_successful_backup_jobs_7d), no_backup_files=$(maa_value datafiles_without_backup_metadata)" "Fix backup coverage before destructive drills; run RMAN backup, preview, and validate."
  fi
  if maa_zero recent_failed_backup_jobs_7d; then
    maa_append_check "$report_file" "OK" "Backup" "No recent failed RMAN jobs" "failed_jobs_7d=$(maa_value recent_failed_backup_jobs_7d)" "Continue monitoring failed backup jobs and alerting."
  else
    maa_append_check "$report_file" "WARN" "Backup" "No recent failed RMAN jobs" "failed_jobs_7d=$(maa_value recent_failed_backup_jobs_7d)" "Review failed RMAN jobs and confirm they do not represent missing required backup windows."
  fi
  if maa_zero recover_file_count && maa_zero block_corruption_count; then
    maa_append_check "$report_file" "OK" "Health" "No media recovery or block corruption rows" "recover_file=$(maa_value recover_file_count), block_corruption=$(maa_value block_corruption_count)" "Keep periodic validation and corruption monitoring."
  else
    maa_append_check "$report_file" "GAP" "Health" "No media recovery or block corruption rows" "recover_file=$(maa_value recover_file_count), block_corruption=$(maa_value block_corruption_count)" "Resolve recovery/corruption rows before measuring MAA readiness."
  fi
  if [[ "$(maa_value flashback_on UNKNOWN)" == "YES" ]]; then
    maa_append_check "$report_file" "OK" "Recovery" "Flashback Database enabled" "FLASHBACK_ON=$(maa_value flashback_on)" "Use guaranteed restore points deliberately for risky changes and validate retention."
  else
    maa_append_check "$report_file" "WARN" "Recovery" "Flashback Database enabled" "FLASHBACK_ON=$(maa_value flashback_on)" "Consider Flashback Database for faster logical-error and failed-change recovery where storage allows."
  fi
  if maa_positive remote_standby_dest_count || [[ "$(maa_value db_role UNKNOWN)" != "PRIMARY" && "$(maa_value db_role UNKNOWN)" != "UNKNOWN" ]]; then
    maa_append_check "$report_file" "OK" "Disaster recovery" "Data Guard topology detected" "role=$(maa_value db_role), standby_dests=$(maa_value remote_standby_dest_count), valid=$(maa_value valid_remote_standby_dest_count)" "Validate switchover/failover, FSFO, transport/apply lag, and application reconnection."
  else
    maa_append_check "$report_file" "GAP" "Disaster recovery" "Data Guard topology detected" "role=$(maa_value db_role), standby_dests=$(maa_value remote_standby_dest_count)" "Gold or higher MAA posture needs Data Guard/Active Data Guard or equivalent DR architecture."
  fi
  if [[ "$(maa_value fsfo_status UNKNOWN)" =~ SYNCHRONIZED|TARGET|PRIMARY|READY|ENABLED ]] || [[ "$(maa_value fsfo_observer_present UNKNOWN)" == "YES" ]]; then
    maa_append_check "$report_file" "OK" "Disaster recovery" "Fast-Start Failover evidence" "FSFO=$(maa_value fsfo_status), observer=$(maa_value fsfo_observer_present)" "Keep testing observer placement and failover/failback runbooks."
  else
    maa_append_check "$report_file" "INFO" "Disaster recovery" "Fast-Start Failover evidence" "FSFO=$(maa_value fsfo_status), observer=$(maa_value fsfo_observer_present)" "For strict RTO/RPO, evaluate FSFO with appropriate protection mode and observer design."
  fi
  if [[ "${MAA_LOCAL_HA_CANDIDATE:-0}" -eq 1 ]]; then
    maa_append_check "$report_file" "OK" "Local HA" "RAC/RAC One/local standby candidate" "cluster=${CLUSTER_TYPE}, cluster_database=$(maa_value cluster_database), parallel=$(maa_value instance_parallel), standby_scope=${MAA_STANDBY_SCOPE:-unknown}" "Validate service placement, FAN/ONS, Application Continuity, and measured local-failure drills before claiming Silver evidenced."
  else
    maa_append_check "$report_file" "INFO" "Local HA" "RAC/RAC One/local standby candidate" "cluster=${CLUSTER_TYPE}, cluster_database=$(maa_value cluster_database), standby_scope=${MAA_STANDBY_SCOPE:-unknown}" "Silver local HA normally requires RAC/RAC One Node or an explicitly local standby plus service/client failover design."
  fi
  if [[ "$app_continuity" =~ ^[0-9]+$ && "$app_continuity" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "Application continuity" "AC-style service metadata" "services=$(maa_value application_continuity_service_count)" "Validate replay safety with application teams and planned/unplanned failover drills."
  else
    maa_append_check "$report_file" "INFO" "Application continuity" "AC-style service metadata" "services=$(maa_value application_continuity_service_count)" "For Silver/Platinum readiness, review services, drivers, FAN/ONS, TAC/AC, and request boundaries."
  fi
  if [[ "$(maa_value redo_min_members 0)" =~ ^[0-9]+$ && "$(maa_value redo_min_members 0)" -ge 2 && "$(maa_value control_file_count 0)" =~ ^[0-9]+$ && "$(maa_value control_file_count 0)" -ge 2 ]]; then
    maa_append_check "$report_file" "OK" "File redundancy" "Control file and redo multiplexing" "control_files=$(maa_value control_file_count), redo_min_members=$(maa_value redo_min_members)" "Keep members separated across failure domains where possible."
  elif [[ "$STORAGE_TYPE" =~ ^FEX && "$(maa_value redo_min_members 0)" =~ ^[0-9]+$ && "$(maa_value redo_min_members 0)" -ge 2 && "$(maa_value control_file_count 0)" == "1" ]]; then
    maa_append_check "$report_file" "INFO" "File redundancy" "FEX control-file posture" "control_files=$(maa_value control_file_count), redo_min_members=$(maa_value redo_min_members), storage=${STORAGE_TYPE}" "OCI FEX exposes provider-managed @... file handles and may not expose a host byte-copy path for manual control-file multiplexing. Validate control-file autobackups, fresh baseline backups, provider storage redundancy, and use a provider-approved offline byte-copy or CREATE CONTROLFILE runbook before attempting active multiplexing."
  else
    maa_append_check "$report_file" "WARN" "File redundancy" "Control file and redo multiplexing" "control_files=$(maa_value control_file_count), redo_min_members=$(maa_value redo_min_members), redo_under2=$(maa_value redo_groups_less_than_two_members)" "Multiplex control files and redo members across independent storage failure domains."
  fi
  if [[ "$(maa_value tde_wallet_not_open_count 0)" == "0" && "$(maa_value encrypted_tablespace_count 0)" != "0" ]]; then
    maa_append_check "$report_file" "OK" "Security" "TDE wallet open for encrypted data" "wallet_open=$(maa_value tde_wallet_open_count), encrypted_tbs=$(maa_value encrypted_tablespace_count)" "Keep wallet backups synchronized across RAC/Data Guard sites."
  elif [[ "$(maa_value encrypted_tablespace_count 0)" == "0" ]]; then
    maa_append_check "$report_file" "INFO" "Security" "TDE wallet open for encrypted data" "encrypted_tbs=0" "Confirm whether encryption is required by policy, compliance, or cloud-service defaults."
  else
    maa_append_check "$report_file" "GAP" "Security" "TDE wallet open for encrypted data" "wallet_not_open=$(maa_value tde_wallet_not_open_count), encrypted_tbs=$(maa_value encrypted_tablespace_count)" "Open/repair keystore state and validate encrypted tablespace and backup access."
  fi

  append_service_awareness_sections "$report_file"

  append_report_section "$report_file" "SLA / RTO / RPO Planning Context"
  {
    printf '| Requirement | Supplied value |\n'
    printf '| --- | --- |\n'
    printf '| Application | `%s` |\n' "$(md_escape "${MAA_APP_NAME:-not supplied}")"
    printf '| Local unplanned RTO | `%s` |\n' "$(md_escape "${MAA_LOCAL_RTO:-not supplied}")"
    printf '| Local unplanned RPO | `%s` |\n' "$(md_escape "${MAA_LOCAL_RPO:-not supplied}")"
    printf '| Disaster/site RTO | `%s` |\n' "$(md_escape "${MAA_DR_RTO:-not supplied}")"
    printf '| Disaster/site RPO | `%s` |\n' "$(md_escape "${MAA_DR_RPO:-not supplied}")"
    printf '| Planned maintenance RTO | `%s` |\n' "$(md_escape "${MAA_PLANNED_RTO:-not supplied}")"
    printf '| Planned maintenance RPO | `%s` |\n' "$(md_escape "${MAA_PLANNED_RPO:-not supplied}")"
    printf '| Criticality | `%s` |\n' "$(md_escape "${MAA_CRITICALITY:-not supplied}")"
    printf '| Local HA target | `%s` |\n' "$(md_escape "${MAA_LOCAL_HA_TARGET:-not supplied}")"
    printf '| DR required | `%s` |\n' "$(md_escape "${MAA_DR_REQUIRED:-not supplied}")"
    printf '| Automatic failover required | `%s` |\n' "$(md_escape "${MAA_AUTOMATIC_FAILOVER_REQUIRED:-not supplied}")"
    printf '| Active-active required | `%s` |\n' "$(md_escape "${MAA_ACTIVE_ACTIVE_REQUIRED:-not supplied}")"
    printf '| Platform hint | `%s` |\n' "$(md_escape "${MAA_PLATFORM_HINT:-not supplied}")"
    printf '| Standby scope | `%s` |\n\n' "$(md_escape "${MAA_STANDBY_SCOPE:-unknown}")"
    printf "Preliminary recommendation hint: %s\n" "$sla_hint"
  } >>"$report_file"

  append_report_section "$report_file" "Suggested CrashSimulator Validation Coverage"
  {
    printf '| Objective | Suggested drills |\n'
    printf '| --- | --- |\n'
    printf '| Bronze backup/restart readiness | Health check, config report, scenarios `5`, `6`, `25`, `26`, `59`, and timed restore-preview/validate runs. |\n'
    printf '| Silver local HA readiness | Service/instance relocation or restart drills such as `55` and `56`, plus client FAN/ONS/Application Continuity validation. |\n'
    printf '| Gold DR readiness | Data Guard transport/apply, switchover/failover, FSFO, archive gap, and standby recovery drills such as `50`, `51`, `52`, `59`. |\n'
    printf '| Platinum/Diamond application continuity | GoldenGate/active-active or sharding failover, conflict handling, zero-downtime planned maintenance, and application transaction replay tests. |\n'
  } >>"$report_file"

  append_report_section "$report_file" "References"
  {
    printf -- '- Oracle MAA Reference Architectures Overview: https://docs.oracle.com/en/database/oracle/oracle-database/26/haiad/maa_overview.html\n'
    printf -- '- Oracle HA requirements, RTO/RPO, and MAA architecture mapping: https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/ha-requirements-architecture.html\n'
    printf -- '- User RTO/RPO planning reference: https://oraclemaa.com/from-downtime-to-data-loss-getting-rto-and-rpo-right-for-high-availability-and-disaster-recovery\n'
    printf -- '- FSFO observer placement reference: https://www.ludovicocaldara.net/blog/video-where-should-i-put-the-observer-in-a-fast-start-failover-configuration/\n'
  } >>"$report_file"

  append_report_section "$report_file" "Raw MAA Evidence"
  {
    printf 'Evidence file: `%s`\n\n' "$evidence_file"
    printf '```text\n'
    sed -n '/^CSIM_MAA|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"

  append_report_file "$report_file" "Data Guard Broker Evidence" "$dgmgrl_fsfo_file"
  if command -v srvctl >/dev/null 2>&1 && [[ -n "$DB_UNIQUE_NAME" ]]; then
    append_report_command "$report_file" "srvctl Database And Service Evidence" bash -lc "srvctl config database -d '${DB_UNIQUE_NAME}' 2>&1; srvctl status database -d '${DB_UNIQUE_NAME}' 2>&1; srvctl config service -d '${DB_UNIQUE_NAME}' 2>&1; srvctl status service -d '${DB_UNIQUE_NAME}' 2>&1"
  fi

  echo "MAA readiness report generated: ${report_file}"
  echo "Target MAA level: ${MAA_TARGET_LEVEL:-Unknown}"
  echo "Candidate MAA level: ${MAA_CANDIDATE_LEVEL:-Unknown}"
  echo "Current evidenced MAA level: ${MAA_EVIDENCED_LEVEL:-Unknown}"
  echo "Readiness status: ${readiness_status}"
  maybe_render_html "$report_file"
}

run_service_review() {
  discover_environment
  ensure_sqlplus

  local report_file sql_file evidence_file srvctl_service_file dgmgrl_fsfo_file generated_at
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  report_file="${LOG_DIR}/crashsim_service_review_${RUN_ID}.md"
  sql_file="${LOG_DIR}/crashsim_service_review_${RUN_ID}.sql"
  evidence_file="${LOG_DIR}/crashsim_service_review_${RUN_ID}.evidence"
  srvctl_service_file="${LOG_DIR}/crashsim_service_review_${RUN_ID}_srvctl_services.out"
  dgmgrl_fsfo_file="${LOG_DIR}/crashsim_service_review_${RUN_ID}_dgmgrl_fsfo.out"

  write_maa_assessment_sql_file "$sql_file"
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "Service review SQL failed: $sql_file (evidence: $evidence_file)"
  parse_maa_evidence_file "$evidence_file"
  collect_srvctl_service_evidence "$srvctl_service_file"
  collect_maa_dgmgrl_fsfo_evidence "$dgmgrl_fsfo_file"

  {
    printf "# CrashSimulator Oracle Service HA Best-Practice Review\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Database: `%s`\n' "$(maa_value db_name "$DB_NAME")"
    printf -- '- DB unique name: `%s`\n' "$(maa_value db_unique_name "$DB_UNIQUE_NAME")"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(maa_value db_role "$DB_ROLE")" "$(maa_value open_mode "$DB_OPEN_MODE")"
    printf -- '- CDB: `%s`\n' "$(maa_value cdb "$DB_CDB")"
    printf -- '- Cluster type: `%s`\n' "$CLUSTER_TYPE"
    printf -- '- Storage type: `%s`\n' "$STORAGE_TYPE"
    printf -- '- SQL evidence file: `%s`\n' "$evidence_file"
    printf -- '- srvctl service evidence file: `%s`\n' "$srvctl_service_file"
    printf -- '- Data Guard Broker FSFO evidence file: `%s`\n' "$dgmgrl_fsfo_file"
    printf "\n"
    printf "This report is read-only. It reviews Oracle Database service metadata, AC/TAC readiness signals, FAN/client HA attributes, Data Guard FSFO posture, Active Data Guard DML redirection configuration, and role-based service evidence when srvctl is available.\n"
  } >"$report_file" || die "Unable to write service review file: $report_file"

  append_service_awareness_sections "$report_file"

  append_report_section "$report_file" "Recommended Validation Drills"
  {
    printf '| Objective | Suggested validation |\n'
    printf '| --- | --- |\n'
    printf '| AC/TAC request replay | Run planned service relocation and scenario `55`/`56`; verify client replay, Transaction Guard outcomes, and application smoke tests. |\n'
    printf '| FAN and service draining | Stop/start or relocate one service through srvctl; confirm connection pools receive FAN/ONS events and drain gracefully. |\n'
    printf '| Data Guard role services | Switchover/failover in a lab; confirm PRIMARY services start only on the new primary and ADG read services start only on the standby role. |\n'
    printf '| FSFO | Validate observer placement, failover threshold, failover target, automatic failover, reinstate, and failback runbooks. |\n'
    printf '| ADG DML redirection | On an ADG standby, test approved redirected DML paths separately from read-only services and measure primary impact. |\n'
  } >>"$report_file"

  append_report_section "$report_file" "Raw Service Evidence"
  {
    printf 'SQL evidence file: `%s`\n\n' "$evidence_file"
    printf '```text\n'
    sed -n '/^CSIM_MAA|/p' "$evidence_file"
    printf '```\n\n'
    printf 'srvctl service evidence file: `%s`\n\n' "$srvctl_service_file"
    printf '```text\n'
    cat "$srvctl_service_file" 2>/dev/null || true
    printf '```\n\n'
    printf 'Data Guard Broker FSFO evidence file: `%s`\n\n' "$dgmgrl_fsfo_file"
    printf '```text\n'
    cat "$dgmgrl_fsfo_file" 2>/dev/null || true
    printf '```\n'
  } >>"$report_file"

  if command -v srvctl >/dev/null 2>&1 && [[ -n "$DB_UNIQUE_NAME" ]]; then
    append_report_command "$report_file" "srvctl Service Status" srvctl status service -d "$DB_UNIQUE_NAME"
  fi
  append_report_file "$report_file" "Data Guard Broker FSFO Evidence" "$dgmgrl_fsfo_file"

  echo "Oracle service HA review generated: ${report_file}"
  maybe_render_html "$report_file"
}

