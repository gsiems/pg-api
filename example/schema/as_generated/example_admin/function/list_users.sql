CREATE OR REPLACE FUNCTION example_admin.list_users (
    a_act_user in text DEFAULT NULL )
RETURNS SETOF priv_example_admin.dv_user
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, example_admin
AS $$
/**
Function list_users

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_act_user                     | in     | text       | The ID or username of the user requesting the list |

*/
DECLARE

    l_has_permission boolean ;

BEGIN

    -- TODO: review this as different applications may have different permissions models.
    -- As written, this asserts that the permissions model is table (as opposed to row) based.

    l_has_permission := example_admin.can_do (
        a_user => a_act_user,
        a_action => 'select',
        a_id => null ) ;

    RETURN QUERY
        SELECT *
            FROM priv_example_admin.dv_user
            WHERE l_has_permission ;

END ;
$$ ;

