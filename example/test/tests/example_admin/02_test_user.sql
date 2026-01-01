
\i 20_pre_tap.sql

\i tests/example_admin/function/example_admin__insert_user.sql
\i tests/example_admin/function/example_admin__update_user.sql
\i tests/example_admin/function/example_admin__upsert_user.sql

-- Plan count should be the number of tests
SELECT plan ( 4 ) ;
--SELECT * FROM no_plan ( ) ;

SELECT ok (
    test.example_admin__insert_user (
        a_username => 'carol',
        a_first_name => 'Carol',
        a_last_name => 'Chad',
        a_email_address => 'Carol@example.com',
        a_app_roles => 'read',
        a_act_user => session_user::text,
        a_label => 'Insert user',
        a_should_pass => true
        ),
    'Insert user'
    ) ;

SELECT ok (
    test.example_admin__update_user (
        a_id => ( select id from example_data.dt_user where username = 'carol' ),
        a_username => 'carol',
        a_first_name => 'Carol',
        a_last_name => 'Smith',
        a_email_address => 'Carol@example.com',
        a_app_roles => 'read,write',
        a_act_user => session_user::text,
        a_label => 'Update user',
        a_should_pass => true
        ),
    'Update user'
    ) ;

SELECT ok (
    test.example_admin__upsert_user (
        a_id => ( select id from example_data.dt_user where username = 'carol' ),
        a_username => 'carol',
        a_first_name => 'Carol',
        a_last_name => 'Chad',
        a_email_address => 'Carol@example.com',
        a_app_roles => 'read',
        a_act_user => session_user::text,
        a_label => 'Upsert user',
        a_should_pass => true
        ),
    'Upsert user (update)'
    ) ;

SELECT ok (
    test.example_admin__upsert_user (
       a_username => 'dudley',
        a_first_name => 'Dudley',
        a_last_name => 'Doright',
        a_email_address => 'Dudley@example.com',
        a_app_roles => 'read',
        a_act_user => session_user::text,
        a_label => 'Upsert user',
        a_should_pass => true
        ),
    'Upsert user (insert)'
    ) ;

\i 30_post_tap.sql
