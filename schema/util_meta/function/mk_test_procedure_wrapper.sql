CREATE OR REPLACE FUNCTION util_meta.mk_test_procedure_wrapper (
    a_object_schema text DEFAULT NULL,
    a_object_name text DEFAULT NULL,
    a_test_schema text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/**
Function mk_test_procedure_wrapper generates a testing function for wrapping a database procedure

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the procedure to wrap |
| a_object_name                  | in     | text       | The (name of the) procedure to wrap                |
| a_test_schema                  | in     | text       | The (name of the) schema to create the wrapper function in |

*/
DECLARE

    r record ;
    r2 record ;

    l_column_names text[] ;
    l_column_name text ;
    l_func_name text ;

    l_func_params util_meta.ut_parameters ; -- calling parameters for the wrapping function
    l_local_params util_meta.ut_parameters ; -- local variables
    l_proc_params text[] ; -- list of the calling parameters for the wrapped procedure
    l_param_names text[] ; -- list of the parameter names for the wrapped procedure
    l_shadow_names text[] ; -- list of local variable names that shadow calling parameters
    l_shadow_init text[] ; -- for initializing the shadowed parameters to the matching function parameter values
    l_uses_logging boolean := false ;

    l_obj_noun text ;
    l_proc_base text ;
    l_proc_type text ;
    l_result text ;
    l_view_name text ;
    l_view_schema text ;
    l_where_cols text[] ;

BEGIN

    ----------------------------------------------------------------------------
    -- Ensure that the specified procedure exists
    IF NOT util_meta._is_valid_object ( a_object_schema, a_object_name, 'procedure' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    -- check that util_log schema exists
    l_uses_logging := util_meta._uses_logging () ;

    ----------------------------------------------------------------------------
    l_proc_base := regexp_replace ( regexp_replace ( a_object_name, '^priv', '' ), '^_', '' ) ;
    l_proc_type := split_part ( l_proc_base, '_', 1 ) ; -- insert, update, delete, upsert
    l_obj_noun := regexp_replace ( regexp_replace ( l_proc_base, '^' || l_proc_type || '_', '' ), '^rt_', '' ) ;
    l_func_name := concat_ws ( '__', a_object_schema, a_object_name ) ;

    ----------------------------------------------------------------------------
    IF l_proc_type IN ( 'insert', 'update', 'upsert' ) THEN

        l_local_params := util_meta._append_parameter (
            a_parameters => l_local_params,
            a_name => 'r',
            a_datatype => 'record' ) ;

    END IF ;

    FOR r IN (
        SELECT *
            FROM (
                VALUES
                    ( 'l_pg_cx' ),
                    ( 'l_pg_ed' ),
                    ( 'l_pg_ec' ),
                    ( 'l_label' )
                ) AS dat ( var_name ) ) LOOP

        l_local_params := util_meta._append_parameter (
            a_parameters => l_local_params,
            a_name => r.var_name,
            a_datatype => 'text' ) ;

    END LOOP ;

    ----------------------------------------------------------------------------
    FOR r IN (
        SELECT schema_name,
                object_name,
                object_type,
                param_name,
                data_type,
                param_default,
                param_direction,
                arg_position,
                local_var_name,
                column_name,
                comments
            FROM util_meta._calling_parameters (
                    a_object_schema => a_object_schema,
                    a_object_name => a_object_name,
                    a_object_type => 'procedure' ) ) LOOP

        l_param_names := array_append ( l_param_names, r.param_name ) ;

        IF r.param_direction IN ( 'inout', 'out' ) THEN

            l_local_params := util_meta._append_parameter (
                a_parameters => l_local_params,
                a_name => r.local_var_name,
                a_datatype => r.data_type ) ;

            l_shadow_names := array_append ( l_shadow_names, r.local_var_name ) ;

            IF r.param_name <> 'a_err' THEN
                l_shadow_init := array_append (
                    l_shadow_init,
                    util_meta._indent ( 1 ) || concat_ws (
                        ' ',
                        r.local_var_name,
                        ':=',
                        r.param_name,
                        ';' ) ) ;
            END IF ;

            l_proc_params := array_append (
                l_proc_params,
                util_meta._indent ( 2 ) || concat_ws (
                    ' ',
                    r.param_name,
                    '=>',
                    r.local_var_name ) ) ;

        ELSE

            l_proc_params := array_append (
                l_proc_params,
                util_meta._indent ( 2 ) || concat_ws (
                    ' ',
                    r.param_name,
                    '=>',
                    r.param_name ) ) ;

        END IF ;

        IF r.param_direction <> 'out' THEN

            l_func_params := util_meta._append_parameter (
                a_parameters => l_func_params,
                a_name => r.param_name,
                a_direction => 'in',
                a_datatype => r.data_type,
                a_description => r.comments ) ;

        END IF ;

    END LOOP ;

    l_func_params := util_meta._append_parameter (
        a_parameters => l_func_params,
        a_name => 'a_label',
        a_direction => 'in',
        a_datatype => 'text' ) ;

    l_func_params := util_meta._append_parameter (
        a_parameters => l_func_params,
        a_name => 'a_should_pass',
        a_direction => 'in',
        a_datatype => 'boolean' ) ;

    ----------------------------------------------------------------------------
    l_result := concat_ws (
        util_meta._new_line (),
        l_result,
        util_meta._snip_function_frontmatter (
            a_ddl_schema => a_test_schema,
            a_function_name => l_func_name,
            a_language => 'plpgsql',
            a_return_type => 'boolean',
            a_returns_set => false,
            a_calling_parameters => l_func_params ),
        util_meta._snip_declare_variables ( a_variables => l_local_params ),
        '',
        'BEGIN',
        '',
        util_meta._indent ( 1 ) || 'l_label := concat_ws ( '' '', ''pgTap test'', quote_ident ( a_label ) ) ;',
        '' ) ;

    IF l_uses_logging THEN
        l_result := concat_ws (
            util_meta._new_line (),
            l_result,
            util_meta._indent ( 1 ) || 'IF coalesce ( a_should_pass, true ) THEN',
            util_meta._indent ( 2 ) || 'call util_log.log_begin ( concat_ws ( '' '', l_label, ''should pass'' ) ) ;',
            util_meta._indent ( 1 ) || 'ELSE',
            util_meta._indent ( 2 ) || 'call util_log.log_begin ( concat_ws ( '' '', l_label, ''should fail'' ) ) ;',
            util_meta._indent ( 1 ) || 'END IF ;',
            '' ) ;
    END IF ;

    l_result := concat_ws (
        util_meta._new_line (),
        l_result,
        array_to_string ( l_shadow_init, util_meta._new_line () ),
        '' ) ;

    ----------------------------------------------------------------------------
    -- Add the procedure call
    IF l_proc_type IN ( 'insert', 'update', 'upsert', 'delete' ) THEN

        l_result := concat_ws (
            util_meta._new_line (),
            l_result,
            '',
            util_meta._indent ( 1 ) || concat_ws (
                ' ',
                'call',
                a_object_schema || '.' || a_object_name,
                '(' ),
            array_to_string ( l_proc_params, ',' || util_meta._new_line () ) || ' ) ;' ) ;

    END IF ;

    ----------------------------------------------------------------------------
    -- Add the local parameter checks
    -- check l_err first
    FOR idx IN 1..array_length ( l_shadow_names, 1 ) LOOP
        IF l_shadow_names[idx] = 'l_err' THEN

            l_result := concat_ws (
                util_meta._new_line (),
                l_result,
                '',
                util_meta._indent ( 1 ) || 'IF ' || l_shadow_names[idx] || ' IS NOT NULL THEN',
                util_meta._indent ( 2 ) || '--RAISE NOTICE E''%'', ' || l_shadow_names[idx] || ' ;' ) ;

            IF l_uses_logging THEN
                l_result := concat_ws (
                    util_meta._new_line (),
                    l_result,
                    util_meta._indent ( 2 )
                        || 'call util_log.log_info ( concat_ws ( '' '', l_label, ''failed'' ) ) ;' ) ;
            END IF ;

            l_result := concat_ws (
                util_meta._new_line (),
                l_result,
                util_meta._indent ( 2 ) || 'RETURN false ;',
                util_meta._indent ( 1 ) || 'END IF ;' ) ;

        END IF ;

    END LOOP ;

    -- check the rest
    FOR idx IN 1..array_length ( l_shadow_names, 1 ) LOOP
        IF l_shadow_names[idx] NOT IN ( 'r', 'l_err', 'l_pg_cx', 'l_pg_ed', 'l_pg_ec', 'l_label' ) THEN

            l_result := concat_ws (
                util_meta._new_line (),
                l_result,
                '',
                util_meta._indent ( 1 ) || 'IF ' || l_shadow_names[idx] || ' IS NULL THEN',
                util_meta._indent ( 2 ) || '--RAISE NOTICE ''' || l_shadow_names[idx] || ' is null'' ;' ) ;

            IF l_uses_logging THEN
                l_result := concat_ws (
                    util_meta._new_line (),
                    l_result,
                    util_meta._indent ( 2 )
                        || 'call util_log.log_info ( concat_ws ( '' '', l_label, ''failed'' ) ) ;' ) ;
            END IF ;

            l_result := concat_ws (
                util_meta._new_line (),
                l_result,
                util_meta._indent ( 2 ) || 'RETURN false ;',
                util_meta._indent ( 1 ) || 'END IF ;' ) ;

        END IF ;

    END LOOP ;

    ----------------------------------------------------------------------------
    -- Add the checks for new values
    IF l_proc_type IN ( 'insert', 'update', 'upsert' ) THEN

        ------------------------------------------------------------------------
        -- For insert, update, and upsert we want to add checks to ensure that the
        -- new table data matches the submitted data.
        -- First, find a matching view. Note that the view probably exists in the same
        -- schema as the procedure... probably
        FOR r IN (
            WITH pfx AS (
                SELECT prefix,
                        sort_order
                    FROM (
                        VALUES
                            ( 'dv_', 1 ),
                            ( 'rv_', 2 )
                        ) AS dat ( prefix, sort_order )
            ),
            x AS (
                SELECT obj.schema_name,
                        obj.object_name,
                        cardinality ( array (
                                SELECT *
                                    FROM unnest ( string_to_array ( obj.schema_name, '_' ) )
                                    WHERE unnest = ANY ( string_to_array ( a_object_schema, '_' ) )
                            ) ) AS cd,
                        pfx.sort_order
                    FROM util_meta.objects obj
                    CROSS JOIN pfx
                    WHERE obj.object_type = 'view'
                        AND obj.object_name = pfx.prefix || l_obj_noun
            ),
            y AS (
                SELECT schema_name,
                        object_name,
                        row_number () OVER ( PARTITION BY schema_name ORDER BY sort_order, cd ) AS rn
                    FROM x
            )
            SELECT schema_name,
                    object_name
                FROM y
                WHERE rn = 1 ) LOOP

            l_view_schema := r.schema_name ;
            l_view_name := r.object_name ;

        END LOOP ;

        -- If the view was found then search for the table
        IF l_view_name IS NOT NULL THEN

            FOR r IN (
                SELECT max ( schema_name ) AS table_schema,
                        object_name AS table_name,
                        count (*) AS kount
                    FROM util_meta.objects
                    WHERE object_name = regexp_replace ( l_view_name, '^([dr])v', '\1t' )
                        AND object_type = 'table'
                    GROUP BY object_name ) LOOP

                -- ASSERTION: If there is only one matching table then it is the one we want
                -- The table is used for determining the primary key columns to select against
                IF r.kount = 1 THEN

                    FOR r2 IN (
                        WITH v_col AS (
                            SELECT column_name,
                                    'a_' || column_name AS param_name,
                                    'l_' || column_name AS local_var_name,
                                    ordinal_position,
                                    is_pk
                                FROM util_meta.columns
                                WHERE schema_name = l_view_schema
                                    AND object_name = l_view_name
                                    AND 'a_' || column_name = ANY ( l_param_names )
                        ),
                        t_col AS (
                            SELECT column_name,
                                    is_pk
                                FROM util_meta.columns
                                WHERE schema_name = r.table_schema
                                    AND object_name = r.table_name
                                    --AND object_type = 'table'
                                    AND 'a_' || column_name = ANY ( l_param_names )
                        )
                        SELECT v_col.column_name,
                                v_col.param_name,
                                v_col.local_var_name,
                                coalesce ( t_col.is_pk, false ) AS is_pk
                            FROM v_col
                            LEFT JOIN t_col
                                ON ( t_col.column_name = v_col.column_name )
                            ORDER BY v_col.ordinal_position ) LOOP

                        IF r2.is_pk THEN

                            IF r2.local_var_name = ANY ( l_shadow_names ) THEN
                                l_where_cols := array_append (
                                    l_where_cols,
                                    concat_ws (
                                        ' ',
                                        r2.column_name,
                                        '=',
                                        r2.local_var_name ) ) ;
                            ELSE
                                l_where_cols := array_append (
                                    l_where_cols,
                                    concat_ws (
                                        ' ',
                                        r2.column_name,
                                        '=',
                                        r2.param_name ) ) ;
                            END IF ;

                        ELSE

                            l_column_names := array_append ( l_column_names, r2.column_name ) ;

                        END IF ;

                    END LOOP ;

                END IF ;

            END LOOP ;

        END IF ;

        IF array_length ( l_where_cols, 1 ) > 0 AND array_length ( l_column_names, 1 ) > 0 THEN

            -- NB: We select against the view based on the assertion that, if there are any transformations to the data,
            -- the view data/datatypes will better match the calling parameters data/datatypes
            l_result := concat_ws (
                util_meta._new_line (),
                l_result,
                '',
                util_meta._indent ( 1 ) || 'FOR r IN (',
                util_meta._indent ( 2 )
                    || 'SELECT '
                    || array_to_string ( l_column_names, ',' || util_meta._new_line () || util_meta._indent ( 4 ) ),
                util_meta._indent ( 3 ) || 'FROM ' || l_view_schema || '.' || l_view_name,
                util_meta._indent ( 3 )
                    || 'WHERE '
                    || array_to_string (
                        l_where_cols,
                        ',' || util_meta._new_line () || util_meta._indent ( 5 ) || 'AND ' )
                    || ' ) LOOP' ) ;

            FOREACH l_column_name IN array l_column_names LOOP

                l_result := concat_ws (
                    util_meta._new_line (),
                    l_result,
                    '',
                    util_meta._indent ( 2 )
                        || 'IF a_'
                        || l_column_name
                        || ' IS NOT NULL AND a_'
                        || l_column_name
                        || ' IS DISTINCT FROM r.'
                        || l_column_name
                        || ' THEN',
                    util_meta._indent ( 3 )
                        || 'RAISE NOTICE E'''
                        || l_column_name
                        || ' did not update. expected %, got %'', a_'
                        || l_column_name
                        || ', r.'
                        || l_column_name
                        || ' ;' ) ;

                IF l_uses_logging THEN
                    l_result := concat_ws (
                        util_meta._new_line (),
                        l_result,
                        util_meta._indent ( 3 )
                            || 'call util_log.log_info ( concat_ws ( '' '', l_label, ''failed'' ) ) ;' ) ;
                END IF ;

                l_result := concat_ws (
                    util_meta._new_line (),
                    l_result,
                    util_meta._indent ( 3 ) || 'RETURN false ;',
                    util_meta._indent ( 2 ) || 'END IF ;' ) ;

            END LOOP ;

            l_result := concat_ws (
                util_meta._new_line (),
                l_result,
                '',
                util_meta._indent ( 1 ) || 'END LOOP ;' ) ;

        ELSE

            l_result := concat_ws (
                util_meta._new_line (),
                l_result,
                '',
                '-- TODO: could not resolve the table/view meta-data for reviewing data changes',
                '' ) ;

        END IF ;

    -- ELSIF l_proc_type = 'delete' THEN
    -- TODO: for delete procedures ensure that the delete succeeded

    END IF ;

    --------------------------------------------------------------------
    -- end-matter
    l_result := concat_ws ( util_meta._new_line (), l_result, '' ) ;

    IF l_uses_logging THEN
        l_result := concat_ws (
            util_meta._new_line (),
            l_result,
            util_meta._indent ( 1 ) || 'call util_log.log_info ( concat_ws ( '' '', l_label, ''passed'' ) ) ;' ) ;
    END IF ;

    l_result := concat_ws (
        util_meta._new_line (),
        l_result,
        util_meta._indent ( 1 ) || 'RETURN true ;',
        '',
        'EXCEPTION',
        util_meta._indent ( 1 ) || 'WHEN others THEN',
        util_meta._indent ( 2 ) || 'GET STACKED DIAGNOSTICS l_pg_cx = PG_CONTEXT,',
        util_meta._indent ( 8 ) || 'l_pg_ed = PG_EXCEPTION_DETAIL,',
        util_meta._indent ( 8 ) || 'l_pg_ec = PG_EXCEPTION_CONTEXT ;',
        util_meta._indent ( 2 )
            || 'l_err := format ( ''%s - %s:\n    %s\n     %s\n   %s'', SQLSTATE, SQLERRM, l_pg_cx, l_pg_ed, l_pg_ec ) ;',
        util_meta._indent ( 2 ) || 'call util_log.log_exception ( l_err ) ;',
        util_meta._indent ( 2 ) || 'RAISE NOTICE E''EXCEPTION: %'', l_err ;' ) ;

    IF l_uses_logging THEN
        l_result := concat_ws (
            util_meta._new_line (),
            l_result,
            util_meta._indent ( 2 ) || 'call util_log.log_info ( concat_ws ( '' '', l_label, ''failed'' ) ) ;' ) ;
    END IF ;

    l_result := concat_ws (
        util_meta._new_line (),
        l_result,
        util_meta._indent ( 2 ) || 'RETURN false ;',
        'END ;',
        '$' || '$ ;' ) ;

    RETURN util_meta._cleanup_whitespace ( l_result ) ;

END ;
$$ ;
