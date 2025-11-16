CREATE OR REPLACE FUNCTION util_meta.snippet_documentation_block (
    a_object_name text DEFAULT NULL,
    a_object_type text DEFAULT NULL,
    a_object_purpose text DEFAULT NULL,
    a_calling_parameters util_meta.ut_parameters DEFAULT NULL,
    a_assertions text[] DEFAULT NULL,
    a_notes text[] DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/**
Function snippet_documentation_block generates the documentation block for an object

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_name                  | in     | text       | The name of the database object                    |
| a_object_type                  | in     | text       | The type {function, procedure} of the object       |
| a_object_purpose               | in     | text       | The (brief) description of the purpose of the object |
| a_calling_parameters           | in     | ut_parameters | The list of calling parameters                  |
| a_notes                        | in     | text[]     | The list of notes for the user/developer of the function |
| a_assertions                   | in     | text[]     | The list of assertions made by the function/procedure |

*/
DECLARE

    l_return text ;
    l_doc_format constant text := '| %-30s | %-6s | %-10s | %-50s |' ;
    l_doc_lines text[] ;

BEGIN

    l_doc_lines := array_append (
        l_doc_lines,
        format (
            l_doc_format,
            'Parameter',
            'In/Out',
            'Datatype',
            'Description' ) ) ;
    l_doc_lines := array_append (
        l_doc_lines,
        format (
            l_doc_format,
            '------------------------------',
            '------',
            '----------',
            '--------------------------------------------------' ) ) ;

    FOR l_idx IN 1..array_length ( a_calling_parameters.names, 1 ) LOOP

        l_doc_lines := array_append (
            l_doc_lines,
            format (
                l_doc_format,
                a_calling_parameters.names[l_idx],
                a_calling_parameters.directions[l_idx],
                a_calling_parameters.datatypes[l_idx],
                coalesce ( a_calling_parameters.descriptions[l_idx], 'TBD' ) ) ) ;

    END LOOP ;

    l_return := concat_ws (
        util_meta.new_line (),
        '/' || '**',
        concat_ws (
            ' ',
            initcap ( a_object_type ),
            a_object_name,
            a_object_purpose ),
        '',
        array_to_string ( l_doc_lines, util_meta.new_line () ),
        '' ) ;

    IF array_length ( a_notes, 1 ) > 0 THEN
        l_return := concat_ws (
            util_meta.new_line (),
            l_return,
            'NOTES',
            '',
            ' * ' || array_to_string ( a_notes, util_meta.new_line ( 2 ) || ' * ' ),
            '' ) ;

    END IF ;

    IF array_length ( a_assertions, 1 ) > 0 THEN
        l_return := concat_ws (
            util_meta.new_line (),
            l_return,
            'ASSERTIONS',
            '',
            ' * ' || array_to_string ( a_assertions, util_meta.new_line ( 2 ) || ' * ' ),
            '' ) ;

    END IF ;

    l_return := concat_ws ( util_meta.new_line (), l_return, '*' || '/' ) ;

    RETURN l_return ;

END ;
$$ ;
