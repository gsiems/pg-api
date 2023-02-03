CREATE OR REPLACE FUNCTION util_meta.snippet_log_params (
    a_param_names text[] default null,
    a_datatypes text[] default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function snippet_log_params generates the pl/pg-sql code snippet for logging the calling parameters to a function or procedure

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_param_names                  | in     | text[]     | The list of calling parameter names                |
| a_datatypes                    | in     | text[]     | The list of the datatypes for the parameters       |

*/
DECLARE

    l_log_lines text[] ;

BEGIN

    -- check that util_log schema exists
    IF NOT util_meta.is_valid_object ( 'util_log', 'log_begin', 'procedure' ) THEN
        RETURN null::text ;
    END IF ;

    FOR l_idx IN 1..array_length ( a_param_names, 1 ) LOOP

        IF a_param_names[l_idx] = 'a_err' THEN
            NULL ;
        ELSIF a_datatypes[l_idx] = 'bytea' THEN
            l_log_lines := array_append ( l_log_lines, '''bytea''::text' ) ;
        ELSE
            l_log_lines := array_append ( l_log_lines, 'util_log.dici ( ' || a_param_names[l_idx] || ' )' ) ;
        END IF ;

    END LOOP ;

    RETURN concat_ws ( util_meta.new_line (),
        '',
        util_meta.indent (1) || 'call util_log.log_begin (',
        util_meta.indent (2) || array_to_string ( l_log_lines, ',' || util_meta.new_line () || util_meta.indent (2) ) || ' ) ;' ) ;

END ;
$$ ;
