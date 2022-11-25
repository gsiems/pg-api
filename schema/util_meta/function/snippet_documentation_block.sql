CREATE OR REPLACE FUNCTION util_meta.snippet_documentation_block (
    a_object_name text default null,
    a_object_type text default null,
    a_object_purpose text default null,
    a_param_names text[] default null,
    a_directions text[] default null,
    a_datatypes text[] default null,
    a_comments text[] default null,
    a_assertions text[] default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function snippet_documentation_block generates the documentation block for an object

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_name                  | in     | text       | The name of the database object                    |
| a_object_type                  | in     | text       | The type {function, procedure} of the object       |
| a_object_purpose               | in     | text       | The (brief) description of the purpose of the object |
| a_param_names                  | in     | text[]     | The list of calling parameter names                |
| a_directions                   | in     | text[]     | The list of the calling parameter directions       |
| a_datatypes                    | in     | text[]     | The list of the datatypes for the parameters       |
| a_comments                     | in     | text[]     | The list of the comments for the parameters        |
| a_assertions                   | in     | text[]     | The list of assertions made by the function/procedure |

*/
DECLARE

    l_return text ;
    l_doc_format text := '| %-30s | %-6s | %-10s | %-50s |' ;
    l_doc_lines text[] ;
    l_idx integer ;

BEGIN

    l_doc_lines := array_append ( l_doc_lines, format ( l_doc_format,  'Parameter', 'In/Out', 'Datatype', 'Remarks' ) ) ;
    l_doc_lines := array_append ( l_doc_lines, format ( l_doc_format,  '------------------------------', '------', '----------', '--------------------------------------------------' ) ) ;

    FOR l_idx IN 1..array_length ( a_param_names, 1 ) LOOP

        l_doc_lines := array_append ( l_doc_lines,
                format ( l_doc_format,
                    a_param_names[l_idx],
                    a_directions[l_idx],
                    a_datatypes[l_idx],
                    coalesce ( a_comments[l_idx], 'TBD' ) ) ) ;

    END LOOP ;

    l_return := concat_ws ( util_meta.new_line (),
        '/' || '**',
        concat_ws ( ' ', initcap ( a_object_type ), a_object_name, a_object_purpose ),
        '',
         array_to_string ( l_doc_lines, util_meta.new_line () ),
        '' ) ;

    IF array_length ( a_assertions, 1 ) > 0 THEN
        l_return := concat_ws ( util_meta.new_line (),
            l_return,
            'ASSERTIONS',
            '',
            ' * ' || array_to_string ( a_assertions,  util_meta.new_line (2) || ' * ' ),
            '' ) ;

    END IF ;

    l_return := concat_ws ( util_meta.new_line (),
        l_return,
        '*' || '/' ) ;

    RETURN l_return ;





END ;
$$ ;
