whenever sqlerror exit sql.sqlcode
set pages 0 lines 32767 trimspool on tab off verify off feedback off heading off
set serveroutput on size unlimited

select 'CSIM_MAA|db_name|' || name from v$database;
select 'CSIM_MAA|db_unique_name|' || db_unique_name from v$database;
select 'CSIM_MAA|db_role|' || database_role from v$database;
select 'CSIM_MAA|open_mode|' || open_mode from v$database;
select 'CSIM_MAA|cdb|' || cdb from v$database;
select 'CSIM_MAA|log_mode|' || log_mode from v$database;
select 'CSIM_MAA|force_logging|' || force_logging from v$database;
select 'CSIM_MAA|flashback_on|' || flashback_on from v$database;
select 'CSIM_MAA|protection_mode|' || protection_mode from v$database;
select 'CSIM_MAA|protection_level|' || protection_level from v$database;
select 'CSIM_MAA|switchover_status|' || switchover_status from v$database;
select 'CSIM_MAA|fsfo_status|' || nvl(fs_failover_status, 'UNKNOWN') from v$database;
select 'CSIM_MAA|fsfo_target|' || nvl(fs_failover_current_target, 'NONE') from v$database;
select 'CSIM_MAA|fsfo_threshold|' || nvl(to_char(fs_failover_threshold), 'UNKNOWN') from v$database;
select 'CSIM_MAA|fsfo_observer_present|' || nvl(fs_failover_observer_present, 'UNKNOWN') from v$database;
select 'CSIM_MAA|dbid|' || dbid from v$database;
select 'CSIM_MAA|platform_name|' || platform_name from v$database;

select 'CSIM_MAA|instance_name|' || instance_name from v$instance;
select 'CSIM_MAA|host_name|' || host_name from v$instance;
select 'CSIM_MAA|version|' || version from v$instance;
select 'CSIM_MAA|version_major|' || regexp_substr(version, '^[0-9]+') from v$instance;
select 'CSIM_MAA|instance_status|' || status from v$instance;
select 'CSIM_MAA|instance_parallel|' || parallel from v$instance;
select 'CSIM_MAA|instance_thread|' || thread# from v$instance;

select 'CSIM_MAA|cluster_database|' || nvl(max(value), 'UNKNOWN')
from v$parameter
where name = 'cluster_database';
select 'CSIM_MAA|remote_login_passwordfile|' || nvl(max(value), 'UNKNOWN')
from v$parameter
where name = 'remote_login_passwordfile';
select 'CSIM_MAA|db_recovery_file_dest|' || nvl(max(value), 'NONE')
from v$parameter
where name = 'db_recovery_file_dest';
select 'CSIM_MAA|db_recovery_file_dest_size|' || nvl(max(display_value), 'UNKNOWN')
from v$parameter
where name = 'db_recovery_file_dest_size';
select 'CSIM_MAA|local_undo_enabled|' || nvl(max(value), 'UNKNOWN')
from v$parameter
where name = 'local_undo_enabled';
select 'CSIM_MAA|wallet_root|' || nvl(max(value), 'NONE')
from v$parameter
where name = 'wallet_root';
select 'CSIM_MAA|tde_configuration|' || nvl(max(value), 'NONE')
from v$parameter
where name = 'tde_configuration';
select 'CSIM_MAA|archive_lag_target|' || nvl(max(value), 'UNKNOWN')
from v$parameter
where name = 'archive_lag_target';
select 'CSIM_MAA|adg_redirect_dml|' || nvl(max(value), 'UNAVAILABLE')
from v$parameter
where name = 'adg_redirect_dml';
select 'CSIM_MAA|adg_redirect_dml_modifiable|' || nvl(max(issys_modifiable), 'UNAVAILABLE')
from v$parameter
where name = 'adg_redirect_dml';

select 'CSIM_MAA|control_file_count|' || count(*) from v$controlfile;
select 'CSIM_MAA|redo_group_count|' || count(*) from v$log;
select 'CSIM_MAA|redo_min_members|' || nvl(min(members), 0) from v$log;
select 'CSIM_MAA|redo_groups_less_than_two_members|' || count(*) from v$log where members < 2;
select 'CSIM_MAA|recover_file_count|' || count(*) from v$recover_file;
select 'CSIM_MAA|block_corruption_count|' || count(*) from v$database_block_corruption;
select 'CSIM_MAA|copy_corruption_count|' || count(*) from v$copy_corruption;
select 'CSIM_MAA|backup_corruption_count|' || count(*) from v$backup_corruption;
select 'CSIM_MAA|guaranteed_restore_point_count|' || count(*)
from v$restore_point
where guarantee_flashback_database = 'YES';

select 'CSIM_MAA|fra_configured|' ||
       case when count(*) > 0 and max(space_limit) > 0 then 'YES' else 'NO' end
from v$recovery_file_dest;
select 'CSIM_MAA|fra_used_pct|' ||
       nvl(to_char(round(max(space_used) / nullif(max(space_limit), 0) * 100, 2)), 'UNKNOWN')
from v$recovery_file_dest;
select 'CSIM_MAA|fra_reclaimable_pct|' ||
       nvl(to_char(round(max(space_reclaimable) / nullif(max(space_limit), 0) * 100, 2)), 'UNKNOWN')
from v$recovery_file_dest;

select 'CSIM_MAA|recent_successful_backup_jobs_7d|' || count(*)
from v$rman_backup_job_details
where start_time >= sysdate - 7
  and status like 'COMPLETED%';
select 'CSIM_MAA|recent_failed_backup_jobs_7d|' || count(*)
from v$rman_backup_job_details
where start_time >= sysdate - 7
  and status not like 'COMPLETED%';
select 'CSIM_MAA|last_successful_backup_time|' ||
       nvl(to_char(max(end_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$rman_backup_job_details
where status like 'COMPLETED%';
select 'CSIM_MAA|last_successful_backup_age_hours|' ||
       nvl(to_char(round((sysdate - max(end_time)) * 24, 1)), 'UNKNOWN')
from v$rman_backup_job_details
where status like 'COMPLETED%';
select 'CSIM_MAA|backup_device_types|' ||
       nvl((
         select listagg(output_device_type, ',') within group (order by output_device_type)
         from (
           select distinct nvl(output_device_type, 'UNKNOWN') output_device_type
           from v$rman_backup_job_details
           where start_time >= sysdate - 30
         )
       ), 'NONE')
from dual;
select 'CSIM_MAA|datafiles_without_backup_metadata|' || count(*)
from (
  select df.file#
  from v$datafile df
  left join v$backup_datafile bdf on bdf.file# = df.file#
  group by df.file#
  having max(bdf.completion_time) is null
);

select 'CSIM_MAA|remote_standby_dest_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and status <> 'INACTIVE';
select 'CSIM_MAA|valid_remote_standby_dest_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and status = 'VALID';
select 'CSIM_MAA|standby_dest_error_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and error is not null;
select 'CSIM_MAA|archive_gap_count|' || count(*) from v$archive_gap;
select 'CSIM_MAA|dataguard_stats_count|' || count(*) from v$dataguard_stats;
select 'CSIM_MAA|dataguard_transport_lag|' ||
       nvl(max(case when name = 'transport lag' then value end), 'UNKNOWN')
from v$dataguard_stats;
select 'CSIM_MAA|dataguard_apply_lag|' ||
       nvl(max(case when name = 'apply lag' then value end), 'UNKNOWN')
from v$dataguard_stats;

select 'CSIM_MAA|tde_wallet_open_count|' || count(*)
from v$encryption_wallet
where status = 'OPEN';
select 'CSIM_MAA|tde_wallet_not_open_count|' || count(*)
from v$encryption_wallet
where status <> 'OPEN';
select 'CSIM_MAA|encrypted_tablespace_count|' || count(*)
from dba_tablespaces
where encrypted = 'YES';

select 'CSIM_MAA|pdb_count|' ||
       case when (select cdb from v$database) = 'YES'
            then (select count(*) from v$pdbs where name <> 'PDB$SEED')
            else 0
       end
from dual;
select 'CSIM_MAA|pdb_not_open_rw_count|' ||
       case when (select cdb from v$database) = 'YES'
            then (select count(*) from v$pdbs where name <> 'PDB$SEED' and open_mode <> 'READ WRITE')
            else 0
       end
from dual;

declare
  l_service_view varchar2(30) := 'DBA_SERVICES';
  l_aq_column varchar2(30);
  l_count number;
  l_has_failover_type boolean;
  l_has_commit_outcome boolean;
  l_has_aq_notification boolean;
  l_has_goal boolean;
  l_has_clb_goal boolean;
  l_has_drain_timeout boolean;
  l_has_session_state boolean;
  l_has_failover_restore boolean;
  l_has_pdb boolean;
  l_ac_condition varchar2(2000) := '1=0';
  l_tac_condition varchar2(2000) := '1=0';
  l_replay_condition varchar2(2000) := '1=0';
  l_user_filter varchar2(1000) := q'[name not like 'SYS$%' and upper(name) not in ('XDB')]';

  function has_column(p_table_name varchar2, p_column_name varchar2) return boolean is
    l_count number;
  begin
    select count(*)
    into l_count
    from all_tab_columns
    where table_name = upper(p_table_name)
      and column_name = upper(p_column_name);
    return l_count > 0;
  exception
    when others then
      return false;
  end;

  procedure emit(p_key varchar2, p_value varchar2) is
  begin
    dbms_output.put_line('CSIM_MAA|' || p_key || '|' || nvl(p_value, 'UNKNOWN'));
  end;

  procedure emit_count(p_key varchar2, p_sql varchar2) is
    l_count number;
  begin
    execute immediate p_sql into l_count;
    emit(p_key, to_char(l_count));
  exception
    when others then
      emit(p_key, 'UNKNOWN');
  end;
begin
  l_has_failover_type := has_column(l_service_view, 'FAILOVER_TYPE');
  l_has_commit_outcome := has_column(l_service_view, 'COMMIT_OUTCOME');
  if has_column(l_service_view, 'AQ_HA_NOTIFICATION') then
    l_has_aq_notification := true;
    l_aq_column := 'aq_ha_notification';
  elsif has_column(l_service_view, 'AQ_HA_NOTIFICATIONS') then
    l_has_aq_notification := true;
    l_aq_column := 'aq_ha_notifications';
  else
    l_has_aq_notification := false;
    l_aq_column := null;
  end if;
  l_has_goal := has_column(l_service_view, 'GOAL');
  l_has_clb_goal := has_column(l_service_view, 'CLB_GOAL');
  l_has_drain_timeout := has_column(l_service_view, 'DRAIN_TIMEOUT');
  l_has_session_state := has_column(l_service_view, 'SESSION_STATE_CONSISTENCY');
  l_has_failover_restore := has_column(l_service_view, 'FAILOVER_RESTORE');
  l_has_pdb := has_column(l_service_view, 'PDB');

  emit('service_attribute_source', l_service_view);
  emit('service_failover_type_column', case when l_has_failover_type then 'YES' else 'NO' end);
  emit('service_commit_outcome_column', case when l_has_commit_outcome then 'YES' else 'NO' end);
  emit('service_aq_ha_notification_column', case when l_has_aq_notification then 'YES' else 'NO' end);
  emit('service_drain_timeout_column', case when l_has_drain_timeout then 'YES' else 'NO' end);
  emit('service_session_state_column', case when l_has_session_state then 'YES' else 'NO' end);

  if l_has_failover_type then
    l_ac_condition := l_ac_condition || q'[ or upper(nvl(failover_type,'')) = 'TRANSACTION']';
    l_tac_condition := l_tac_condition || q'[ or upper(nvl(failover_type,'')) = 'AUTO']';
    l_replay_condition := l_replay_condition || q'[ or upper(nvl(failover_type,'')) in ('TRANSACTION','AUTO')]';
  end if;
  if l_has_commit_outcome then
    l_ac_condition := l_ac_condition || q'[ or upper(nvl(commit_outcome,'')) in ('YES','TRUE')]';
    l_replay_condition := l_replay_condition || q'[ or upper(nvl(commit_outcome,'')) in ('YES','TRUE')]';
  end if;

  emit_count('service_total_count', 'select count(*) from ' || l_service_view);
  emit_count('service_user_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter);
  emit_count('ac_service_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter || ' and (' || l_ac_condition || ')');
  emit_count('tac_service_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter || ' and (' || l_tac_condition || ')');
  emit_count('application_continuity_service_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter || ' and (' || l_replay_condition || ')');
  emit_count('service_without_ac_tac_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter || ' and not (' || l_replay_condition || ')');

  if l_has_commit_outcome then
    emit_count('commit_outcome_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(commit_outcome,'')) in ('YES','TRUE')]');
  else
    emit('commit_outcome_service_count', 'UNKNOWN');
  end if;

  if l_has_aq_notification then
    emit_count('fan_notification_service_count', 'select count(*) from dba_services where name not like ''SYS$%'' and upper(name) not in (''XDB'') and upper(nvl(' || l_aq_column || ',''NO'')) in (''YES'',''TRUE'')');
  else
    emit('fan_notification_service_count', 'UNKNOWN');
  end if;

  if l_has_goal and l_has_clb_goal then
    emit_count('runtime_load_balancing_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and (upper(nvl(goal,'NONE')) <> 'NONE' or upper(nvl(clb_goal,'NONE')) <> 'NONE')]');
  elsif l_has_goal then
    emit_count('runtime_load_balancing_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(goal,'NONE')) <> 'NONE']');
  elsif l_has_clb_goal then
    emit_count('runtime_load_balancing_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(clb_goal,'NONE')) <> 'NONE']');
  else
    emit('runtime_load_balancing_service_count', 'UNKNOWN');
  end if;

  if l_has_drain_timeout then
    emit_count('drain_timeout_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and nvl(drain_timeout,0) > 0]');
  else
    emit('drain_timeout_service_count', 'UNKNOWN');
  end if;

  if l_has_session_state then
    emit_count('session_state_consistency_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(session_state_consistency,'NONE')) not in ('NONE','STATIC')]');
  else
    emit('session_state_consistency_service_count', 'UNKNOWN');
  end if;

  if l_has_failover_restore then
    emit_count('failover_restore_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(failover_restore,'NONE')) not in ('NONE','NO')]');
  else
    emit('failover_restore_service_count', 'UNKNOWN');
  end if;

  if l_has_pdb then
    emit_count('pdb_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and pdb is not null]');
  else
    emit('pdb_service_count', 'UNKNOWN');
  end if;

  begin
    execute immediate 'select count(*) from dba_capture' into l_count;
    emit('capture_process_count', to_char(l_count));
  exception
    when others then
      emit('capture_process_count', 'UNKNOWN');
  end;

  begin
    execute immediate 'select count(*) from dba_apply' into l_count;
    emit('apply_process_count', to_char(l_count));
  exception
    when others then
      emit('apply_process_count', 'UNKNOWN');
  end;
end;
/

exit
