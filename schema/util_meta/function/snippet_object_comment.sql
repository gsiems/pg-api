CREATE OR REPLACE FUNCTION util_meta.snippet_object_comment (
    a_ddl_schema text default null,
    a_object_name text default null,
    a_object_type text default null,
    a_comment text default null,
    a_calling_parameters util_meta.ut_parameters default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function snippet_object_comment generates a COMMENT ON ... snippet

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_ddl_schema                   | in     | text       | The (name of the) schema of the object being commented on |
| a_object_name                  | in     | text       | The (name of the) object being commented on        |
| a_object_type                  | in     | text       | The (name of the) object type                      |
| a_comment                      | in     | text       | The text of the comment for the object             |
| a_calling_parameters           | in     | ut_parameters | The (optional) list of calling parameters       |

*/
BEGIN

    IF a_object_type IS NULL OR a_object_name IS NULL THEN
        RETURN null::text ;
    END IF ;

    IF a_calling_parameters IS NOT NULL AND array_length ( a_calling_parameters.datatypes, 1 ) > 0 THEN

        RETURN concat_ws ( ' ',
            'COMMENT ON',
            upper ( a_object_type ),
            a_ddl_schema || '.' || a_object_name,
            '(', array_to_string ( a_calling_parameters.datatypes, ', ' ), ')',
            'IS',
            quote_literal ( trim ( coalesce ( a_comment, 'TBD' ) ) ),
            ';' ) ;

    END IF ;

    RETURN concat_ws ( ' ',
        'COMMENT ON',
        upper ( a_object_type ),
        a_ddl_schema || '.' || a_object_name,
        'IS',
        quote_literal ( trim ( coalesce ( a_comment, 'TBD' ) ) ),
        ';' ) ;

END ;
$$ ;
