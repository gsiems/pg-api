CREATE OR REPLACE VIEW util_log.dv_proc_log_last_day
AS
SELECT row_number () OVER ( ORDER BY dpl.tmsp_exec DESC ) AS rn,
        dpl.date_exec,
        dpl.tmsp_exec,
        lead ( dpl.tmsp_exec, 1 ) OVER (
            PARTITION BY dpl.pid, dpl.username, dpl.client_address, dpl.client_port, dpl.date_exec
            ORDER BY dpl.date_exec, dpl.tmsp_exec ) - dpl.tmsp_exec AS exec_interval,
        dpl.db_name,
        dpl.username,
        dpl.client_address,
        dpl.client_port,
        dpl.application_name,
        dpl.pid,
        dpl.log_level,
        stl.name AS log_level_name,
        dpl.calling_obj_name,
        dpl.calling_obj_line_number,
        dpl.obj_name,
        dpl.obj_line_number,
        dpl.remarks
    FROM util_log.dt_proc_log dpl
    LEFT JOIN util_log.st_log_level stl
        ON ( stl.id = dpl.log_level )
    WHERE dpl.tmsp_exec > now () - '1 day'::interval
    ORDER BY dpl.tmsp_exec DESC ;

COMMENT ON VIEW util_log.dv_proc_log_last_day IS 'View of database log entries for the past 24 hours.' ;
