CREATE TABLE util_log.dt_last_logged (
    tmsp_first_logged timestamp with time zone,
    tmsp_last_logged timestamp with time zone,
    logged_count bigint,
    username name,
    application_name text,
    obj_name text,
    calling_obj_name text,
    CONSTRAINT dt_last_exec_pk PRIMARY KEY ( username, application_name, obj_name, calling_obj_name ) ) ;

COMMENT ON TABLE util_log.dt_last_logged IS 'Log the last time that a function, procedure, (or maybe even query) was logged, and by whom, for the purpose of understanding code usage and identifying potentially unused functions and procedures' ;

COMMENT ON COLUMN util_log.dt_last_logged.tmsp_first_logged IS 'The timestamp of the oldest log entry' ;
COMMENT ON COLUMN util_log.dt_last_logged.tmsp_last_logged IS 'The timestamp of the most recent log entry' ;
COMMENT ON COLUMN util_log.dt_last_logged.logged_count IS 'The count of log entries found between the tmsp_first_logged and the tmsp_last_logged' ;
COMMENT ON COLUMN util_log.dt_last_logged.username IS 'The username for the client connection.' ;
COMMENT ON COLUMN util_log.dt_last_logged.application_name IS 'The name of the client application (if made known).' ;
COMMENT ON COLUMN util_log.dt_last_logged.obj_name IS 'The function or procedure that performed the logging.' ;
COMMENT ON COLUMN util_log.dt_last_logged.calling_obj_name IS 'The function or procedure that called the logging function/procedure.' ;
