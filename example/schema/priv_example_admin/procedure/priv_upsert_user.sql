CREATE OR REPLACE PROCEDURE priv_example_admin.priv_upsert_user (
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
SET search_path = pg_catalog, priv_example_admin
AS $$
/**
Procedure priv_upsert_user performs an upsert on dt_user

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

ASSERTIONS

 * User permissions have already been checked and do not require further checking

*/
DECLARE

    l_acting_user_id integer ;
    l_is_active boolean ;
    l_desired_action text ;

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

    l_acting_user_id := priv_example_admin.resolve_user_id ( a_username => a_act_user ) ;
    IF l_acting_user_id IS NULL THEN
        a_err := 'No, or invalid, user specified' ;
        call util_log.log_exception ( a_err ) ;
        RETURN ;
    END IF ;

    l_is_active := coalesce ( a_is_active, true ) = true ;

    -- TODO review existing/add additional checks and lookups

    IF a_id IS NULL THEN
        l_desired_action := 'insert' ;
    ELSE
        l_desired_action := 'update' ;
    END IF ;

    IF l_desired_action = 'insert' THEN

        INSERT INTO example_data.dt_user (
                id,
                username,
                first_name,
                last_name,
                email_address,
                is_active,
                created_dt,
                updated_dt,
                created_by_id,
                updated_by_id )
            SELECT nextval ( 'example_data.dt_user_id_seq' ) AS id,
                    a_username AS username,
                    a_first_name AS first_name,
                    a_last_name AS last_name,
                    a_email_address AS email_address,
                    l_is_active AS is_active,
                    now () AS created_dt,
                    now () AS updated_dt,
                    l_acting_user_id AS created_by_id,
                    l_acting_user_id AS updated_by_id
                RETURNING id INTO a_id ;

    ELSE

        UPDATE example_data.dt_user o
            SET username = a_username,
                first_name = a_first_name,
                last_name = a_last_name,
                email_address = a_email_address,
                is_active = l_is_active,
                updated_dt = now (),
                updated_by_id = l_acting_user_id
            WHERE o.id = a_id
                AND ( o.username IS DISTINCT FROM a_username
                    OR o.first_name IS DISTINCT FROM a_first_name
                    OR o.last_name IS DISTINCT FROM a_last_name
                    OR o.email_address IS DISTINCT FROM a_email_address
                    OR o.is_active IS DISTINCT FROM l_is_active ) ;

    END IF ;

    call priv_example_admin.priv_set_user_app_roles (
        a_user_id => a_id,
        a_app_roles => a_app_roles,
        a_act_user_id => l_acting_user_id,
        a_err => a_err ) ;

EXCEPTION
    WHEN others THEN
        a_err := substr ( SQLSTATE::text || ' - ' || SQLERRM, 1, 200 ) ;
        call util_log.log_exception ( SQLSTATE::text || ' - ' || SQLERRM ) ;
END ;
$$ ;
