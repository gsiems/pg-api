CREATE TABLE example_data.dt_user (
        id serial NOT NULL,
        username text NOT NULL,
        first_name text,
        last_name text,
        email_address text,
        is_active bool NOT NULL DEFAULT true,
        created_dt timestamp DEFAULT now (),
        updated_dt timestamp DEFAULT now (),
        created_by_id int,
        updated_by_id int,
        CONSTRAINT dt_user_pk PRIMARY KEY ( id ),
        CONSTRAINT dt_user_nk UNIQUE ( username ),
        CONSTRAINT dt_user_fk01 FOREIGN KEY ( created_by_id ) REFERENCES example_data.dt_user ( id ),
        CONSTRAINT dt_user_fk02 FOREIGN KEY ( updated_by_id ) REFERENCES example_data.dt_user ( id ) ) ;

COMMENT ON TABLE example_data.dt_user IS 'User accounts for the example application.' ;
COMMENT ON COLUMN example_data.dt_user.id IS 'The system generated ID (primary key) for a user.' ;
COMMENT ON COLUMN example_data.dt_user.username IS 'The login username.' ;
COMMENT ON COLUMN example_data.dt_user.first_name IS 'The first name for the user.' ;
COMMENT ON COLUMN example_data.dt_user.last_name IS 'The last name for the user.' ;
COMMENT ON COLUMN example_data.dt_user.email_address IS 'The email address for the user.' ;
COMMENT ON COLUMN example_data.dt_user.is_active IS 'Indicates if the user account is active.' ;
COMMENT ON COLUMN example_data.dt_user.created_dt IS 'Date and time on which this row of data was added to this table.' ;
COMMENT ON COLUMN example_data.dt_user.updated_dt IS 'Date and time on which this row of data in this table was last updated.' ;
COMMENT ON COLUMN example_data.dt_user.created_by_id IS 'The ID of the user who added the row in the database.' ;
COMMENT ON COLUMN example_data.dt_user.updated_by_id IS 'The ID of the user who last updated the row in the database.' ;

-- Setup the initial application user account(s)
