CREATE OR REPLACE FUNCTION util_meta.snippet_get_permissions (
    a_indents integer default null,
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
Function snippet_get_permissions generates the pl/pg-sql code snippet for calling a getting the users permissions for an action on an object

| Parameter                      | In/Out | Datatype   | Remarks                                            |
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
    that returns a true/false value indicating if the specified user can to the specified action to the specified object

*/
DECLARE

    l_object_type text ;
    l_action text ;
    l_id_param text ;
    l_indents integer ;

BEGIN

    l_indents := coalesce ( a_indents, 0 ) ;

    IF substring ( a_object_type for 3 ) = 'rt_' THEN
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

    IF a_parent_object_type IS NULL THEN

        l_id_param := coalesce ( l_id_param, a_id_param, 'null' ) ;

        RETURN concat_ws ( util_meta.new_line (),
                '',
                util_meta.indent (l_indents + 1) || 'l_has_permission := ' || a_ddl_schema || '.can_do (',
                util_meta.indent (l_indents + 2) || 'a_user => a_user,',
                util_meta.indent (l_indents + 2) || 'a_action => ' || l_action || ',',
                util_meta.indent (l_indents + 2) || 'a_object_type => ' || quote_literal ( l_object_type ) || ',  -- TODO verify this',
                util_meta.indent (l_indents + 2) || 'a_id => ' || l_id_param || ' ) ; -- TODO verify this' ) ;

    END IF ;

    RETURN concat_ws ( util_meta.new_line (),
            '',
            util_meta.indent (l_indents + 1) || 'l_has_permission := ' || a_ddl_schema || '.can_do (',
            util_meta.indent (l_indents + 2) || 'a_user => a_user,',
            util_meta.indent (l_indents + 2) || 'a_action => ' || l_action || ',',
            util_meta.indent (l_indents + 2) || 'a_object_type => ' || quote_literal ( l_object_type ) || ',  -- TODO verify this',
            util_meta.indent (l_indents + 2) || 'a_id => null,',
            util_meta.indent (l_indents + 2) || 'a_parent_object_type => ' || quote_literal ( a_parent_object_type ) || ',',
            util_meta.indent (l_indents + 2) || 'a_parent_object_id => ' || a_parent_id_param || ' ) ;' ) ;

END ;
$$ ;
