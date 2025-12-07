CREATE OR REPLACE FUNCTION util_meta._snip_procedure_backmatter (
    a_ddl_schema text DEFAULT NULL,
    a_procedure_name text DEFAULT NULL,
    a_comment text DEFAULT NULL,
    a_owner text DEFAULT NULL,
    a_grantees text DEFAULT NULL,
    a_calling_parameters util_meta.ut_parameters DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function _snip_procedure_backmatter generates the pl/pg-sql code snippet for the end of a procedure

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in |
| a_procedure_name               | in     | text       | The (name of the) procedure to create              |
| a_comment                      | in     | text       | The text of the comment for the object             |
| a_owner                        | in     | text       | The role that is to be the owner of the procedure  |
| a_grantees                     | in     | text       | The csv list of roles that should be granted execute on the procedure |
| a_calling_parameters           | in     | ut_parameters | The list of calling parameters                  |

ASSERTION: There is a set of logging utility functions in the util_log schema

*/
DECLARE

    l_return text ;

BEGIN

    l_return := concat_ws (
        util_meta._new_line (),
        '',
        'EXCEPTION',
        util_meta._indent ( 1 ) || 'WHEN others THEN',
        util_meta._indent ( 2 ) || 'a_err := substr ( SQLSTATE::text || '' - '' || SQLERRM, 1, 200 ) ;' ) ;

    -- check that util_log schema exists
    IF util_meta._is_valid_object ( 'util_log', 'log_exception', 'procedure' ) THEN
        l_return := concat_ws (
            util_meta._new_line (),
            l_return,
            util_meta._indent ( 2 ) || 'call util_log.log_exception ( SQLSTATE::text || '' - '' || SQLERRM ) ;' ) ;
    END IF ;

    l_return := concat_ws (
        util_meta._new_line (),
        l_return,
        'END ;',
        '$' || '$ ;',
        util_meta._snip_owners_and_grants (
            a_ddl_schema => a_ddl_schema,
            a_object_name => a_procedure_name,
            a_object_type => 'procedure',
            a_owner => a_owner,
            a_grantees => a_grantees,
            a_calling_parameters => a_calling_parameters ),
        '',
        util_meta._snip_object_comment (
            a_ddl_schema => a_ddl_schema,
            a_object_name => a_procedure_name,
            a_object_type => 'procedure',
            a_comment => a_comment,
            a_calling_parameters => a_calling_parameters ),
        '' ) ;

    RETURN l_return ;

END ;
$$ ;
