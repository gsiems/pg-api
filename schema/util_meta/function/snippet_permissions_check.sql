CREATE OR REPLACE FUNCTION util_meta.snippet_permissions_check (
    a_action text default null,
    a_ddl_schema text default null,
    a_object_type text default null,
    a_id_param text default null,
    a_parent_object_type text default null,
    a_parent_id_param text default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function snippet_permissions_check generates the pl/pg-sql code snippet for calling a permissions check

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_action                       | in     | text       | The (name of the) action that that is to be performed |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in |
| a_object_type                  | in     | text       | The (name of the) kind of object to perform the permissions check for |
| a_id_param                     | in     | text       | The parameter to use for the id argument           |
| a_parent_object_type           | in     | text       | The (name of) the type of object that is the parent of the object to check permissons for (think inserts) |
| a_parent_id_param              | in     | text       | The parameter to use for the parent id argument    |

*/
DECLARE

    l_return text ;

BEGIN

    l_return := concat_ws ( util_meta.new_line (),
        util_meta.snippet_get_permissions (
            a_action => a_action,
            a_ddl_schema => a_ddl_schema,
            a_object_type => a_object_type,
            a_id_param => a_id_param,
            a_parent_object_type => a_parent_object_type,
            a_parent_id_param => a_parent_id_param ),
        '',
        util_meta.indent (1) || 'IF NOT l_has_permission THEN',
        util_meta.indent (2) || 'a_err := ''No, or insufficient, privileges'' ;' ) ;

    IF util_meta.is_valid_object ( 'util_log', 'log_exception', 'procedure' ) THEN
        l_return := concat_ws ( util_meta.new_line (),
            l_return,
            util_meta.indent (2) || 'call util_log.log_exception ( a_err ) ;' ) ;
    END IF ;

    l_return := concat_ws ( util_meta.new_line (),
        l_return,
        util_meta.indent (2) || 'RETURN ;',
        util_meta.indent (1) || 'END IF ;' ) ;

    RETURN l_return ;

END ;
$$ ;
