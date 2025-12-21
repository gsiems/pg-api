/*
NB that, since we are partitioning the dt_proc_log table by date, we
need to have a date column in the table.

*/
CREATE TABLE util_log.dt_proc_log (
    date_exec date default current_date,
    tmsp_exec timestamp with time zone default current_timestamp,
    client_address inet default inet_client_addr(),
    client_port integer default inet_client_port(),
    pid integer default pg_backend_pid(),
    log_level integer,
    obj_line_number integer,
    calling_obj_line_number integer,
    db_name name default current_catalog,
    username name default session_user,
    application_name text,
    obj_name text,
    calling_obj_name text,
    remarks text )
    PARTITION BY range ( date_exec ) ;

COMMENT ON TABLE util_log.dt_proc_log IS 'Database log entries.' ;
COMMENT ON COLUMN util_log.dt_proc_log.date_exec IS 'The date for the log entry.' ;
COMMENT ON COLUMN util_log.dt_proc_log.tmsp_exec IS 'The time of the log entry.' ;
COMMENT ON COLUMN util_log.dt_proc_log.client_address IS 'The IP address of the client connection that resulted in the log entry.' ;
COMMENT ON COLUMN util_log.dt_proc_log.client_port IS 'The port of the client connection that resulted in the log entry.' ;
COMMENT ON COLUMN util_log.dt_proc_log.pid IS 'The system process ID of the client connection.' ;
COMMENT ON COLUMN util_log.dt_proc_log.log_level IS 'The level, or importance, of the log entry.' ;
COMMENT ON COLUMN util_log.dt_proc_log.obj_line_number IS 'The line number in the procedure or fumction where the logging was called from.' ;
COMMENT ON COLUMN util_log.dt_proc_log.calling_obj_line_number IS 'The line number in the procedure or fumction that the logging function/procedure was called from.' ;
COMMENT ON COLUMN util_log.dt_proc_log.db_name IS 'The name of the database.' ;
COMMENT ON COLUMN util_log.dt_proc_log.username IS 'The username for the client connection.' ;
COMMENT ON COLUMN util_log.dt_proc_log.application_name IS 'The name of the client application (if made known).' ;
COMMENT ON COLUMN util_log.dt_proc_log.obj_name IS 'The function or procedure that performed the logging.' ;
COMMENT ON COLUMN util_log.dt_proc_log.calling_obj_name IS 'The function or procedure that called the logging function/procedure.' ;
COMMENT ON COLUMN util_log.dt_proc_log.remarks IS 'The information to log (such as calling arguments or SQL errors).' ;
