CREATE OR REPLACE PROCEDURE example_admin.upsert_user (
    a_id inout integer DEFAULT NULL,
    a_username in text DEFAULT NULL,
    a_first_name in text DEFAULT NULL,
    a_last_name in text DEFAULT NULL,
    a_email_address in text DEFAULT NULL,
    a_app_roles in text DEFAULT NULL,
    a_is_active in boolean DEFAULT NULL,
    a_act_user in text DEFAULT NULL,
    a_err inout text DEFAULT NULL )
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, example_admin
AS $$
/**
Procedure upsert_user performs upsert actions on example_data.dt_user

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_id                           | inout  | integer    | The system generated ID (primary key) for a user.  |
| a_username                     | in     | text       | The login username.                                |
| a_first_name                   | in     | text       | The first name for the user.                       |
| a_last_name                    | in     | text       | The last name for the user.                        |
| a_email_address                | in     | text       | The email address for the user.                    |
| a_app_roles                    | in     | text       | The csv list of the role names for the user        |
| a_is_active                    | in     | boolean    | Indicates if the user account is active.           |
| a_act_user                     | in     | text       | The ID or username of the user performing the upsert |
| a_err                          | inout  | text       | The (business or database) error that was generated, if any |

*/
DECLARE

    r record ;
    l_has_permission boolean ;

BEGIN

    call util_log.log_begin (
        util_log.dici ( a_id ),
        util_log.dici ( a_username ),
        util_log.dici ( a_first_name ),
        util_log.dici ( a_last_name ),
        util_log.dici ( a_email_address ),
        util_log.dici ( a_app_roles ),
        util_log.dici ( a_is_active ),
        util_log.dici ( a_act_user ) ) ;

    ----------------------------------------------------------------------------
    -- TODO verify this
    IF a_id IS NULL THEN

        l_has_permission := example_admin.can_do (
            a_user => a_act_user,
            a_action => 'insert',
            a_object_type => 'user',
            a_id => a_id ) ;

        IF NOT l_has_permission THEN
            a_err := 'No, or insufficient, privileges' ;
            call util_log.log_exception ( a_err ) ;
            RETURN ;
        END IF ;

    ELSE
        FOR r IN (
            SELECT a_id AS param
                FROM example_data.dt_user
                    WHERE id = a_id ) LOOP

            l_has_permission := example_admin.can_do (
                a_user => a_act_user,
                a_action => 'update',
                a_object_type => 'user',
                a_id => r.param ) ;
        END LOOP ;

        IF NOT coalesce ( l_has_permission, false ) THEN
            call util_log.log_exception ( a_err ) ;
            RETURN ;
        END IF ;
    END IF ;

    call priv_example_admin.priv_upsert_user (
        a_id => a_id,
        a_username => a_username,
        a_first_name => a_first_name,
        a_last_name => a_last_name,
        a_email_address => a_email_address,
        a_app_roles => a_app_roles,
        a_is_active => a_is_active,
        a_act_user => a_act_user,
        a_err => a_err ) ;

EXCEPTION
    WHEN others THEN
        a_err := substr ( SQLSTATE::text || ' - ' || SQLERRM, 1, 200 ) ;
        call util_log.log_exception ( SQLSTATE::text || ' - ' || SQLERRM ) ;
END ;
$$ ;
