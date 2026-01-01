DELETE FROM example_data.dt_user_app_role ;
DELETE FROM example_data.dt_user ;

INSERT INTO example_data.dt_user ( username, first_name, last_name )
    VALUES
        ( session_user::text, initcap ( session_user::text ), 'NLN' ),
        ( 'alice', 'Alice', 'A' ),
        ( 'bob', 'Bob', 'B' ),
        ( 'eve', 'Eve', 'Eavesdropper' ),
        ( 'mallory', 'Mallory', 'Malicious' ),
        ( 'trent', 'Trent', 'Trusted' ) ;
