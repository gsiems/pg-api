CREATE OR REPLACE VIEW priv_example_admin.sv_app_role
AS
SELECT base.id,
        base.name,
        base.is_active,
        base.created_dt,
        base.updated_dt,
        base.created_by_id,
        base.updated_by_id
    FROM example_data.st_app_role base ;

COMMENT ON VIEW priv_example_admin.sv_app_role IS 'View of: Application roles for the example app.' ;
COMMENT ON COLUMN priv_example_admin.sv_app_role.id IS 'The system-generated ID (primary key) for the row.' ;
COMMENT ON COLUMN priv_example_admin.sv_app_role.name IS 'The name of the application role.' ;
COMMENT ON COLUMN priv_example_admin.sv_app_role.is_active IS 'Indicates if the row is available for further use.' ;
COMMENT ON COLUMN priv_example_admin.sv_app_role.created_dt IS 'Date and time on which this row of data was added to this table.' ;
COMMENT ON COLUMN priv_example_admin.sv_app_role.updated_dt IS 'Date and time on which this row of data in this table was last updated.' ;
COMMENT ON COLUMN priv_example_admin.sv_app_role.created_by_id IS 'The ID of the user who added the row in the database.' ;
COMMENT ON COLUMN priv_example_admin.sv_app_role.updated_by_id IS 'The ID of the user who last updated the row in the database.' ;

