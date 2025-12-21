CREATE OR REPLACE FUNCTION example_admin.get_user (
    a_id in integer DEFAULT NULL,
    a_username in text DEFAULT NULL,
    a_act_user in text DEFAULT NULL )
RETURNS SETOF priv_example_admin.dv_user
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, example_admin
AS $$
/**
Function get_user Returns the specified user entry

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_id                           | in     | integer    | The system generated ID (primary key) for a user.  |
| a_username                     | in     | text       | The login username.                                |
| a_act_user                     | in     | text       | The ID or username of the user doing the search    |

*/
DECLARE

    l_has_permission boolean ;
    l_id integer ;

BEGIN

    l_id := priv_example_admin.resolve_user_id (
        a_id => a_id,
        a_username => a_username ) ;

    l_has_permission := example_admin.can_do (
        a_user => a_act_user,
        a_action => 'select',
        a_object_type => 'user',
        a_id => l_id ) ;

    RETURN QUERY
        SELECT *
            FROM priv_example_admin.dv_user
            WHERE l_has_permission
                AND id = l_id ;

END ;
$$ ;

