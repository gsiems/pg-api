CREATE OR REPLACE PROCEDURE priv_example_admin.priv_set_user_app_roles (
    a_user_id in integer DEFAULT NULL,
    a_app_roles in text DEFAULT NULL,
    a_act_user_id in integer DEFAULT NULL,
    a_err inout text DEFAULT NULL )
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, priv_example_admin
AS $$
/**
Procedure priv_set_user_app_roles sets the app roles for a user

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_user_id                      | in     | integer    | The ID of the user to set the roles for            |
| a_app_roles                    | in     | text       | The csv list of the role names for the user        |
| a_act_user_id                  | in     | text       | The ID of the acting user performing the action    |
| a_err                          | inout  | text       | The (business or database) error that was generated, if any |

ASSERTIONS

 * User permissions have already been checked and do not require further checking

*/

BEGIN

    call util_log.log_begin (
        util_log.dici ( a_user_id ),
        util_log.dici ( a_app_roles ),
        util_log.dici ( a_act_user_id ) ) ;

    WITH roles AS (
        SELECT regexp_split_to_table ( a_app_roles, '[,;]+' ) AS app_role
    ),
    nl AS (
        SELECT sar.id AS app_role_id
            FROM example_data.st_app_role sar
            JOIN roles
                ON ( roles.app_role = sar.name )
    ),
    ol AS (
        SELECT app_role_id
            FROM example_data.dt_user_app_role
            WHERE user_id = a_user_id
    ),
    n_list AS (
        SELECT nl.app_role_id AS new_id,
                ol.app_role_id AS old_id
            FROM nl
            FULL OUTER JOIN ol
                ON ( nl.app_role_id = ol.app_role_id )
    ),
    inserted AS (
        INSERT INTO example_data.dt_user_app_role ( user_id, app_role_id, created_by_id )
            SELECT a_user_id,
                    n_list.new_id,
                    a_act_user_id
                FROM n_list
                WHERE n_list.old_id IS NULL
                    AND n_list.new_id IS NOT NULL
    )
    DELETE FROM example_data.dt_user_app_role
        WHERE user_id = a_user_id
            AND app_role_id IN (
                SELECT n_list.old_id
                    FROM n_list
                    WHERE n_list.new_id IS NULL
                        AND n_list.old_id IS NOT NULL
                ) ;

EXCEPTION
    WHEN others THEN
        a_err := substr ( sqlstate::text || ' - ' || sqlerrm, 1, 200 ) ;
        call util_log.log_exception ( sqlstate::text || ' - ' || sqlerrm ) ;
END ;
$$ ;
