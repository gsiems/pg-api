CREATE OR REPLACE VIEW priv_example_admin.dv_user_app_role
AS
SELECT base.id,
        base.user_id,
        t002.username AS user,
        base.app_role_id,
        t003.name AS app_role,
        base.created_dt,
        base.created_by_id,
        t005.username AS created_by
    FROM example_data.dt_user_app_role base
    JOIN example_data.dt_user t002
        ON ( t002.id = base.user_id )
    JOIN example_data.st_app_role t003
        ON ( t003.id = base.app_role_id )
    LEFT JOIN example_data.dt_user t005
        ON ( t005.id = base.created_by_id ) ;

COMMENT ON VIEW priv_example_admin.dv_user_app_role IS 'View of: Application roles assigned to users.' ;
COMMENT ON COLUMN priv_example_admin.dv_user_app_role.id IS 'The system generated ID (primary key) for a user role.' ;
COMMENT ON COLUMN priv_example_admin.dv_user_app_role.user_id IS 'The ID of the user.' ;
COMMENT ON COLUMN priv_example_admin.dv_user_app_role.user IS 'The username for the user' ;
COMMENT ON COLUMN priv_example_admin.dv_user_app_role.app_role_id IS 'The ID of the application role.' ;
COMMENT ON COLUMN priv_example_admin.dv_user_app_role.app_role IS 'The name for the app role' ;
COMMENT ON COLUMN priv_example_admin.dv_user_app_role.created_dt IS 'Date and time on which this row of data was added to this table.' ;
COMMENT ON COLUMN priv_example_admin.dv_user_app_role.created_by_id IS 'The ID of the user who added the row in the database.' ;
COMMENT ON COLUMN priv_example_admin.dv_user_app_role.created_by IS 'The username for the created by' ;

