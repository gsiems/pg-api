CREATE OR REPLACE FUNCTION util_meta.snippet_resolve_id (
    a_id_param text default null,
    a_function_schema text default null,
    a_function_name text default null,
    a_resolve_id_params text[] default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function snippet_resolve_id generates the pl/pg-sql code snippet for calling a resolve ID function

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_id_param                     | in     | text       | The (name of the) parameter to set the resolved ID to  |
| a_function_schema              | in     | text       | The (name of the) schema to find the function in   |
| a_function_name                | in     | text       | The (name of the) kind of ID resolution function   |
| a_resolve_id_params            | in     | text       | The list of parameters for the ID resolution function |

*/
DECLARE

    l_resolve_id_params text[] ;
    idx integer ;

BEGIN

    FOR idx IN 1..array_length ( a_resolve_id_params, 1 ) LOOP
        l_resolve_id_params := array_append ( l_resolve_id_params, concat_ws ( ' ', a_resolve_id_params[idx], '=>', a_resolve_id_params[idx] ) ) ;
    END LOOP ;

    RETURN concat_ws ( util_meta.new_line (),
        util_meta.indent (1) || concat_ws ( ' ', a_id_param, ':=', a_function_schema || '.' || a_function_name, '(' ),
        util_meta.indent (2) || array_to_string ( l_resolve_id_params, ',' || util_meta.new_line () || util_meta.indent (2) ) || ' ) ;' ) ;

END ;
$$ ;
