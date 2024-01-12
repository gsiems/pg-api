CREATE OR REPLACE FUNCTION util_meta.snippet_procedure_frontmatter (
    a_ddl_schema text default null,
    a_procedure_name text default null,
    a_procedure_purpose text default null,
    a_language text default null,
    a_assertions text[] default null,
    a_calling_parameters util_meta.ut_parameters default null,
    a_variables util_meta.ut_parameters default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function snippet_procedure_frontmatter generates the pl/pg-sql code snippet for the start of a procedure

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in |
| a_procedure_name               | in     | text       | The (name of the) procedure to create              |
| a_procedure_purpose            | in     | text       | The (brief) description of the purpose of the procedure |
| a_language                     | in     | text       | The language that the procedure is written in (defaults to plpgsql) |
| a_assertions                   | in     | text[]     | The list of assertions made by the procedure       |
| a_calling_parameters           | in     | ut_parameters | The list of calling parameters                  |
| a_variables                    | in     | ut_parameters | The list of local variables                     |

*/
DECLARE

    l_return text ;
    l_params text[] ;
    l_param_count integer ;

BEGIN


    l_param_count := array_length ( a_calling_parameters.names, 1 ) ;

    IF l_param_count > 0 THEN

        FOR l_idx IN 1..l_param_count LOOP
            l_params := array_append ( l_params,
                util_meta.indent (1) || concat_ws ( ' ', a_calling_parameters.names[l_idx], a_calling_parameters.directions[l_idx], a_calling_parameters.datatypes[l_idx], 'default null' ) ) ;
        END LOOP ;

        l_return := concat_ws ( util_meta.new_line (),
            'CREATE OR REPLACE PROCEDURE ' || a_ddl_schema || '.' || a_procedure_name || ' (',
            array_to_string ( l_params, ', ' || util_meta.new_line () ) || ' )' ) ;

    ELSE

        l_return := concat_ws ( util_meta.new_line (),
            'CREATE OR REPLACE PROCEDURE ' || a_ddl_schema || '.' || a_procedure_name || ' ()' ) ;

    END IF ;

    l_return := concat_ws ( util_meta.new_line (),
        l_return,
        'LANGUAGE ' || lower ( coalesce ( a_language, 'plpgsql' ) ),
        'SECURITY DEFINER',
        'AS $' || '$',
        util_meta.snippet_documentation_block (
            a_object_name => a_procedure_name,
            a_object_type => 'procedure',
            a_object_purpose => a_procedure_purpose,
            a_calling_parameters => a_calling_parameters,
            a_assertions => a_assertions ) ) ;

    IF array_length ( a_variables.names, 1 ) > 0 THEN
        l_return := concat_ws ( util_meta.new_line (),
            l_return,
            util_meta.snippet_declare_variables (
                a_variables => a_variables ),
                '' ) ;

    END IF ;

    l_return := concat_ws ( util_meta.new_line (),
        l_return,
        'BEGIN' ) ;

    RETURN l_return ;

END ;
$$ ;
