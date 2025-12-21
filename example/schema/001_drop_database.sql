/* *

## Drop database

[001_drop_database](001_drop_database.sql)

*/

\c postgres

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;

\unset ON_ERROR_STOP

-- Since "REVOKE CONNECT ON DATABASE example_db FROM ALL" isn't an option, so:
DO $$
DECLARE
    r record ;
BEGIN
    FOR r IN (
        WITH rol AS (
            SELECT oid,
                    rolname::text AS role_name
                FROM pg_roles
            UNION
            SELECT 0::oid AS oid,
                    'public'::text
        ),
        db AS (
            SELECT d.oid AS database_oid,
                    d.datname::text AS database_name,
                    d.datdba AS owner_oid,
                    coalesce ( d.datacl, acldefault ( 'd'::"char", d.datdba ) ) AS acl
                FROM pg_database d
                WHERE d.datname = 'example_db'
        ),
        grnt AS (
            SELECT database_oid,
                    database_name,
                    owner_oid,
                    ( aclexplode ( acl ) ).grantor AS grantor_oid,
                    ( aclexplode ( acl ) ).grantee AS grantee_oid,
                    ( aclexplode ( acl ) ).privilege_type AS privilege_type
                FROM db
        )
        SELECT grnt.database_name,
                rol.role_name,
                grnt.privilege_type
            FROM grnt
            JOIN rol
                ON grnt.grantee_oid = rol.oid
            WHERE grnt.privilege_type = 'CONNECT'
                AND grnt.grantor_oid <> grnt.grantee_oid
            ORDER BY grnt.database_name,
                rol.role_name,
                grnt.privilege_type ) LOOP

        EXECUTE format (
                'REVOKE %L ON DATABASE %L FROM %L',
                r.privilege_type,
                r.database_name,
                r.role_name ) ;

    END LOOP ;
END ;
$$ ;

-- Ensure that there are no other connections to the database
SELECT pg_terminate_backend ( pid )
    FROM pg_stat_activity
    WHERE pid <> pg_backend_pid ()
        AND datname = 'example_db' ;

\set ON_ERROR_STOP

DROP DATABASE IF EXISTS example_db ;
