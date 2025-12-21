CREATE TABLE example_data.dt_user_app_role (
        id serial NOT NULL,
        user_id integer NOT NULL,
        app_role_id integer NOT NULL,
        created_dt timestamp DEFAULT now (),
        created_by_id int,
        CONSTRAINT dt_user_app_role_pk PRIMARY KEY ( id ),
        CONSTRAINT dt_user_app_role_nk UNIQUE ( user_id, app_role_id ),
        CONSTRAINT dt_user_app_role_fk01 FOREIGN KEY ( user_id ) REFERENCES example_data.dt_user ( id ),
        CONSTRAINT dt_user_app_role_fk02 FOREIGN KEY ( app_role_id ) REFERENCES example_data.st_app_role ( id ),
        CONSTRAINT dt_user_app_role_fk03 FOREIGN KEY ( created_by_id ) REFERENCES example_data.dt_user ( id ) ) ;

COMMENT ON TABLE example_data.dt_user_app_role IS 'Application roles assigned to users.' ;
COMMENT ON COLUMN example_data.dt_user_app_role.id IS 'The system generated ID (primary key) for a user role.' ;
COMMENT ON COLUMN example_data.dt_user_app_role.user_id IS 'The ID of the user.' ;
COMMENT ON COLUMN example_data.dt_user_app_role.app_role_id IS 'The ID of the application role.' ;
COMMENT ON COLUMN example_data.dt_user_app_role.created_dt IS 'Date and time on which this row of data was added to this table.' ;
COMMENT ON COLUMN example_data.dt_user_app_role.created_by_id IS 'The ID of the user who added the row in the database.' ;
