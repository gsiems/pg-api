CREATE OR REPLACE PROCEDURE util_log.log_to_dblink (
    a_log_level integer,
    variadic a_args text[] )
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, util_log, public
AS $$
/**
Function log_to_dblink takes a logging level and a variable list of text values,
determines which function/procedure was called (and which function/procedure
called it (if applicable)) and uses dblink to log the results.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_log_level                    | in     | integer    | The logging level (per st_log_level)               |
| a_args                         | in     | text[]     | The list of elements to log                        |

*/
DECLARE

    l_stack text ;
    l_called text ;
    l_caller text ;
    l_calling_obj_name text ;
    l_obj_name text ;
    l_calling_obj_line_number text ;
    l_obj_line_number text ;
    x text ;
    i integer := 0 ;
    l_log_level integer ;
    l_cmd text ;
    has_conn boolean ;

BEGIN

    GET DIAGNOSTICS l_stack = PG_CONTEXT ;

    -- NOTICE:  --- Call Stack ---
    -- PL/pgSQL function util_log.log_entry(text[]) line 9 at GET DIAGNOSTICS
    -- SQL statement "CALL util_log.log_entry(util_log.dici(42))"
    -- PL/pgSQL function foo.proc_two() line 3 at CALL
    -- SQL statement "CALL foo.proc_two()"
    -- PL/pgSQL function foo.func_one() line 3 at CALL
    --
    -- The topmost "PL/pgSQL .." line should be the call to this,
    -- the second "PL/pgSQL .." line should be the callee,
    -- the third "PL/pgSQL .." line (if there is one) should be the caller

    FOREACH x IN ARRAY string_to_array ( l_stack, E'\n' ) LOOP
        IF starts_with ( x, 'PL/pgSQL'::text ) THEN
            i := i + 1 ;
            IF i = 3 THEN
                l_called := split_part ( x, 'PL/pgSQL function '::text, 2 ) ;

                l_obj_line_number := split_part ( l_called, ') line '::text, 2 ) ;
                l_obj_line_number := split_part ( l_obj_line_number, ' '::text, 1 ) ;

                l_obj_name := split_part ( l_called, ')'::text, 1 ) || ')' ;

            ELSIF i = 4 THEN
                l_caller := split_part ( x, 'PL/pgSQL function '::text, 2 ) ;

                l_calling_obj_line_number := split_part ( l_caller, ') line '::text, 2 ) ;
                l_calling_obj_line_number := split_part ( l_calling_obj_line_number, ' '::text, 1 ) ;

                l_calling_obj_name := split_part ( l_caller, ')'::text, 1 ) || ')' ;

                EXIT ;
            END IF ;
        END IF ;
    END LOOP ;

    IF l_obj_line_number IS NULL OR trim ( l_obj_line_number ) = '' THEN
        l_obj_line_number := 'null::integer' ;
    END IF ;

    IF l_calling_obj_line_number IS NULL OR trim ( l_calling_obj_line_number ) = '' THEN
        l_calling_obj_line_number := 'null::integer' ;
    END IF ;

    -- If the log entry is for the beginning of a function/procedure then
    -- check if the function/procedure being called is being called from
    -- another function/procedure or if it is being called as an entry point.
    l_log_level := a_log_level ;
    IF l_log_level = 30 AND l_calling_obj_name IS NULL THEN
        l_log_level := 20 ;
    END IF ;

    -- If desired to alter the logging verbosity, add/adjust as desired.
    -- Note the logging level values:
    --      10 => Exception
    --      20 => Entry
    --      30 => Begin
    --      40 => Info
    --      50 => Debug
    /*
    IF l_log_level > 20 THEN
        RETURN ;
    END IF ;
    */

    has_conn := 'logconn' = ANY ( dblink_get_connections () ) ;
    IF has_conn IS NULL OR NOT has_conn THEN
        PERFORM dblink_connect ( 'logconn', 'loopback_dblink' ) ;
    END IF ;

    l_cmd := '
    INSERT INTO util_log.dt_proc_log (
            date_exec,
            tmsp_exec,
            client_address,
            client_port,
            pid,
            log_level,
            obj_line_number,
            calling_obj_line_number,
            db_name,
            username,
            application_name,
            obj_name,
            calling_obj_name,
            remarks )
        SELECT current_date AS date_exec,
                current_timestamp AS tmsp_exec,
                psa.client_addr,
                psa.client_port,
                psa.pid,
                ' || ( coalesce ( l_log_level, 0 ) )::text || ' AS log_level,
                ' || l_obj_line_number || ' AS obj_line_number,
                ' || l_calling_obj_line_number || ' AS calling_obj_line_number,
                psa.datname AS db_name,
                psa.usename AS username,
                psa.application_name,
                ' || quote_nullable ( l_obj_name ) || ' AS obj_name,
                ' || quote_nullable ( l_calling_obj_name ) || ' AS calling_obj_name,
                ' || quote_literal ( array_to_string ( a_args, ', ' ) ) || ' AS remarks
            FROM pg_stat_activity psa
            WHERE psa.pid = ' || pg_backend_pid()::text || '
            LIMIT 1 ' ;

    PERFORM dblink_exec ( 'logconn', l_cmd ) ;

END ;
$$;
