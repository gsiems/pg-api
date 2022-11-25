CREATE OR REPLACE FUNCTION util_meta.snippet_declare_variables (
    a_var_names text[] default null,
    a_var_datatypes text[] default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function snippet_declare_variables generates the pl/pg-sql code snippet for declaring the local variables for a function or procedure

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_var_names               | in     | text[]     | The list of variable names                         |
| a_var_datatypes           | in     | text[]     | The list of the datatypes for the variables        |

*/
DECLARE

    l_return text ;
    l_idx integer ;
    l_variable_lines text[] ;

BEGIN

    FOR l_idx IN 1..array_length ( a_var_names, 1 ) LOOP
        IF a_var_names[l_idx] IS NOT NULL AND a_var_datatypes[l_idx] IS NOT NULL THEN
            l_variable_lines := array_append ( l_variable_lines, concat_ws ( ' ', a_var_names[l_idx], a_var_datatypes[l_idx], ';' ) ) ;
        END IF ;
    END LOOP ;

    RETURN concat_ws ( util_meta.new_line (),
        'DECLARE',
        '',
        util_meta.indent (1) || array_to_string ( l_variable_lines, ',' || util_meta.new_line () || util_meta.indent (1) ) ) ;

END ;
$$ ;
