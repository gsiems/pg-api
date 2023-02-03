CREATE OR REPLACE FUNCTION util_meta.mk_can_do_function_shell (
    a_ddl_schema text default null,
    a_owner text default null,
    a_grantees text default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function mk_can_do_function_shell generates the shell of a draft can_do function

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |

*/

DECLARE

    r record ;

    l_local_types text[] ;
    l_local_var_names text[]  ;
    l_param_comments text[] ;
    l_param_directions text[] ;
    l_param_names text[] ;
    l_param_types text[] ;
    l_notes text [] ;

BEGIN

    l_notes := array_append ( l_notes, 'To help prevent privilege escalation attacks, both the acting user and the connected user need to have sufficient permissions to perform the action' ) ;

    FOR r IN (
        SELECT schema_name AS ddl_schema
            FROM util_meta.objects
            WHERE schema_name = a_ddl_schema  ) LOOP

        l_param_names := array_append ( l_param_names, 'a_user' ) ;
        l_param_directions := array_append ( l_param_directions, 'in' ) ;
        l_param_types := array_append ( l_param_types, 'text' ) ;
        l_param_comments := array_append ( l_param_comments, 'The user to check permissions for' ) ;

        l_param_names := array_append ( l_param_names, 'a_action' ) ;
        l_param_directions := array_append ( l_param_directions, 'in' ) ;
        l_param_types := array_append ( l_param_types, 'text' ) ;
        l_param_comments := array_append ( l_param_comments, 'The action to perform' ) ;

        l_param_names := array_append ( l_param_names, 'a_object_type' ) ;
        l_param_directions := array_append ( l_param_directions, 'in' ) ;
        l_param_types := array_append ( l_param_types, 'text' ) ;
        l_param_comments := array_append ( l_param_comments, 'The (name of) the type of object to perform the action on' ) ;

        l_param_names := array_append ( l_param_names, 'a_id' ) ;
        l_param_directions := array_append ( l_param_directions, 'in' ) ;
        l_param_types := array_append ( l_param_types, 'integer' ) ;
        l_param_comments := array_append ( l_param_comments, 'The ID of the object to check permissions for' ) ;

        l_param_names := array_append ( l_param_names, 'a_parent_object_type' ) ;
        l_param_directions := array_append ( l_param_directions, 'in' ) ;
        l_param_types := array_append ( l_param_types, 'text' ) ;
        l_param_comments := array_append ( l_param_comments, 'The (name of) the type of object that is the parent of the object to check permissions for (this is for inserts)' ) ;

        l_param_names := array_append ( l_param_names, 'a_parent_id' ) ;
        l_param_directions := array_append ( l_param_directions, 'in' ) ;
        l_param_types := array_append ( l_param_types, 'integer' ) ;
        l_param_comments := array_append ( l_param_comments, 'The ID of the parent object to check permissions for (this is for inserts)' ) ;

        l_local_var_names := array_append ( l_local_var_names, 'l_acting_user_id' ) ;
        l_local_types := array_append ( l_local_types, 'integer' ) ;

        l_local_var_names := array_append ( l_local_var_names, 'l_connected_user_id' ) ;
        l_local_types := array_append ( l_local_types, 'integer' ) ;

        RETURN concat_ws ( util_meta.new_line (),
            util_meta.snippet_function_frontmatter (
                a_ddl_schema => r.ddl_schema,
                a_function_name => 'can_do',
                a_language => 'plpgsql',
                a_return_type => 'boolean',
                a_param_names => l_param_names,
                a_directions => l_param_directions,
                a_datatypes => l_param_types ),
            util_meta.snippet_documentation_block (
                a_object_name => 'can_do',
                a_object_type => 'function',
                a_object_purpose => 'determines if a user has permission to perform the specified action on the specified object (optionally for the specified ID)',
                a_param_names => l_param_names,
                a_directions => l_param_directions,
                a_datatypes => l_param_types,
                a_comments => l_param_comments,
                a_notes => l_notes ),
            util_meta.snippet_declare_variables (
                a_var_names => l_local_var_names,
                a_var_datatypes => l_local_types ),
            '',
            'BEGIN',
            '',
            util_meta.snippet_resolve_user_id (
                a_check_result => true ),
            '',
            util_meta.snippet_resolve_user_id (
                a_user_id_var => 'l_connected_user_id',
                a_user_id_param => 'connected_user::text',
                a_check_result => true ),
            '',
            util_meta.indent (1) || '-- TODO: Finish this function',
            '',
            util_meta.indent (1) || 'RETURN false ;',
            util_meta.snippet_function_backmatter (
                a_ddl_schema => r.ddl_schema,
                a_function_name => 'can_do',
                a_language => 'plpgsql',
                a_comment => null::text,
                a_owner => a_owner,
                a_grantees => a_grantees,
                a_datatypes => l_param_types ) ) ;

    END LOOP ;

    RETURN 'ERROR: invalid schema' ;

END ;
$$ ;
