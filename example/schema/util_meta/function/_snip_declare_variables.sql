CREATE OR REPLACE FUNCTION util_meta._snip_declare_variables (
    a_variables util_meta.ut_parameters DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function _snip_declare_variables generates the pl/pg-sql code snippet for declaring the local variables for a function or procedure

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_variables                    | in     | ut_parameters | The list of variables                           |

*/
DECLARE

    l_variable_lines text[] ;
    l_variable_line text ;

BEGIN

    FOR l_idx IN 1..array_length ( a_variables.names, 1 ) LOOP
        IF a_variables.names[l_idx] IS NOT NULL AND a_variables.datatypes[l_idx] IS NOT NULL THEN

            IF a_variables.defaults[l_idx] IS NULL THEN
                l_variable_line := concat_ws (
                    ' ',
                    a_variables.names[l_idx],
                    a_variables.datatypes[l_idx],
                    ';' ) ;
            ELSE
                l_variable_line := concat_ws (
                    ' ',
                    a_variables.names[l_idx],
                    a_variables.datatypes[l_idx],
                    ':=',
                    a_variables.defaults[l_idx],
                    ';' ) ;
            END IF ;

            l_variable_lines := array_append ( l_variable_lines, l_variable_line ) ;

        END IF ;
    END LOOP ;

    RETURN concat_ws (
        util_meta._new_line (),
        'DECLARE',
        '',
        util_meta._indent ( 1 )
            || array_to_string ( l_variable_lines, util_meta._new_line () || util_meta._indent ( 1 ) ) ) ;

END ;
$$ ;
