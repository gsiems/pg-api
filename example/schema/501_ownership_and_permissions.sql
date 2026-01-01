/**
## Ownership and Permissions

[501_ownership_and_permissions](501_ownership_and_permissions.sql)

### Goal

To document rules regarding how ownership/privileges could be set and provide
code to enforce those rules.

### Approach

Rather than setting object ownership and permissions in each individual DDL
file the setting of ownership and permissions could be consolidated into one
location... here.

### Rule Basics

1. All database objects should be owned by the same owner. In the example the
"example_db_owner" role should be the owner of all objects (In a real
application it is hoped that the owner is not named "example_db_owner"). Also,
in a real application, there may be exceptions to this rule and those
exceptions should be documented-- for example, if the database integrates some
third-party tools such as ESRI).

2. The database objects owner should be a NOLOGIN role.

3. The database objects owner should be consistent across the different
environments (local, development, test, and production).

4. Permissions to "private" objects should be minimized and should be
consistently applied across the different environments.

5. Permissions to API objects should be should be consistently applied across
the different environments.

6. Grants to the "public" role should be minimized.

*/

\connect example_db

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;

--------------------------------------------------------------------------------
-- Temporary tables for establishing Ownership and Grants

-- List of roles (per conventions)
CREATE TEMPORARY TABLE tt_object_roles (
        role_name name,
        label text )
    ON COMMIT PRESERVE ROWS ;

-- list of usernames for developers
CREATE TEMPORARY TABLE tt_developers (
        role_name name )
    ON COMMIT PRESERVE ROWS ;

-- List of schemas for the application
CREATE TEMPORARY TABLE tt_object_schemas (
        schema_name text,
        label text )
    ON COMMIT PRESERVE ROWS ;

/*
NB: Populate the tt_object_roles, tt_developers, and tt_object_schemas tables
according the the actual project
*/
-- Object role labels used: backend, developer, logger, owner, read, update
INSERT INTO tt_object_roles
    VALUES
        ( 'example_db_owner', 'owner' ),
        ( 'example_db_developer', 'developer' ),
        ( 'example_db_bend', 'backend' ),
        ( 'example_db_logger', 'logger' ),
        ( 'example_db_read', 'read' ),
        ( 'example_db_updt', 'update' ) ;

INSERT INTO tt_developers
    VALUES ( current_user::text ) ;

INSERT INTO tt_developers
    VALUES
        ( 'alice' ),
        ( 'bob' ),
        ( 'eve' ) ;

-- Schema type labels used: api, private, util
INSERT INTO tt_object_schemas
    VALUES
        ( 'example_admin', 'api' ),
        ( 'example_admin_json', 'api' ),
        ( 'priv_example_admin', 'private' ),
        ( 'priv_example_api', 'private' ),
        ( 'example', 'api' ),
        ( 'example_data', 'private' ),
        ( 'example_json', 'api' ),
        ( 'priv_example', 'private' ),
        ( 'util_log', 'util' ),
        ( 'util_meta', 'util' ) ;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
* RULE: Database objects should all be owned by the same NOLOGIN role

*/
DO $$
DECLARE
    r record ;
    r2 record ;

BEGIN

    FOR r IN (
        SELECT role_name
            FROM tt_object_roles
            WHERE label = 'owner' ) LOOP

        -- Needed by util_meta:
        EXECUTE format ( 'GRANT TEMPORARY ON DATABASE %I TO %s', current_database ()::text, r.role_name ) ;

        FOR r2 IN (
            SELECT obj.schema_name,
                    obj.object_name,
                    obj.base_object_type AS object_type,
                    coalesce ( obj.calling_signature, '' ) AS calling_signature
                FROM util_meta.objects obj
                JOIN tt_object_schemas t
                    ON ( t.schema_name = obj.schema_name )
                WHERE obj.object_owner <> r.role_name
                    AND obj.object_type NOT IN ( 'index', 'sequence' ) ) LOOP

            IF r2.object_type IN ( 'function', 'procedure' ) THEN

                EXECUTE format (
                        'ALTER %s %I.%I ( %s ) OWNER TO %I ;',
                        r2.object_type,
                        r2.schema_name,
                        r2.object_name,
                        r2.calling_signature,
                        r.role_name ) ;

            ELSE

                EXECUTE format (
                        'ALTER %s %I.%I OWNER TO %I ;',
                        r2.object_type,
                        r2.schema_name,
                        r2.object_name,
                        r.role_name ) ;

                IF r2.object_type = 'schema' THEN
                    EXECUTE format ( 'GRANT USAGE ON SCHEMA %I TO %I ;', r2.schema_name, r.role_name ) ;
                END IF ;

            END IF ;

        END LOOP ;

        FOR r2 IN (
            SELECT obj.schema_name,
                    obj.object_name,
                    obj.base_object_type AS object_type,
                    coalesce ( obj.calling_signature, '' ) AS calling_signature
                FROM util_meta.objects obj
                JOIN tt_object_schemas t
                    ON ( t.schema_name = obj.schema_name )
                WHERE obj.object_owner <> r.role_name
                    AND obj.object_type IN ( 'sequence' ) ) LOOP

            EXECUTE format (
                    'ALTER %s %I.%I OWNER TO %I ;',
                    r2.object_type,
                    r2.schema_name,
                    r2.object_name,
                    r.role_name ) ;

        END LOOP ;

    END LOOP ;
END ;
$$ ;

/**
* RULE: The public role should have minimal permissions

*/
DO $$
DECLARE
    r record ;
BEGIN

    FOR r IN (
        SELECT og.schema_name,
                og.object_name,
                og.base_object_type AS object_type,
                coalesce ( og.calling_signature, '' ) AS calling_signature,
                og.grantee,
                og.privilege_type
            FROM util_meta.object_grants og
            JOIN tt_object_schemas t
                ON ( t.schema_name = og.schema_name )
            WHERE og.grantee = 'public' ) LOOP

        IF r.object_type IN ( 'function', 'procedure' ) THEN
            EXECUTE format (
                    'REVOKE %s ON %s %I.%I ( %s ) FROM %I ;',
                    r.privilege_type,
                    r.object_type,
                    r.schema_name,
                    r.object_name,
                    r.calling_signature,
                    r.grantee ) ;

        ELSE
            EXECUTE format (
                    'REVOKE %s ON %s %I.%I FROM %I ;',
                    r.privilege_type,
                    r.object_type,
                    r.schema_name,
                    r.object_name,
                    r.grantee ) ;
        END IF ;

    END LOOP ;
END ;
$$ ;

/**
* RULE: Developer users should have developer role membership
    * QUESTION: developer role in production???
    * NOTE: To be really thorough this could be recursive

* RULE: Non-developer users should NOT have developer role membership
    * NOTE: To be really thorough this should be recursive

*/
DO $$
DECLARE
    r record ;
BEGIN

    FOR r IN (
        WITH has_rol AS (
            SELECT rol.rolname::text AS role_name
                FROM pg_catalog.pg_roles rol
                JOIN pg_catalog.pg_auth_members pam
                    ON ( pam.member = rol.oid )
                JOIN pg_catalog.pg_roles dev
                    ON ( dev.oid = pam.roleid )
                JOIN tt_object_roles tor
                    ON ( tor.role_name = dev.rolname::text )
                WHERE tor.label = 'developer'
        )
        SELECT coalesce ( has_rol.role_name, td.role_name ) AS role_name,
                tor.role_name AS developer_role,
                CASE WHEN has_rol.role_name IS NULL THEN true WHEN td.role_name IS NULL THEN false END AS needs_grant
            FROM has_rol
            FULL JOIN tt_developers td
                ON ( has_rol.role_name = td.role_name )
            CROSS JOIN tt_object_roles tor
            WHERE ( has_rol.role_name IS NULL
                    OR td.role_name IS NULL )
                AND tor.label = 'developer' ) LOOP

        IF r.needs_grant THEN
            EXECUTE format ( 'GRANT %s TO %s ;', r.developer_role, r.role_name ) ;
        ELSE
            EXECUTE format ( 'REVOKE %s FROM %s ;', r.developer_role, r.role_name ) ;
        END IF ;

    END LOOP ;
END ;
$$ ;

/**
* RULE: "Private" and util database objects should only be accessible to schema owners and the developer role.
    * QUESTION: developer role in production???
    * EXCEPTION: The back-end maintenance role needs execute on util_log.manage_partitions
    * EXCEPTION: The logging user needs insert on util_log.dt_proc_log

*/
DO $$
DECLARE
    r record ;
    r2 record ;
BEGIN

    -- Grants to roles other than owner and developer.
    FOR r IN (
        WITH rol AS (
            SELECT role_name
                FROM tt_object_roles
                WHERE label IN ( 'owner', 'developer' )
            UNION
            SELECT DISTINCT owner_name
                FROM util_meta.schemas
        )
        SELECT og.schema_name,
                og.object_name,
                og.base_object_type AS object_type,
                coalesce ( og.calling_signature, '' ) AS calling_signature,
                og.grantee,
                og.privilege_type
            FROM util_meta.object_grants og
            JOIN tt_object_schemas t
                ON ( t.schema_name = og.schema_name )
            LEFT JOIN rol
                ON ( rol.role_name = og.grantee )
            WHERE t.label IN ( 'private', 'util' )
                AND rol.role_name IS NULL ) LOOP

        IF r.object_type = 'schema' THEN

            EXECUTE format (
                    'REVOKE %s ON %s %I FROM %s ;',
                    r.privilege_type,
                    r.object_type,
                    r.schema_name,
                    r.grantee ) ;

        ELSIF r.object_type IN ( 'function', 'procedure' ) THEN

            EXECUTE format (
                    'REVOKE %s ON %s %I.%I ( %s ) FROM %s ;',
                    r.privilege_type,
                    r.object_type,
                    r.schema_name,
                    r.object_name,
                    r.calling_signature,
                    r.grantee ) ;

        ELSE

            EXECUTE format (
                    'REVOKE %s ON %s %I.%I FROM %s ;',
                    r.privilege_type,
                    r.object_type,
                    r.schema_name,
                    r.object_name,
                    r.grantee ) ;

        END IF ;

    END LOOP ;

    -- Missing grants to the developer role.
    FOR r IN (
        SELECT role_name
            FROM tt_object_roles
            WHERE label = 'developer' ) LOOP

        FOR r2 IN (
            WITH granted AS (
                SELECT og.schema_name,
                        og.object_name,
                        og.base_object_type,
                        coalesce ( og.calling_signature, '' ) AS calling_signature,
                        og.grantee,
                        og.privilege_type
                    FROM util_meta.object_grants og
                    JOIN tt_object_schemas t
                        ON ( t.schema_name = og.schema_name )
                    JOIN tt_object_roles rol
                        ON ( rol.role_name = og.grantee )
                    WHERE t.label IN ( 'private', 'util' )
                        AND og.grantee = r.role_name
            )
            SELECT obj.schema_name,
                    obj.object_name,
                    obj.base_object_type AS object_type,
                    coalesce ( obj.calling_signature, '' ) AS calling_signature
                FROM util_meta.objects obj
                LEFT JOIN granted
                    ON ( granted.schema_name = obj.schema_name
                        AND granted.object_name = obj.object_name
                        AND granted.base_object_type = obj.base_object_type
                        AND granted.calling_signature IS NOT DISTINCT FROM obj.calling_signature )
                WHERE granted.grantee IS NULL ) LOOP

            -- database, foreign table, function, index, materialized view,
            -- partitioned table, procedure, schema, sequence, table,
            -- table partition, trigger, type, view

            IF r2.object_type = 'schema' THEN

                EXECUTE format (
                        'GRANT USAGE ON %s %I TO %s ;',
                        r2.object_type,
                        r2.schema_name,
                        r.role_name ) ;

            ELSIF r2.object_type IN ( 'function', 'procedure' ) THEN

                EXECUTE format (
                        'GRANT EXECUTE ON %s %I.%I ( %s ) TO %s ;',
                        r2.object_type,
                        r2.schema_name,
                        r2.object_name,
                        r2.calling_signature,
                        r.role_name ) ;

            ELSIF r2.object_type IN ( 'foreign table', 'materialized view', 'table', 'view' ) THEN

                EXECUTE format (
                        'GRANT SELECT ON %I.%I TO %s ;',
                        r2.schema_name,
                        r2.object_name,
                        r.role_name ) ;

            END IF ;

        END LOOP ;
    END LOOP ;

END ;
$$ ;

/**
* RULE: External (login) users should not have any privileges on tables
  * NOTE: Direct table privileges, if any, should be done through nologin role membership

*/
DO $$
DECLARE
    r record ;
BEGIN

    FOR r IN (
        SELECT og.schema_name,
                og.object_name,
                og.base_object_type AS object_type,
                og.grantee,
                og.privilege_type
            FROM util_meta.object_grants og
            JOIN tt_object_schemas t
                ON ( t.schema_name = og.schema_name )
            JOIN pg_catalog.pg_roles rol
                ON ( rol.rolname::text = og.grantee )
            WHERE og.object_type = 'table'
                AND rol.rolcanlogin ) LOOP

        EXECUTE format (
                'REVOKE %s ON %I.%I FROM %s ;',
                r.privilege_type,
                r.schema_name,
                r.object_name,
                r.grantee ) ;

    END LOOP ;
END ;
$$ ;

/**
* RULE: Update roles should have execute on (non-private) API functions and procedures

*/
DO $$
DECLARE
    r record ;
    r2 record ;
BEGIN

    FOR r IN (
        SELECT role_name
            FROM tt_object_roles
            WHERE label = 'update' ) LOOP

        FOR r2 IN (
            WITH procs AS (
                SELECT obj.schema_name,
                        obj.object_name,
                        obj.base_object_type,
                        coalesce ( obj.calling_signature, '' ) AS calling_signature
                    FROM util_meta.objects obj
                    JOIN tt_object_schemas tos
                        ON ( tos.schema_name = obj.schema_name )
                    WHERE tos.label = 'api'
                        AND obj.base_object_type IN ( 'function', 'procedure' )
                        AND obj.object_name !~ '^_'
                        AND obj.object_name !~ '^priv_'
            )
            SELECT procs.schema_name,
                    procs.object_name,
                    procs.base_object_type AS object_type,
                    coalesce ( procs.calling_signature, '' ) AS calling_signature
                FROM procs
                LEFT JOIN util_meta.object_grants og
                    ON ( og.schema_name = procs.schema_name
                        AND og.object_name = procs.object_name
                        AND og.base_object_type = procs.base_object_type
                        AND og.calling_signature IS NOT DISTINCT FROM procs.calling_signature
                        AND og.grantee = r.role_name ) ) LOOP

            EXECUTE format (
                    'GRANT EXECUTE ON %s %I.%I ( %s ) TO %s ;',
                    r2.object_type,
                    r2.schema_name,
                    r2.object_name,
                    r2.calling_signature,
                    r.role_name ) ;

        END LOOP ;
    END LOOP ;
END ;
$$ ;

/**
* RULE: Read roles should have execute on (non-private) API find, list, and get functions

*/
DO $$
DECLARE
    r record ;
    r2 record ;
BEGIN

    FOR r IN (
        SELECT role_name
            FROM tt_object_roles
            WHERE label = 'read' ) LOOP

        FOR r2 IN (
            WITH procs AS (
                SELECT obj.schema_name,
                        obj.object_name,
                        obj.base_object_type,
                        coalesce ( obj.calling_signature, '' ) AS calling_signature
                    FROM util_meta.objects obj
                    JOIN tt_object_schemas tos
                        ON ( tos.schema_name = obj.schema_name )
                    WHERE tos.label = 'api'
                        AND obj.object_type = 'function'
                        AND ( obj.object_name ~ '^find_'
                            OR obj.object_name ~ '^get_'
                            OR obj.object_name ~ '^list_' )
            )
            SELECT procs.schema_name,
                    procs.object_name,
                    procs.base_object_type AS object_type,
                    coalesce ( procs.calling_signature, '' ) AS calling_signature
                FROM procs
                LEFT JOIN util_meta.object_grants og
                    ON ( og.schema_name = procs.schema_name
                        AND og.object_name = procs.object_name
                        AND og.base_object_type = procs.base_object_type
                        AND og.calling_signature IS NOT DISTINCT FROM procs.calling_signature
                        AND og.grantee = r.role_name ) ) LOOP

            EXECUTE format (
                    'GRANT EXECUTE ON %s %I.%I ( %s ) TO %s ;',
                    r2.object_type,
                    r2.schema_name,
                    r2.object_name,
                    r2.calling_signature,
                    r.role_name ) ;

        END LOOP ;
    END LOOP ;
END ;
$$ ;

/**
* RULE: util_log does need to work for the logger and backend roles

*/
DO $$
DECLARE
    r record ;
    l_passwd text ;
    l_owner text ;
BEGIN

    FOR rs IN (
        SELECT schema_name
            FROM tt_object_schemas
            WHERE schema_name = 'util_log' ) LOOP

        ------------------------------------------------------------------------
        -- Owner
        FOR r IN (
            SELECT role_name
                FROM tt_object_roles
                WHERE label = 'owner' ) LOOP

            l_owner := r.role_name ;
            EXECUTE format ( 'ALTER SERVER loopback_dblink OWNER TO %s', r.role_name ) ;

        END LOOP ;

        ------------------------------------------------------------------------
        -- Logger
        WITH x AS (
            -- upper case letters
            SELECT chr ( ( 65 + round ( random () * 25 ) )::integer ) AS x
                FROM generate_series ( 1, 26 )
            UNION
            -- lower case letters
            SELECT chr ( ( 97 + round ( random () * 25 ) )::integer )
                FROM generate_series ( 1, 26 )
            UNION
            -- numbers
            SELECT chr ( ( 48 + round ( random () * 9 ) )::integer )
                FROM generate_series ( 1, 10 )
        ),
        y AS (
            SELECT x AS chrs
                FROM x
                ORDER BY random ()
                LIMIT ( 20 + round ( random () * 10 ) )
        )
        SELECT array_to_string ( array_agg ( chrs ), '' ) AS passwd
            INTO l_passwd
            FROM y ;

        FOR r IN (
            SELECT role_name
                FROM tt_object_roles
                WHERE label = 'logger' ) LOOP

            EXECUTE format ( 'GRANT CONNECT ON DATABASE %I TO %s ;', current_database ()::text, r.role_name ) ;

            EXECUTE format ( 'GRANT USAGE ON SCHEMA util_log TO %s ;', r.role_name ) ;

            EXECUTE format ( 'GRANT INSERT ON util_log.dt_proc_log TO %s ;', r.role_name ) ;

            EXECUTE format ( 'ALTER ROLE %s LOGIN PASSWORD %L', r.role_name, l_passwd ) ;

            EXECUTE format ('DROP USER MAPPING IF EXISTS FOR %s SERVER loopback_dblink', l_owner ) ;
            EXECUTE format ('DROP USER MAPPING IF EXISTS FOR %s SERVER loopback_dblink', current_user::text ) ;

            EXECUTE format ('CREATE USER MAPPING FOR %s SERVER loopback_dblink
                OPTIONS ( user %L, password %L )', l_owner, r.role_name, l_passwd ) ;

        END LOOP ;

        ------------------------------------------------------------------------
        -- Backend (partition management)
        FOR r IN (
            SELECT role_name
                FROM tt_object_roles
                WHERE label = 'backend' ) LOOP

            EXECUTE format ( 'GRANT CONNECT ON DATABASE %I TO %s ;', current_database ()::text, r.role_name ) ;

            EXECUTE format ( 'GRANT USAGE ON SCHEMA util_log TO %s ;', r.role_name ) ;

            EXECUTE format ( 'GRANT EXECUTE ON FUNCTION util_log.manage_partitions () TO %s ;', r.role_name ) ;

        END LOOP ;

    END LOOP ;

END ;
$$ ;

/**
* RULE: If a role has grants to an object in a schema then it should also have usage on the schema.

* RULE: If a role does not have grants to any objects in a schema then it should not have usage on the schema.

*/
DO $$
DECLARE
    r record ;
BEGIN

    FOR r IN (
        WITH granted_schemas AS (
            SELECT object_name AS schema_name,
                    grantee AS role_name
                FROM util_meta.object_grants
                WHERE object_type = 'schema'
        ),
        granted_objs AS (
            SELECT DISTINCT schema_name,
                    grantee AS role_name
                FROM util_meta.object_grants
                WHERE object_type NOT IN ( 'database', 'schema' )
        )
        SELECT coalesce ( s.schema_name, o.schema_name ) AS schema_name,
                coalesce ( s.role_name, o.role_name ) AS role_name,
                CASE WHEN s.role_name IS NULL THEN true WHEN o.role_name IS NULL THEN false END AS needs_grant
            FROM granted_schemas s
            FULL JOIN granted_objs o
                ON ( s.schema_name = o.schema_name
                    AND s.role_name = o.role_name )
            WHERE s.role_name IS DISTINCT FROM o.role_name ) LOOP

        IF r.needs_grant THEN
            EXECUTE format ( 'GRANT USAGE ON SCHEMA %I TO %s ;', r.schema_name, r.role_name ) ;
        ELSE
            EXECUTE format ( 'REVOKE USAGE ON SCHEMA %I FROM %s ;', r.schema_name, r.role_name ) ;
        END IF ;

    END LOOP ;
END ;
$$ ;

/**
* RULE: Login users should not have any any explicit privileges that are also provided by a granted role

*/
-- TBD

/**
* RULE: Login users that have been granted application roles should have connect on the database?

*/
-- TBD

/**
* Etc.

*/

DROP TABLE tt_developers ;
DROP TABLE tt_object_roles ;
DROP TABLE tt_object_schemas ;
