\i 20_pre_tap.sql

-- Plan count should be the number of tests
SELECT PLAN ( 4 ) ;
--SELECT * FROM no_plan ( ) ;

SELECT ok (
    NOT example_admin.can_do (
        a_user => 'mallory',
        a_action => 'insert',
        a_object_type => 'user',
        a_id => NULL::integer,
        a_parent_object_type => NULL::text,
        a_parent_id => NULL::integer ),
    'Unprivileged user cannot do' ) ;

SELECT ok (
    NOT example_admin.can_do (
        a_user => 'eve',
        a_action => 'insert',
        a_object_type => 'user',
        a_id => NULL::integer,
        a_parent_object_type => NULL::text,
        a_parent_id => NULL::integer ),
    'Under-privileged user cannot do' ) ;

SELECT ok (
    example_admin.can_do (
        a_user => 'trent',
        a_action => 'insert',
        a_object_type => 'user',
        a_id => NULL::integer,
        a_parent_object_type => NULL::text,
        a_parent_id => NULL::integer ),
    'Privileged user can do (insert)' ) ;

SELECT ok (
    example_admin.can_do (
        a_user => 'trent',
        a_action => 'update',
        a_object_type => 'user',
        a_id => (
            SELECT min ( id )
                FROM example_data.dt_user ),
        a_parent_object_type => NULL::text,
        a_parent_id => NULL::integer ),
    'Privileged user can do (update)' ) ;

\i 30_post_tap.sql
