CREATE OR REPLACE FUNCTION plprofiler_client.save_dataset_from_local (
    a_opt_name text DEFAULT NULL::text,
    a_config plprofiler_client.ut_config DEFAULT NULL::plprofiler_client.ut_config,
    a_config_json json DEFAULT NULL::json,
    a_overwrite boolean DEFAULT false )
RETURNS void
LANGUAGE plpgsql
AS $$
/**
Function save_dataset_from_local

    "Aggregate the existing data found in pl_profiler_linestats_local
    and pl_profiler_callgraph_local into a new entry in *_saved."

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_opt_name                     | in     | text       | The name of the saved-dataset                      |
| a_config                       | in     | ut_config  |                                                    |
| a_config_json                  | in     | json       |                                                    |
| a_overwrite                    | in     | boolean    |                                                    |

Extracted from plprofiler.py save_dataset_from_local()
*/
DECLARE

    l_options text ;
    l_schema text ;
    l_row_count bigint ;

BEGIN

    perform plprofiler_client.set_search_path () ;

    l_schema := plprofiler_client.query_plprofiler_namespace ()::text ;

    IF a_overwrite THEN

        DELETE FROM pl_profiler_saved
            WHERE s_name = a_opt_name ;

        l_options := plprofiler_client.resolve_config_string (
            a_opt_name => a_opt_name,
            a_config => a_config,
            a_config_json => a_config_json ) ;

        INSERT INTO pl_profiler_saved (
                s_name,
                s_options,
                s_callgraph_overflow,
                s_functions_overflow,
                s_lines_overflow )
            VALUES (
                    a_opt_name,
                    l_options,
                    false,
                    false,
                    false ) ;

    END IF ;

    -- Added coalesce to func_result and func_args
    -- Added schema to fully qualify sequence name
    INSERT INTO pl_profiler_saved_functions (
            f_s_id,
            f_funcoid,
            f_schema,
            f_funcname,
            f_funcresult,
            f_funcargs )
        SELECT currval ( l_schema || '.pl_profiler_saved_s_id_seq' ) AS s_id,
                p.oid,
                n.nspname,
                p.proname,
                min (
                    CASE
                        WHEN p.prokind = 'p' THEN ''
                        ELSE coalesce ( pg_catalog.pg_get_function_result ( p.oid ), 'void' )
                        END
                    ) AS func_result,
                coalesce ( pg_catalog.pg_get_function_arguments ( p.oid ), 'none' ) AS func_args
            FROM pg_catalog.pg_proc p
            JOIN pg_catalog.pg_namespace n
                ON ( n.oid = p.pronamespace )
            WHERE p.oid IN (
                    SELECT *
                        FROM unnest ( pl_profiler_func_oids_local () )
                )
            GROUP BY s_id,
                p.oid,
                n.nspname,
                p.proname
            ORDER BY s_id,
                p.oid,
                n.nspname,
                p.proname ;

    GET diagnostics l_row_count = row_count ;

    IF l_row_count = 0 THEN
        RAISE EXCEPTION 'No function data to save found' ;
    END IF ;

    -- Added join on pg_catalog.pg_proc
    -- Added schema to fully qualify sequence name
    INSERT INTO pl_profiler_saved_linestats (
            l_s_id,
            l_funcoid,
            l_line_number,
            l_source,
            l_exec_count,
            l_total_time,
            l_longest_time )
        SELECT currval ( l_schema || '.pl_profiler_saved_s_id_seq' ) AS s_id,
                l.func_oid,
                l.line_number,
                coalesce ( s.source, '-- SOURCE NOT FOUND' ),
                sum ( l.exec_count ),
                sum ( l.total_time ),
                max ( l.longest_time )
            FROM pl_profiler_linestats_local () l
            JOIN pl_profiler_funcs_source ( pl_profiler_func_oids_local () ) s
                ON ( s.func_oid = l.func_oid
                    AND s.line_number = l.line_number )
            JOIN pg_catalog.pg_proc p
                ON ( p.oid = l.func_oid )
            GROUP BY s_id,
                l.func_oid,
                l.line_number,
                s.source
            ORDER BY s_id,
                l.func_oid,
                l.line_number ;

    GET diagnostics l_row_count = row_count ;

    IF l_row_count = 0 THEN
        RAISE EXCEPTION 'No plprofiler data to save' ;
    END IF ;

    -- Added schema to fully qualify sequence name
    INSERT INTO pl_profiler_saved_callgraph (
            c_s_id,
            c_stack,
            c_call_count,
            c_us_total,
            c_us_children,
            c_us_self )
        SELECT currval ( l_schema || '.pl_profiler_saved_s_id_seq' ) AS s_id,
                pl_profiler_get_stack ( stack ),
                sum ( call_count ),
                sum ( us_total ),
                sum ( us_children ),
                sum ( us_self )
            FROM pl_profiler_callgraph_local ()
            GROUP BY s_id,
                stack
            ORDER BY s_id,
                stack ;

END ;
$$ ;
