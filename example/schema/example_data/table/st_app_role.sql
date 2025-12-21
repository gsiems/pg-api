CREATE TABLE example_data.st_app_role (
        id int NOT NULL DEFAULT nextval ( 'example_data.seq_rt_id' ),
        name text NOT NULL,
        is_active bool NOT NULL DEFAULT true,
        created_dt timestamp DEFAULT now (),
        updated_dt timestamp DEFAULT now (),
        created_by_id int,
        updated_by_id int,
        CONSTRAINT st_app_role_pk PRIMARY KEY ( id ),
        CONSTRAINT st_app_role_nk UNIQUE ( name ) ) ;

COMMENT ON TABLE example_data.st_app_role IS 'Application roles for the example app.' ;
COMMENT ON COLUMN example_data.st_app_role.id IS 'The system-generated ID (primary key) for the row.' ;
COMMENT ON COLUMN example_data.st_app_role.name IS 'The name of the application role.' ;
COMMENT ON COLUMN example_data.st_app_role.is_active IS 'Indicates if the row is available for further use.' ;
COMMENT ON COLUMN example_data.st_app_role.created_dt IS 'Date and time on which this row of data was added to this table.' ;
COMMENT ON COLUMN example_data.st_app_role.updated_dt IS 'Date and time on which this row of data in this table was last updated.' ;
COMMENT ON COLUMN example_data.st_app_role.created_by_id IS 'The ID of the user who added the row in the database.' ;
COMMENT ON COLUMN example_data.st_app_role.updated_by_id IS 'The ID of the user who last updated the row in the database.' ;

INSERT INTO example_data.st_app_role ( name )
    VALUES
        ( 'read' ),
        ( 'write' ),
        ( 'admin' ) ;
