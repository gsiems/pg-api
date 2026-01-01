CREATE OR REPLACE FUNCTION example_admin.can_do (
    a_user in text DEFAULT NULL,
    a_action in text DEFAULT NULL,
    a_object_type in text DEFAULT NULL,
    a_id in integer DEFAULT NULL,
    a_parent_object_type in text DEFAULT NULL,
    a_parent_id in integer DEFAULT NULL )
RETURNS boolean
LANGUAGE plpgsql
--STABLE
SECURITY DEFINER
SET search_path = pg_catalog, example_admin
AS $$
/**
Function can_do determines if a user has permission to perform the specified action on the specified object (optionally for the specified ID)

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_user                         | in     | text       | The user to check permissions for                  |
| a_action                       | in     | text       | The action to perform                              |
| a_object_type                  | in     | text       | The (name of) the type of object to perform the action on |
| a_id                           | in     | integer    | The ID of the object to check permissions for      |
| a_parent_object_type           | in     | text       | The (name of) the type of object that is the parent of the object to check permissions for (this is for inserts) |
| a_parent_id                    | in     | integer    | The ID of the parent object to check permissions for (this is for inserts) |

NOTES

 * To help prevent privilege escalation attacks, both the acting user and the connected user need to have sufficient permissions to perform the action

*/
DECLARE

    r record ;
    l_acting_user_id integer ;
    l_connected_user_id integer ;
    l_acting_can_do boolean := false ;
    l_connected_can_do boolean := false ;

    l_do_logging boolean := false ;

BEGIN

    -- This bit is to keep pl_profiler from complaining about unused parameters:
    IF l_do_logging THEN
        call util_log.log_begin (
            util_log.dici ( a_user ),
            util_log.dici ( a_action ),
            util_log.dici ( a_object_type ),
            util_log.dici ( a_id ),
            util_log.dici ( a_parent_object_type ),
            util_log.dici ( a_parent_id ) ) ;
    END IF ;

    l_acting_user_id := priv_example_admin.resolve_user_id ( a_username => a_user ) ;

    l_connected_user_id := priv_example_admin.resolve_user_id ( a_username => session_user::text ) ;

    FOR r IN (
        SELECT user_id
            FROM priv_example_admin.dv_user_app_role
            WHERE app_role = 'admin'
                AND user_id IN ( l_acting_user_id, l_connected_user_id ) ) LOOP

        IF l_acting_user_id = r.user_id THEN
            l_acting_can_do := true ;
        END IF ;
        IF l_connected_user_id = r.user_id THEN
            l_connected_can_do := true ;
        END IF ;

    END LOOP ;

    RETURN l_acting_can_do AND l_connected_can_do ;

END ;
$$ ;
