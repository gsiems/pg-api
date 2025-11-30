CREATE OR REPLACE FUNCTION util_meta.snippet_declare_variables (
    a_variables util_meta.ut_parameters DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function snippet_declare_variables generates the pl/pg-sql code snippet for declaring the local variables for a function or procedure

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_variables                    | in     | ut_parameters | The list of variables                           |

*/
DECLARE

    l_variable_lines text[] ;

BEGIN

    FOR l_idx IN 1..array_length ( a_variables.names, 1 ) LOOP
        IF a_variables.names[l_idx] IS NOT NULL AND a_variables.datatypes[l_idx] IS NOT NULL THEN
            l_variable_lines := array_append (
                l_variable_lines,
                concat_ws (
                    ' ',
                    a_variables.names[l_idx],
                    a_variables.datatypes[l_idx],
                    ';' ) ) ;
        END IF ;
    END LOOP ;

    RETURN concat_ws (
        util_meta.new_line (),
        'DECLARE',
        '',
        util_meta.indent ( 1 )
            || array_to_string ( l_variable_lines, util_meta.new_line () || util_meta.indent ( 1 ) ) ) ;

END ;
$$ ;
