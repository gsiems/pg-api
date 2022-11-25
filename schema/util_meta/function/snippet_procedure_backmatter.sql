CREATE OR REPLACE FUNCTION util_meta.snippet_procedure_backmatter (
    a_ddl_schema text default null,
    a_procedure_name text default null,
    a_comment text default null,
    a_owner text default null,
    a_grantees text default null,
    a_datatypes text[] default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function snippet_procedure_backmatter generates the pl/pg-sql code snippet for the end of a procedure

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in |
| a_procedure_name               | in     | text       | The (name of the) procedure to create              |
| a_comment                      | in     | text       | The text of the comment for the object             |
| a_owner                        | in     | text       | The role that is to be the owner of the procedure  |
| a_grantees                     | in     | text       | The csv list of roles that should be granted execute on the procedure |
| a_datatypes                    | in     | text[]     | The list of the datatypes for the parameters       |

ASSERTION: There is a set of logging utility functions in the util_log schema

*/
DECLARE

    l_return text ;

BEGIN

    l_return := concat_ws ( util_meta.new_line (),
        '',
        'EXCEPTION',
        util_meta.indent (1) || 'WHEN others THEN',
        util_meta.indent (2) || 'a_err := substr ( SQLSTATE::text || '' - '' || SQLERRM, 1, 200 ) ;' ) ;

    -- check that util_log schema exists
    IF util_meta.is_valid_object ( 'util_log', 'log_exception', 'procedure' ) THEN
        l_return := concat_ws ( util_meta.new_line (),
            l_return,
            util_meta.indent (2) || 'call util_log.log_exception ( SQLSTATE::text || '' - '' || SQLERRM ) ;' ) ;
    END IF ;

    l_return := concat_ws ( util_meta.new_line (),
        l_return,
        'END ;',
        '$' || '$ ;',
        util_meta.snippet_owners_and_grants (
            a_ddl_schema => a_ddl_schema,
            a_object_name => a_procedure_name,
            a_object_type => 'procedure',
            a_owner => a_owner,
            a_grantees => a_grantees,
            a_datatypes => a_datatypes ),
        '',
        util_meta.snippet_object_comment (
            a_ddl_schema => a_ddl_schema,
            a_object_name => a_procedure_name,
            a_object_type => 'procedure',
            a_comment => a_comment,
            a_param_types => a_datatypes ),
        '' ) ;

    RETURN l_return ;

END ;
$$ ;
