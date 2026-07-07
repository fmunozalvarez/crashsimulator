main() {
  register_scenarios
  register_adb_scenarios
  load_startup_config "$@"
  parse_args "$@"
  normalize_targets
  init_runtime
  audit_start

  case "$MODE" in
    discover)
      print_discovery
      ;;
    list)
      list_scenarios
      ;;
    doctor)
      run_doctor
      ;;
    first_run)
      run_first_run_guide
      ;;
    public_limitations)
      run_public_limitations_page
      ;;
    health)
      run_health_check
      ;;
    report)
      run_configuration_report
      ;;
    backup_report)
      run_backup_report
      ;;
    service_review)
      run_service_review
      ;;
    apex_ords_report)
      run_apex_ords_report
      ;;
    prepare_environment)
      run_prepare_environment
      ;;
    adb_readiness_report)
      run_adb_readiness_report
      ;;
    adb_scenarios)
      print_adb_scenario_catalog
      ;;
    adb_scenario_detail)
      [[ -n "$ADB_SCENARIO_ID" ]] || die "No ADB scenario id provided."
      print_adb_scenario_detail "$ADB_SCENARIO_ID"
      ;;
    baseline_backup)
      run_baseline_backup
      ;;
    audit_status)
      audit_status
      ;;
    audit_purge)
      purge_audit_logs
      ;;
    show_config)
      show_active_config
      ;;
    validate_config)
      validate_config_runtime || exit "$FAIL"
      ;;
    write_config_template)
      write_config_template "$CONFIG_TEMPLATE_FILE"
      ;;
    review)
      generate_review_index
      ;;
    review_topology)
      review_topology
      ;;
    show_artifact)
      [[ -n "$REVIEW_TARGET" ]] || die "No artifact reference provided."
      show_artifact "$REVIEW_TARGET"
      ;;
    render_html)
      [[ -n "$HTML_TARGET" ]] || die "No artifact reference provided."
      render_html_target "$HTML_TARGET"
      ;;
    maa_report)
      run_maa_report
      ;;
    resilience_scorecard)
      run_resilience_scorecard
      ;;
    validate)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      print_scenario_validation "$SCENARIO_ID"
      ;;
    validate_all)
      validate_all_scenarios
      ;;
    scenario_readiness_report)
      generate_scenario_readiness_report
      ;;
    scenario_lifecycle_report)
      generate_scenario_lifecycle_report
      ;;
    scenario_lifecycle_check)
      scenario_lifecycle_check
      ;;
    secret_scan)
      run_secret_scan
      ;;
    sanitize_artifacts)
      run_sanitize_artifacts
      ;;
    node_sync_check)
      run_node_sync_check
      ;;
    release_check)
      run_release_check
      ;;
    runbook)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      print_runbook_only "$SCENARIO_ID"
      ;;
    scenario)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      run_scenario "$SCENARIO_ID"
      ;;
    random)
      run_random_scenario
      ;;
    protect)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      protect_scenario "$SCENARIO_ID"
      ;;
    recover)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      recover_scenario "$SCENARIO_ID"
      ;;
    menu)
      echo "Starting CrashSimulator Guided Workflow menu..."
      echo "Trying target topology discovery for the menu header. This normally takes a few seconds on database hosts."
      echo "If SQL*Plus is unavailable, the menu still opens for ADB reports, ADB scenarios, review, and configuration."
      menu_discover_environment_optional
      interactive_menu
      ;;
    *)
      die "Unknown mode: $MODE"
      ;;
  esac

  maybe_refresh_resilience_scorecard "$MODE" "$SCENARIO_ID"
}

main "$@"
