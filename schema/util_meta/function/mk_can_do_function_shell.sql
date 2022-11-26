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

    l_param_comments text[] ;
    l_param_directions text[] ;
    l_param_names text[] ;
    l_param_types text[] ;

BEGIN

    FOR r IN (
        SELECT schema_name
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

        RETURN concat_ws ( util_meta.new_line (),
            util_meta.snippet_function_frontmatter (
                a_ddl_schema => a_ddl_schema,
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
                a_comments => l_param_comments ),
            '',
            'DECLARE',
            '',
            'BEGIN',
            '',
            util_meta.indent (1) || '-- TODO: Finish this function',
            util_meta.indent (1) || 'RETURN false ;',
            util_meta.snippet_function_backmatter (
                a_ddl_schema => a_ddl_schema,
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
