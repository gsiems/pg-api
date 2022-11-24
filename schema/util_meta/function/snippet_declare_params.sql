CREATE OR REPLACE FUNCTION util_meta.snippet_declare_params (
    a_param_names text[] default null,
    a_datatypes text[] default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function snippet_declare_params generates the pl/pg-sql code snippet for declaring the local parameters for a function or procedure

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_param_names                  | in     | text[]     | The list of parameter names                        |
| a_datatypes                    | in     | text[]     | The list of the datatypes for the parameters       |

*/
DECLARE

    l_return text ;
    l_idx integer ;
    l_param_lines text[] ;

BEGIN

    FOR l_idx IN 1..array_length ( a_param_names, 1 ) LOOP
        IF a_param_names[l_idx] IS NOT NULL AND a_datatypes[l_idx] IS NOT NULL THEN
            l_param_lines := array_append ( l_param_lines, concat_ws ( ' ', a_param_names[l_idx], a_datatypes[l_idx], ';' ) ) ;
        END IF ;
    END LOOP ;

    RETURN concat_ws ( util_meta.new_line (),
        'DECLARE',
        '',
        util_meta.indent (1) || array_to_string ( l_param_lines, ',' || util_meta.new_line () || util_meta.indent (1) ) ) ;

END ;
$$ ;
