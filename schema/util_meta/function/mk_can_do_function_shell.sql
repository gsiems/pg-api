CREATE OR REPLACE FUNCTION util_meta.mk_can_do_function_shell (
    a_ddl_schema text DEFAULT NULL,
    a_owner text DEFAULT NULL,
    a_grantees text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/**
Function mk_can_do_function_shell generates the shell of a draft can_do function

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |

*/

DECLARE

    r record ;

    l_notes text[] ;

    l_local_vars util_meta.ut_parameters ;
    l_calling_params util_meta.ut_parameters ;

BEGIN

    l_notes := array_append (
        l_notes,
        'To help prevent privilege escalation attacks, both the acting user and the connected user need to have sufficient permissions to perform the action' ) ;

    FOR r IN (
        SELECT schema_name AS ddl_schema
            FROM util_meta.schemas
            WHERE schema_name = a_ddl_schema ) LOOP

        l_calling_params := util_meta.append_parameter (
            a_parameters => l_calling_params,
            a_name => 'a_user',
            a_datatype => 'text',
            a_description => 'The user to check permissions for' ) ;

        l_calling_params := util_meta.append_parameter (
            a_parameters => l_calling_params,
            a_name => 'a_action',
            a_datatype => 'text',
            a_description => 'The action to perform' ) ;

        l_calling_params := util_meta.append_parameter (
            a_parameters => l_calling_params,
            a_name => 'a_object_type',
            a_datatype => 'text',
            a_description => 'The (name of) the type of object to perform the action on' ) ;

        l_calling_params := util_meta.append_parameter (
            a_parameters => l_calling_params,
            a_name => 'a_id',
            a_datatype => 'integer',
            a_description => 'The ID of the object to check permissions for' ) ;

        l_calling_params := util_meta.append_parameter (
            a_parameters => l_calling_params,
            a_name => 'a_parent_object_type',
            a_datatype => 'text',
            a_description => 'The (name of) the type of object that is the parent of the object to check permissions for (this is for inserts)' ) ;

        l_calling_params := util_meta.append_parameter (
            a_parameters => l_calling_params,
            a_name => 'a_parent_id',
            a_datatype => 'integer',
            a_description => 'The ID of the parent object to check permissions for (this is for inserts)' ) ;

        ------------------------------------------------------------------------
        l_local_vars := util_meta.append_parameter (
            a_parameters => l_local_vars,
            a_name => 'l_acting_user_id',
            a_datatype => 'integer' ) ;

        l_local_vars := util_meta.append_parameter (
            a_parameters => l_local_vars,
            a_name => 'l_connected_user_id',
            a_datatype => 'integer' ) ;

        RETURN util_meta.cleanup_whitespace ( concat_ws (
            util_meta.new_line (),
            util_meta.snippet_function_frontmatter (
                a_ddl_schema => r.ddl_schema,
                a_function_name => 'can_do',
                a_language => 'plpgsql',
                a_return_type => 'boolean',
                a_calling_parameters => l_calling_params ),
            util_meta.snippet_documentation_block (
                a_object_name => 'can_do',
                a_object_type => 'function',
                a_object_purpose => 'determines if a user has permission to perform the specified action on the specified object (optionally for the specified ID)',
                a_calling_parameters => l_calling_params,
                a_notes => l_notes ),
            util_meta.snippet_declare_variables ( a_variables => l_local_vars ),
            '',
            'BEGIN',
            '',
            util_meta.snippet_resolve_user_id ( a_check_result => true ),
            '',
            util_meta.snippet_resolve_user_id (
                a_user_id_var => 'l_connected_user_id',
                a_user_id_param => 'connected_user::text',
                a_check_result => true ),
            '',
            util_meta.indent ( 1 ) || '-- TODO: Finish this function',
            '',
            util_meta.indent ( 1 ) || 'RETURN false ;',
            util_meta.snippet_function_backmatter (
                a_ddl_schema => r.ddl_schema,
                a_function_name => 'can_do',
                a_language => 'plpgsql',
                a_comment => NULL::text,
                a_owner => a_owner,
                a_grantees => a_grantees,
                a_calling_parameters => l_calling_params ) ) ) ;

    END LOOP ;

    RETURN 'ERROR: invalid schema' ;

END ;
$$ ;
