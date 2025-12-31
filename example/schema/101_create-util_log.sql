/**
### Logging

[101_create-util_log](101_create-util_log.sql)

Setup [util_log](https://github.com/gsiems/pg-util_log) to provide persistent
logging for functions, procedures, and views.

*/

\connect example_db

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;


-- set the search path so dblink creates properly
SET search_path = public, pg_catalog ;

CREATE EXTENSION IF NOT EXISTS dblink SCHEMA public ;

SET search_path = pg_catalog, public ;

\unset ON_ERROR_STOP

DROP SCHEMA IF EXISTS util_log CASCADE ;

CREATE SCHEMA IF NOT EXISTS util_log ;

COMMENT ON SCHEMA util_log IS 'Schema and objects for logging database function and procedure calls' ;

ALTER SCHEMA util_log OWNER TO example_db_owner ;
GRANT USAGE ON SCHEMA util_log TO example_db_owner ;
REVOKE USAGE ON SCHEMA util_log FROM public ;

DROP SERVER IF EXISTS loopback_dblink CASCADE ;

CREATE SERVER loopback_dblink FOREIGN DATA WRAPPER dblink_fdw
    OPTIONS ( hostaddr '127.0.0.1', dbname 'example_db' ) ;

ALTER SERVER loopback_dblink OWNER TO example_db_owner ;

GRANT CONNECT ON DATABASE example_db TO example_db_logger ;

GRANT USAGE ON SCHEMA util_log TO example_db_logger ;

GRANT INSERT ON util_log.dt_proc_log TO example_db_logger ;

/**
Since the logging is using dblink as a loopback, the password for the linked
user and user mappings can be dynamically set/used.

*/
DO
$$
DECLARE
    r record ;
BEGIN
    FOR r IN (
        WITH x AS (
            -- upper case letters
            SELECT chr ( ( 65 + round ( random () * 25 ) )::integer ) AS x
                FROM generate_series ( 1, 26 )
            UNION
            -- lower case letters
            SELECT chr ( ( 97 + round ( random () * 25 ) )::integer )
                FROM generate_series ( 1, 26 )
            UNION
            -- numbers
            SELECT chr ( ( 48 + round ( random () * 9 ) )::integer )
                FROM generate_series ( 1, 10 )
        ),
        y AS (
            SELECT x AS chrs
                FROM x
                ORDER BY random ()
                LIMIT ( 20 + round ( random () * 10 ) )
        )
        SELECT 'example_db_logger' AS usr,
                array_to_string ( array_agg ( chrs ), '' ) AS passwd
            FROM y ) LOOP

        EXECUTE format ('ALTER ROLE %I LOGIN PASSWORD %L', r.usr, r.passwd ) ;

        EXECUTE format ('CREATE USER MAPPING FOR example_db_owner SERVER loopback_dblink
            OPTIONS ( user %L, password %L )', r.usr, r.passwd ) ;

        EXECUTE format ('CREATE USER MAPPING FOR CURRENT_USER SERVER loopback_dblink
            OPTIONS ( user %L, password %L )', r.usr, r.passwd ) ;

    END LOOP ;
END ;
$$ ;

\set ON_ERROR_STOP

-- Tables --------------------------------------------------------------
\i util_log/table/st_log_level.sql
\i util_log/table/dt_proc_log.sql
\i util_log/table/dt_last_logged.sql

-- Views ---------------------------------------------------------------
\i util_log/view/dv_proc_log.sql
\i util_log/view/dv_proc_log_today.sql
\i util_log/view/dv_proc_log_last_hour.sql
\i util_log/view/dv_proc_log_last_day.sql
\i util_log/view/dv_proc_log_last_week.sql

-- Functions -----------------------------------------------------------
\i util_log/function/dici.sql
\i util_log/function/manage_partitions.sql
\i util_log/function/update_last_logged.sql

-- Procedures ----------------------------------------------------------
\i util_log/procedure/log_to_dblink.sql
\i util_log/procedure/log_begin.sql
\i util_log/procedure/log_debug.sql
\i util_log/procedure/log_exception.sql
\i util_log/procedure/log_finish.sql
\i util_log/procedure/log_info.sql

-- Query bug -----------------------------------------------------------
\i util_log/function/query_bug.sql
