DELETE FROM example_data.dt_user_app_role ;

WITH n AS (
    SELECT usr.id AS user_id,
            rol.id AS app_role_id
        FROM example_data.dt_user usr
        CROSS JOIN example_data.st_app_role rol
        WHERE rol.name = 'admin'
            AND usr.username IN ( session_user::text, 'trent' )
    UNION
    SELECT usr.id AS user_id,
            rol.id AS rol_id
        FROM example_data.dt_user usr
        CROSS JOIN example_data.st_app_role rol
        WHERE rol.name IN ( 'read', 'write' )
            AND usr.username IN ( 'alice', 'bob' )
    UNION
    SELECT usr.id AS user_id,
            rol.id AS rol_id
        FROM example_data.dt_user usr
        CROSS JOIN example_data.st_app_role rol
        WHERE rol.name = 'read'
            AND usr.username = 'eve'
)
INSERT INTO example_data.dt_user_app_role ( user_id, app_role_id )
    SELECT *
        FROM n ;
