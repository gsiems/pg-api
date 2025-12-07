CREATE OR REPLACE FUNCTION util_meta._snip_permissions_check (
    a_indents integer DEFAULT NULL,
    a_action text DEFAULT NULL,
    a_object_schema text DEFAULT NULL,
    a_object_name text DEFAULT NULL,
    a_ddl_schema text DEFAULT NULL,
    a_object_type text DEFAULT NULL,
    a_id_param text DEFAULT NULL,
    a_parent_object_type text DEFAULT NULL,
    a_parent_id_param text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function _snip_permissions_check generates the pl/pg-sql code snippet for calling a permissions check

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_indents                      | in     | integer    | The number of indentations to prepend to each line of the code snippet (default 0) |
| a_action                       | in     | text       | The (name of the) action that that is to be performed |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in |
| a_object_type                  | in     | text       | The (name of the) kind of object to perform the permissions check for |
| a_id_param                     | in     | text       | The parameter to use for the id argument           |
| a_parent_object_type           | in     | text       | The (name of) the type of object that is the parent of the object to check permissons for (think inserts) |
| a_parent_id_param              | in     | text       | The parameter to use for the parent id argument    |

*/
DECLARE

    l_indents integer ;
    l_return text ;
    l_log_line text ;
    l_err_line text ;
    l_ins_err_line text ;
    l_upd_err_line text ;
    l_del_err_line text ;

    l_has_ins_permission text ;
    l_has_upd_permission text ;
    l_has_permission text ;

BEGIN

    l_indents := coalesce ( a_indents, 0 ) ;

    l_ins_err_line := 'a_err := ''No, or insufficient, privileges'' ;' ;
    l_upd_err_line := 'a_err := ''No, or insufficient, privileges or the ' || a_object_type || ' does not exist'' ;' ;
    l_del_err_line := 'a_err := ''No, or insufficient, privileges or the '
        || a_object_type
        || ' has already been deleted'' ;' ;

    IF util_meta._is_valid_object ( 'util_log', 'log_exception', 'procedure' ) THEN
        l_log_line := 'call util_log.log_exception ( a_err ) ;' ;
    END IF ;

    l_return := concat_ws (
        util_meta._new_line (),
        util_meta._indent ( l_indents + 1 ) || '-- Check the permissions',
        util_meta._indent ( l_indents + 1 ) || '-- TODO verify this' ) ;

    IF a_action = 'insert' THEN

        l_has_permission := util_meta._snip_get_permissions (
            a_indents => l_indents,
            a_action => a_action,
            a_ddl_schema => a_ddl_schema,
            a_object_type => a_object_type,
            --a_id_param => null::text,
            a_parent_object_type => a_parent_object_type,
            a_parent_id_param => a_parent_id_param ) ;

        l_return := concat_ws (
            util_meta._new_line (),
            l_return,
            l_has_permission,
            '',
            util_meta._indent ( l_indents + 1 ) || 'IF NOT l_has_permission THEN',
            util_meta._indent ( l_indents + 2 ) || l_ins_err_line,
            util_meta._indent ( l_indents + 2 ) || l_log_line,
            util_meta._indent ( l_indents + 2 ) || 'RETURN ;',
            util_meta._indent ( l_indents + 1 ) || 'END IF ;' ) ;

        RETURN l_return ;

    END IF ;

    IF a_action IN ( 'update', 'delete' ) THEN

        IF a_action = 'update' THEN
            l_err_line := l_upd_err_line ;
        ELSE
            l_err_line := l_del_err_line ;
        END IF ;

        l_has_permission := util_meta._snip_get_permissions (
            a_indents => l_indents + 1,
            a_action => a_action,
            a_ddl_schema => a_ddl_schema,
            a_object_type => a_object_type,
            a_id_param => 'r.param',
            a_parent_object_type => a_parent_object_type,
            a_parent_id_param => a_parent_id_param ) ;

        l_return := concat_ws (
            util_meta._new_line (),
            l_return,
            util_meta._indent ( l_indents + 1 ) || 'FOR r IN (',
            util_meta._indent ( l_indents + 2 ) || 'SELECT ' || a_id_param || ' AS param',
            util_meta._indent ( l_indents + 3 ) || 'FROM ' || a_object_schema || '.' || a_object_name,
            util_meta._indent ( l_indents + 3 ) || 'WHERE id = ' || a_id_param || ' ) LOOP',
            l_has_permission,
            util_meta._indent ( l_indents + 1 ) || 'END LOOP ;',
            '',
            util_meta._indent ( l_indents + 1 ) || 'IF NOT coalesce ( l_has_permission, false ) THEN',
            util_meta._indent ( l_indents + 2 ) || l_err_line,
            util_meta._indent ( l_indents + 2 ) || l_log_line,
            util_meta._indent ( l_indents + 2 ) || 'RETURN ;',
            util_meta._indent ( l_indents + 1 ) || 'END IF ;' ) ;

        RETURN l_return ;

    END IF ;

    IF a_action = 'upsert' THEN

        l_has_ins_permission := util_meta._snip_get_permissions (
            a_indents => l_indents + 1,
            a_action => 'insert',
            a_ddl_schema => a_ddl_schema,
            a_object_type => a_object_type,
            a_id_param => a_id_param,
            a_parent_object_type => a_parent_object_type,
            a_parent_id_param => a_parent_id_param ) ;

        l_has_upd_permission := util_meta._snip_get_permissions (
            a_indents => l_indents + 2,
            a_action => 'update',
            a_ddl_schema => a_ddl_schema,
            a_object_type => a_object_type,
            a_id_param => 'r.param',
            a_parent_object_type => a_parent_object_type,
            a_parent_id_param => a_parent_id_param ) ;

        l_return := concat_ws (
            util_meta._new_line (),
            util_meta._indent ( l_indents + 1 ) || '-- TODO verify this',
            util_meta._indent ( l_indents + 1 ) || 'IF ' || a_id_param || ' IS NULL THEN',
            l_has_ins_permission,
            '',
            util_meta._indent ( l_indents + 2 ) || 'IF NOT l_has_permission THEN',
            util_meta._indent ( l_indents + 3 ) || l_ins_err_line,
            util_meta._indent ( l_indents + 3 ) || l_log_line,
            util_meta._indent ( l_indents + 3 ) || 'RETURN ;',
            util_meta._indent ( l_indents + 2 ) || 'END IF ;',
            '',
            util_meta._indent ( l_indents + 1 ) || 'ELSE',
            util_meta._indent ( l_indents + 2 ) || 'FOR r IN (',
            util_meta._indent ( l_indents + 3 ) || 'SELECT ' || a_id_param || ' AS param',
            util_meta._indent ( l_indents + 4 ) || 'FROM ' || a_object_schema || '.' || a_object_name,
            util_meta._indent ( l_indents + 5 ) || 'WHERE id = ' || a_id_param || ' ) LOOP',
            l_has_upd_permission,
            util_meta._indent ( l_indents + 2 ) || 'END LOOP ;',
            '',
            util_meta._indent ( l_indents + 2 ) || 'IF NOT coalesce ( l_has_permission, false ) THEN',
            util_meta._indent ( l_indents + 3 ) || l_err_line,
            util_meta._indent ( l_indents + 3 ) || l_log_line,
            util_meta._indent ( l_indents + 3 ) || 'RETURN ;',
            util_meta._indent ( l_indents + 2 ) || 'END IF ;',
            util_meta._indent ( l_indents + 1 ) || 'END IF ;' ) ;

        RETURN l_return ;

    END IF ;

    RETURN l_return ;

END ;
$$ ;
