CREATE OR REPLACE FUNCTION util_meta.snippet_function_frontmatter (
    a_ddl_schema text default null,
    a_function_name text default null,
    a_language text default null,
    a_return_type text default null,
    a_returns_set boolean default null,
    a_calling_parameters util_meta.ut_parameters default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function snippet_function_frontmatter generates the pl/pg-sql code snippet for the start of a function

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in |
| a_function_name                | in     | text       | The (name of the) function  to create              |
| a_language                     | in     | text       | The language that the function is written in (defaults to plpgsql) |
| a_return_type                  | in     | text       | The data type to return                            |
| a_returns_set                  | in     | text       | Indicates if the return type is a set (vs. scalar) (defaults to scalar) |
| a_calling_parameters           | in     | ut_parameters | The list of calling parameters                  |

*/
DECLARE

    l_return text ;
    l_params text [] ;
    l_param_count integer ;
    l_is_stable boolean := true ;

BEGIN

    IF a_function_name ~ 'insert'
        OR a_function_name ~ 'update'
        OR a_function_name ~ 'upsert'
        OR a_function_name ~ 'delete' THEN
        l_is_stable := false ;
    END IF ;

    l_param_count := array_length ( a_calling_parameters.names, 1 ) ;

    IF l_param_count > 0 THEN

        FOR l_idx IN 1..l_param_count LOOP
            l_params := array_append ( l_params,
                util_meta.indent (1) || concat_ws ( ' ', a_calling_parameters.names[l_idx], a_calling_parameters.directions[l_idx], a_calling_parameters.datatypes[l_idx], 'default null' ) ) ;
        END LOOP ;

        l_return := concat_ws ( util_meta.new_line (),
            'CREATE OR REPLACE FUNCTION ' || a_ddl_schema || '.' || a_function_name || ' (',
            array_to_string ( l_params, ', ' || util_meta.new_line () ) || ' )' ) ;

    ELSE

        l_return := concat_ws ( util_meta.new_line (),
            'CREATE OR REPLACE FUNCTION ' || a_ddl_schema || '.' || a_function_name || ' ()' ) ;

    END IF ;

    IF coalesce ( a_returns_set, false ) THEN
        l_return := concat_ws ( util_meta.new_line (),
            l_return,
            'RETURNS SETOF ' || a_return_type ) ;
    ELSE
        l_return := concat_ws ( util_meta.new_line (),
            l_return,
            'RETURNS ' || a_return_type ) ;
    END IF ;

    l_return := concat_ws ( util_meta.new_line (),
        l_return,
        'LANGUAGE ' || lower ( coalesce ( a_language, 'plpgsql' ) ) );

    IF l_is_stable THEN
        l_return := concat_ws ( util_meta.new_line (),
            l_return,
            'STABLE' ) ;
    END IF ;

    RETURN concat_ws ( util_meta.new_line (),
        l_return,
        'SECURITY DEFINER',
        'AS $' || '$' ) ;

END ;
$$ ;
