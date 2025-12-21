CREATE OR REPLACE VIEW priv_example_admin.dv_user
AS
SELECT base.id,
        base.username,
        base.first_name,
        base.last_name,
        base.email_address,
        base.is_active,
        base.created_dt,
        base.updated_dt,
        base.created_by_id,
        t009.username AS created_by,
        base.updated_by_id,
        t010.username AS updated_by
    FROM example_data.dt_user base
    LEFT JOIN example_data.dt_user t009
        ON ( t009.id = base.created_by_id )
    LEFT JOIN example_data.dt_user t010
        ON ( t010.id = base.updated_by_id ) ;

COMMENT ON VIEW priv_example_admin.dv_user IS 'View of: User accounts for the example application.' ;
COMMENT ON COLUMN priv_example_admin.dv_user.id IS 'The system generated ID (primary key) for a user.' ;
COMMENT ON COLUMN priv_example_admin.dv_user.username IS 'The login username.' ;
COMMENT ON COLUMN priv_example_admin.dv_user.first_name IS 'The first name for the user.' ;
COMMENT ON COLUMN priv_example_admin.dv_user.last_name IS 'The last name for the user.' ;
COMMENT ON COLUMN priv_example_admin.dv_user.email_address IS 'The email address for the user.' ;
COMMENT ON COLUMN priv_example_admin.dv_user.is_active IS 'Indicates if the user account is active.' ;
COMMENT ON COLUMN priv_example_admin.dv_user.created_dt IS 'Date and time on which this row of data was added to this table.' ;
COMMENT ON COLUMN priv_example_admin.dv_user.updated_dt IS 'Date and time on which this row of data in this table was last updated.' ;
COMMENT ON COLUMN priv_example_admin.dv_user.created_by_id IS 'The ID of the user who added the row in the database.' ;
COMMENT ON COLUMN priv_example_admin.dv_user.created_by IS 'The username for the created by' ;
COMMENT ON COLUMN priv_example_admin.dv_user.updated_by_id IS 'The ID of the user who last updated the row in the database.' ;
COMMENT ON COLUMN priv_example_admin.dv_user.updated_by IS 'The username for the updated by' ;

