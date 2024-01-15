CREATE SCHEMA test_data ;
CREATE SCHEMA test ;
CREATE SCHEMA test_json ;



CREATE TABLE test_data.dt_user (
--    id integer NOT NULL GENERATED ALWAYS AS IDENTITY,
    id serial NOT NULL,
    username text NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    created_dt timestamp with time zone DEFAULT ( now () AT TIME ZONE 'UTC' ),
    CONSTRAINT dt_user_pk PRIMARY KEY ( id ),
    CONSTRAINT dt_user_nk PRIMARY KEY ( username ) ) ;

COMMENT ON TABLE test_data.dt_user IS 'User accounts.' ;

COMMENT ON COLUMN test_data.dt_user.id IS 'System generated unique ID for the user account.' ;

COMMENT ON COLUMN test_data.dt_user.is_enabled IS 'Indicates if the account is enabled (may log in) or not.' ;

COMMENT ON COLUMN test_data.dt_user.created_dt IS 'The timestamp when the user account was created.' ;

create table test_data.dt_primary_one
create table test_data.dt_primary_two
create table test_data.dt_child_one
create table test_data.dt_child_two

create table test_data.rt_attribute_one (
    id integer,
    name text,
    is_active boolean default true,
    is_default boolean default false,
    constraint rt_attribute_one_pk primary key ( id ),
    constraint rt_attribute_one_nk unique ( name ) ) ;

create table test_data.rt_attribute_two (
    id integer,
    name text,
    is_active boolean default true,
    is_default boolean default false,
    constraint rt_attribute_two_pk primary key ( id ),
    constraint rt_attribute_two_nk unique ( name ) ) ;

create table test_data.rt_attribute_three (
    id integer,
    name text,
    is_active boolean default true,
    is_default boolean default false,
    constraint rt_attribute_three_pk primary key ( id ),
    constraint rt_attribute_three_nk unique ( name ) ) ;






CREATE OR REPLACE VIEW test.dv_user AS
SELECT id,
        username,
        is_enabled,
        created_dt
    FROM test_data.dt_user ;
