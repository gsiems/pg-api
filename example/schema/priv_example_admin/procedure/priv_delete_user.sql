CREATE OR REPLACE PROCEDURE priv_example_admin.priv_delete_user (
    a_id in integer DEFAULT NULL,
    a_act_user in text DEFAULT NULL,
    a_err inout text DEFAULT NULL )
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, priv_example_admin
AS $$
/**
Procedure priv_delete_user performs a delete on dt_user

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_id                           | in     | integer    | The system generated ID (primary key) for a user.  |
| a_act_user                     | in     | text       | The ID or username of the user performing the delete |
| a_err                          | inout  | text       | The (business or database) error that was generated, if any |

ASSERTIONS

 * User permissions have already been checked and do not require further checking

*/
BEGIN

    call util_log.log_begin (
        util_log.dici ( a_id ),
        util_log.dici ( a_act_user ) ) ;

    DELETE FROM example_data.dt_user
        WHERE id = a_id ;

EXCEPTION
    WHEN others THEN
        a_err := substr ( SQLSTATE::text || ' - ' || SQLERRM, 1, 200 ) ;
        call util_log.log_exception ( SQLSTATE::text || ' - ' || SQLERRM ) ;
END ;
$$ ;
