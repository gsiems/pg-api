CREATE OR REPLACE FUNCTION util_meta._snip_resolve_id (
    a_indents integer DEFAULT NULL,
    a_id_param text DEFAULT NULL,
    a_calling_schema text DEFAULT NULL,
    a_calling_func text DEFAULT NULL,
    a_desired_func text DEFAULT NULL,
    a_resolve_id_params text[] DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function _snip_resolve_id generates the pl/pg-sql code snippet for calling a resolve ID function

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_indents                      | in     | integer    | The number of indentations to prepend to each line of the code snippet (default 0) |
| a_id_param                     | in     | text       | The (name of the) parameter to set the resolved ID to  |
| a_calling_schema               | in     | text       | The (name of the) schema that contains the function/procedure that wants to call the desired function |
| a_calling_func                 | in     | text       | The (name of the) the function/procedure that wants to call the desired function |
| a_desired_func                 | in     | text       | The (name of the) desired function to find         |
| a_function_schema              | in     | text       | The (name of the) schema to find the function in   |
| a_function_name                | in     | text       | The (name of the) kind of ID resolution function   |
| a_resolve_id_params            | in     | text[]     | The list of parameters for the ID resolution function |

*/
DECLARE

    l_resolve_id_params text[] ;
    l_indents integer ;
    l_func util_meta.ut_object ;

BEGIN

    l_indents := coalesce ( a_indents, 0 ) ;

    l_func := util_meta._find_func (
        a_calling_schema => a_calling_schema,
        a_calling_func => a_calling_func,
        a_desired_func => a_desired_func ) ;

    FOR idx IN 1..array_length ( a_resolve_id_params, 1 ) LOOP
        l_resolve_id_params := array_append (
            l_resolve_id_params,
            concat_ws (
                ' ',
                a_resolve_id_params[idx],
                '=>',
                a_resolve_id_params[idx] ) ) ;
    END LOOP ;

    RETURN concat_ws (
        util_meta._new_line (),
        util_meta._indent ( l_indents + 1 )
            || concat_ws (
                ' ',
                a_id_param,
                ':=',
                l_func.full_object_name,
                '(' ),
        util_meta._indent ( l_indents + 2 )
            || array_to_string (
                l_resolve_id_params,
                ',' || util_meta._new_line () || util_meta._indent ( l_indents + 2 ) )
            || ' ) ;' ) ;

END ;
$$ ;
