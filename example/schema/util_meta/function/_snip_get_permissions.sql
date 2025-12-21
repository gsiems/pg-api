CREATE OR REPLACE FUNCTION util_meta._snip_get_permissions (
    a_indents integer DEFAULT NULL,
    a_action text DEFAULT NULL,
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
Function _snip_get_permissions generates the pl/pgsql code snippet for calling a getting the users permissions for an action on an object

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_indents                      | in     | integer    | The number of indentations to prepend to each line of the code snippet (default 0) |
| a_action                       | in     | text       | The (name of the) action that that is to be performed |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in |
| a_object_type                  | in     | text       | The (name of the) kind of object to perform the permissions check for |
| a_id_param                     | in     | text       | The parameter to use for the id argument           |
| a_parent_object_type           | in     | text       | The (name of) the type of object that is the parent of the object to check permissons for (think inserts) |
| a_parent_id_param              | in     | text       | The parameter to use for the parent id argument    |

ASSERTION: In the DDL schema there exists a function:
    can_do (
        a_user text,
        a_action text,
        a_object_type text,
        a_id integer,
        a_parent_object_type text,
        a_parent_object_id integer ) ;
    that returns a true/false value indicating if the specified user can perform the specified action on the specified object/object type

*/
DECLARE

    l_object_type text ;
    l_action text ;
    l_id_param text ;
    l_indents integer ;
    l_return text ;

BEGIN

    l_indents := coalesce ( a_indents, 0 ) ;

    IF substring ( a_object_type FOR 3 ) = 'rt_' THEN
        l_object_type := 'ref_data' ;
        l_id_param := 'null' ;
    ELSE
        l_object_type := a_object_type ;
    END IF ;

    IF a_action = 'l_desired_action' THEN
        l_action := a_action ;
    ELSE
        l_action := quote_literal ( a_action ) ;
    END IF ;

    l_return := concat_ws (
        util_meta._new_line (),
        '',
        util_meta._indent ( l_indents + 1 ) || 'l_has_permission := ' || a_ddl_schema || '.can_do (',
        util_meta._indent ( l_indents + 2 ) || 'a_user => a_act_user,',
        util_meta._indent ( l_indents + 2 ) || 'a_action => ' || l_action || ',',
        util_meta._indent ( l_indents + 2 ) || 'a_object_type => ' || quote_literal ( l_object_type ) || ',' ) ;

    IF a_parent_object_type IS NULL THEN

        l_id_param := coalesce ( l_id_param, a_id_param, 'null' ) ;

        RETURN concat_ws (
            util_meta._new_line (),
            l_return,
            util_meta._indent ( l_indents + 2 ) || 'a_id => ' || l_id_param || ' ) ;' ) ;

    END IF ;

    RETURN concat_ws (
        util_meta._new_line (),
        l_return,
        util_meta._indent ( l_indents + 2 ) || 'a_id => null,',
        util_meta._indent ( l_indents + 2 )
            || 'a_parent_object_type => '
            || quote_literal ( a_parent_object_type ) || ',',
        util_meta._indent ( l_indents + 2 ) || 'a_parent_object_id => ' || a_parent_id_param || ' ) ;' ) ;

END ;
$$ ;
