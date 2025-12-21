CREATE OR REPLACE FUNCTION util_meta._snip_log_params (
    a_logging_scope text DEFAULT NULL,
    a_parameters util_meta.ut_parameters DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function _snip_log_params generates the pl/pg-sql code snippet for logging a list of parameters (or variables)

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_parameters                   | in     | ut_parameters | The list of parameters to log                   |


*/
DECLARE

    l_log_lines text[] ;
    l_logging_scope text ;
BEGIN

    -- check that util_log schema exists
    IF NOT util_meta._is_valid_object ( 'util_log', 'log_begin', 'procedure' ) THEN
        RETURN NULL::text ;
    END IF ;

    l_logging_scope := coalesce ( a_logging_scope, 'begin' ) ;

    FOR l_idx IN 1..array_length ( a_parameters.names, 1 ) LOOP

        IF a_parameters.names[l_idx] = 'a_err' THEN
            NULL ;
        ELSIF a_parameters.datatypes[l_idx] = 'bytea' THEN
            l_log_lines := array_append ( l_log_lines, '''bytea''::text' ) ;
        ELSE
            l_log_lines := array_append ( l_log_lines, 'util_log.dici ( ' || a_parameters.names[l_idx] || ' )' ) ;
        END IF ;

    END LOOP ;

    RETURN concat_ws (
        util_meta._new_line (),
        '',
        util_meta._indent ( 1 ) || 'call util_log.log_' || l_logging_scope || ' (',
        util_meta._indent ( 2 )
            || array_to_string ( l_log_lines, ',' || util_meta._new_line () || util_meta._indent ( 2 ) )
            || ' ) ;' ) ;

END ;
$$ ;
