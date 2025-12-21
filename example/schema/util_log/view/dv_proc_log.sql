CREATE OR REPLACE VIEW util_log.dv_proc_log
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
    ORDER BY dpl.tmsp_exec DESC ;

COMMENT ON VIEW util_log.dv_proc_log IS 'View of database log entries.' ;

COMMENT ON COLUMN util_log.dv_proc_log.rn IS 'The row number of the log entry.' ;
COMMENT ON COLUMN util_log.dv_proc_log.date_exec IS 'The date for the log entry.' ;
COMMENT ON COLUMN util_log.dv_proc_log.tmsp_exec IS 'The time of the log entry.' ;
COMMENT ON COLUMN util_log.dv_proc_log.exec_interval IS 'The (estimated) time to execute the logged line.' ;
COMMENT ON COLUMN util_log.dv_proc_log.db_name IS 'The name of the database.' ;
COMMENT ON COLUMN util_log.dv_proc_log.username IS 'The username for the client connection.' ;
COMMENT ON COLUMN util_log.dv_proc_log.client_address IS 'The IP address of the client connection that resulted in the log entry.' ;
COMMENT ON COLUMN util_log.dv_proc_log.client_port IS 'The port of the client connection that resulted in the log entry.' ;
COMMENT ON COLUMN util_log.dv_proc_log.application_name IS 'The name of the client application (if made known).' ;
COMMENT ON COLUMN util_log.dv_proc_log.pid IS 'The system process ID of the client connection.' ;
COMMENT ON COLUMN util_log.dv_proc_log.log_level IS 'The level, or importance, of the log entry.' ;
COMMENT ON COLUMN util_log.dv_proc_log.log_level_name IS 'The name of the level, or importance, of the log entry.' ;
COMMENT ON COLUMN util_log.dv_proc_log.calling_obj_name IS 'The function or procedure that called the logging function/procedure.' ;
COMMENT ON COLUMN util_log.dv_proc_log.calling_obj_line_number IS 'The line number in the procedure or fumction that the logging function/procedure was called from.' ;
COMMENT ON COLUMN util_log.dv_proc_log.obj_name IS 'The function or procedure that performed the logging.' ;
COMMENT ON COLUMN util_log.dv_proc_log.obj_line_number IS 'The line number in the procedure or fumction where the logging was called from.' ;
COMMENT ON COLUMN util_log.dv_proc_log.remarks IS 'The information to log (such as calling arguments or SQL errors).' ;
