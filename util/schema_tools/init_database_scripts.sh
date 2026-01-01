#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

init_database_scripts.sh

SYNOPSIS

    init_database_scripts.sh [-o target_directory] -d database_name

DESCRIPTION

    Creates the initial scripts for creating a database.

OPTIONS

    -d database_name

        The name of the database to create scripts for

    -o target_directory

        The name of the directory to create the scripts in (defaults to ../../schema)

    -h

        Displays this help

EOT
    exit 0
}

cd "$(dirname "$0")" || exit 1

########################################################################
# Read the calling args
while getopts 'hd:o:' arg; do
    case ${arg} in
        d) dbName="${OPTARG}" ;;
        h) usage=1 ;;
        o) targetDir="${OPTARG}" ;;
        *) usage=1 ;;
    esac
done

if [[ -n ${usage} ]]; then
    usage
fi

if [[ -z ${dbName} ]]; then
    echo "Please specify a name for the new database"
    usage
fi

if [[ -z ${targetDir} ]]; then
    targetDir=../../schema
fi

########################################################################
if [ ! -d "${targetDir}" ]; then
    mkdir -p "${targetDir}" || exit 1
fi

preamble="
SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;
"

################################################################################
function init_drop_database() {
    fileName=001_drop_database
    psqlFile="${targetDir}"/"${fileName}".sql

    if [[ -f ${psqlFile} ]]; then
        echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    else
        cat <<EOT >"${psqlFile}"
/* *

## Drop database

[${fileName}](${fileName}.sql)

*/

\\c postgres
${preamble}
\\unset ON_ERROR_STOP

-- Since "REVOKE CONNECT ON DATABASE ${dbName} FROM ALL" isn't an option, so:
DO \$\$
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
                WHERE d.datname = '${dbName}'
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
\$\$ ;

-- Ensure that there are no other connections to the database
SELECT pg_terminate_backend ( pid )
    FROM pg_stat_activity
    WHERE pid <> pg_backend_pid ()
        AND datname = '${dbName}' ;

\set ON_ERROR_STOP

DROP DATABASE IF EXISTS ${dbName} ;
EOT
    fi
}

################################################################################
function init_drop_roles() {
    fileName=002_drop_roles
    psqlFile="${targetDir}"/"${fileName}".sql

    if [[ -f ${psqlFile} ]]; then
        echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    else
        cat <<EOT >"${psqlFile}"
/* *
## Drop roles

[${fileName}](${fileName}.sql)

*/
${preamble}
\\unset ON_ERROR_STOP

DROP ROLE IF EXISTS ${dbName}_developer ;
DROP USER IF EXISTS ${dbName}_logger ;
DROP USER IF EXISTS ${dbName}_bend ;
DROP USER IF EXISTS ${dbName}_read ;
DROP USER IF EXISTS ${dbName}_updt ;
DROP ROLE IF EXISTS ${dbName}_owner ;

\\set ON_ERROR_STOP
EOT
    fi
}

################################################################################
function init_create_roles() {
    fileName=003_create_roles
    psqlFile="${targetDir}"/"${fileName}".sql

    if [[ -f ${psqlFile} ]]; then
        echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    else
        cat <<EOT >"${psqlFile}"
/**
## Create roles

[${fileName}](${fileName}.sql)

*/
${preamble}
\\unset ON_ERROR_STOP

CREATE ROLE ${dbName}_owner NOLOGIN
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION ;

COMMENT ON ROLE ${dbName}_owner IS 'Default ownership role for all ${dbName} database objects' ;

CREATE USER ${dbName}_bend NOLOGIN
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION ;

COMMENT ON ROLE ${dbName}_bend IS 'Back-end maintenance role for the ${dbName} database' ;

CREATE USER ${dbName}_logger NOLOGIN
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION ;

COMMENT ON ROLE ${dbName}_logger IS 'Logging role for the ${dbName} database' ;

CREATE USER ${dbName}_read NOLOGIN
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION ;

COMMENT ON ROLE ${dbName}_read IS 'Read-only role for the ${dbName} database' ;

CREATE USER ${dbName}_updt NOLOGIN
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION ;

COMMENT ON ROLE ${dbName}_updt IS 'Update role for the ${dbName} database' ;

CREATE ROLE ${dbName}_developer NOLOGIN
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION ;

COMMENT ON ROLE ${dbName}_developer IS 'Developer role for working with the ${dbName} database' ;

GRANT ${dbName}_read TO ${dbName}_developer ;
GRANT ${dbName}_updt TO ${dbName}_developer ;

\\set ON_ERROR_STOP
EOT
    fi
}

################################################################################
function init_create_database() {
    fileName=004_create_database
    psqlFile="${targetDir}"/"${fileName}".sql

    if [[ -f ${psqlFile} ]]; then
        echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    else
        cat <<EOT >"${psqlFile}"
/**
## Create the database

[${fileName}](${fileName}.sql)

*/
${preamble}
\\unset ON_ERROR_STOP

CREATE DATABASE ${dbName}
    WITH TEMPLATE = template0
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8' ;

COMMENT ON DATABASE ${dbName} IS '${dbName} database.' ;

ALTER DATABASE ${dbName} OWNER TO ${dbName}_owner ;

\\set ON_ERROR_STOP

REVOKE ALL ON DATABASE ${dbName} FROM PUBLIC ;

\\connect ${dbName}

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog ;

--CREATE EXTENSION IF NOT EXISTS postgis ;
--CREATE EXTENSION IF NOT EXISTS fuzzystrmatch ;
CREATE EXTENSION IF NOT EXISTS plpgsql_check ;
EOT
    fi
}

################################################################################
function init_util_schema() {

    owner=${dbName}_owner

    utilDir="${targetDir}"/util_log

    if [[ -d $utilDir ]]; then
        fileName=101_create-util_log
        psqlFile="${targetDir}"/"${fileName}".sql

        if [[ -f ${psqlFile} ]]; then
            echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
        else
            cat <<EOT >"${psqlFile}"
/**
### Logging

[${fileName}](${fileName}.sql)

Setup [util_log](https://github.com/gsiems/pg-util_log) to provide persistent
logging for functions, procedures, and views.

*/

\\connect ${dbName}
${preamble}

-- set the search path so dblink creates properly
SET search_path = public, pg_catalog ;

CREATE EXTENSION IF NOT EXISTS dblink SCHEMA public ;

SET search_path = pg_catalog, public ;

\\unset ON_ERROR_STOP

DROP SCHEMA IF EXISTS util_log CASCADE ;

CREATE SCHEMA IF NOT EXISTS util_log ;

COMMENT ON SCHEMA util_log IS 'Schema and objects for logging database function and procedure calls' ;

ALTER SCHEMA util_log OWNER TO ${owner} ;
GRANT USAGE ON SCHEMA util_log TO ${owner} ;
REVOKE USAGE ON SCHEMA util_log FROM public ;

DROP SERVER IF EXISTS loopback_dblink CASCADE ;

CREATE SERVER loopback_dblink FOREIGN DATA WRAPPER dblink_fdw
    OPTIONS ( hostaddr '127.0.0.1', dbname '${dbName}' ) ;

ALTER SERVER loopback_dblink OWNER TO ${owner} ;

GRANT CONNECT ON DATABASE example_db TO ${dbName}_logger ;

GRANT USAGE ON SCHEMA util_log TO ${dbName}_logger ;

GRANT INSERT ON util_log.dt_proc_log TO ${dbName}_logger ;

/**
Since the logging is using dblink as a loopback, the password for the linked
user and user mappings can be dynamically set/used.

*/
DO
\$\$
DECLARE
    r record ;
BEGIN
    FOR r IN (
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
        SELECT '${dbName}_logger' AS usr,
                array_to_string ( array_agg ( chrs ), '' ) AS passwd
            FROM y ) LOOP

        EXECUTE format ('ALTER ROLE %I LOGIN PASSWORD %L', r.usr, r.passwd ) ;

        EXECUTE format ('CREATE USER MAPPING FOR ${owner} SERVER loopback_dblink
            OPTIONS ( user %L, password %L )', r.usr, r.passwd ) ;

        EXECUTE format ('CREATE USER MAPPING FOR CURRENT_USER SERVER loopback_dblink
            OPTIONS ( user %L, password %L )', r.usr, r.passwd ) ;

    END LOOP ;
END ;
\$\$ ;

\\set ON_ERROR_STOP

-- Tables --------------------------------------------------------------
\\i util_log/table/st_log_level.sql
\\i util_log/table/dt_proc_log.sql
\\i util_log/table/dt_last_logged.sql

-- Views ---------------------------------------------------------------
\\i util_log/view/dv_proc_log.sql
\\i util_log/view/dv_proc_log_today.sql
\\i util_log/view/dv_proc_log_last_hour.sql
\\i util_log/view/dv_proc_log_last_day.sql
\\i util_log/view/dv_proc_log_last_week.sql

-- Functions -----------------------------------------------------------
\\i util_log/function/dici.sql
\\i util_log/function/manage_partitions.sql
\\i util_log/function/update_last_logged.sql

-- Procedures ----------------------------------------------------------
\\i util_log/procedure/log_to_dblink.sql
\\i util_log/procedure/log_begin.sql
\\i util_log/procedure/log_debug.sql
\\i util_log/procedure/log_exception.sql
\\i util_log/procedure/log_finish.sql
\\i util_log/procedure/log_info.sql

-- Query bug -----------------------------------------------------------
\\i util_log/function/query_bug.sql
EOT

        fi
    fi

    utilDir="${targetDir}"/util_meta

    if [[ -d $utilDir ]]; then
        fileName=102_create-util_meta
        psqlFile="${targetDir}"/"${fileName}".sql

        if [[ -f ${psqlFile} ]]; then
            echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
        else
            cat <<EOT >"${psqlFile}"
/**
### Metadata

[${fileName}](${fileName}.sql)

Setup util_meta for generating the DDL for creating functions, procedures, and
views.

*/

\\connect ${dbName}
${preamble}
\\unset ON_ERROR_STOP

DROP SCHEMA IF EXISTS util_meta CASCADE ;

\\set ON_ERROR_STOP

CREATE SCHEMA IF NOT EXISTS util_meta ;

COMMENT ON SCHEMA util_meta IS 'Database meta-data for objects (views, functions, procedures) for creating database API objects.' ;

ALTER SCHEMA util_meta OWNER TO ${owner} ;
GRANT USAGE ON SCHEMA util_meta TO ${owner} ;
REVOKE USAGE ON SCHEMA util_meta FROM public ;

-- Types -----------------------------------------------------------------------
\\i util_meta/type/ut_parameters.sql
\\i util_meta/type/ut_object.sql
\\i util_meta/type/ut_parent_table.sql

-- Tables ----------------------------------------------------------------------
\\i util_meta/table/st_default_param.sql
\\i util_meta/table/rt_config_default.sql
\\i util_meta/table/rt_plural_word.sql

-- Views -----------------------------------------------------------------------
\\i util_meta/view/conftypes.sql
\\i util_meta/view/contypes.sql
\\i util_meta/view/prokinds.sql
\\i util_meta/view/relkinds.sql
\\i util_meta/view/typtypes.sql

\\i util_meta/view/schemas.sql
\\i util_meta/view/objects.sql
\\i util_meta/view/columns.sql
\\i util_meta/view/foreign_keys.sql
\\i util_meta/view/object_grants.sql
\\i util_meta/view/dependencies.sql
\\i util_meta/view/extensions.sql
\\i util_meta/view/indexes.sql

-- Functions -------------------------------------------------------------------

-- Common utility functions
\\i util_meta/function/_to_plural.sql
\\i util_meta/function/_to_singular.sql
\\i util_meta/function/_base_name.sql
\\i util_meta/function/_base_order.sql

\\i util_meta/function/_resolve_parameter.sql

\\i util_meta/function/_append_parameter.sql

\\i util_meta/function/_cleanup_whitespace.sql
\\i util_meta/function/_indent.sql
\\i util_meta/function/_is_valid_object.sql
\\i util_meta/function/_uses_logging.sql
\\i util_meta/function/_new_line.sql
\\i util_meta/function/_table_noun.sql
\\i util_meta/function/_proc_parameters.sql
\\i util_meta/function/_calling_parameters.sql
\\i util_meta/function/_boolean_casting.sql
\\i util_meta/function/_find_func.sql
\\i util_meta/function/_view_name.sql
\\i util_meta/function/_find_view.sql

\\i util_meta/function/_find_dt_parent.sql

-- Snippet functions
\\i util_meta/function/_snip_declare_variables.sql
\\i util_meta/function/_snip_documentation_block.sql

\\i util_meta/function/_snip_log_params.sql
\\i util_meta/function/_snip_object_comment.sql
\\i util_meta/function/_snip_owners_and_grants.sql
\\i util_meta/function/_snip_resolve_id.sql
\\i util_meta/function/_snip_resolve_user_id.sql

\\i util_meta/function/_snip_function_backmatter.sql
\\i util_meta/function/_snip_function_frontmatter.sql
\\i util_meta/function/_snip_procedure_backmatter.sql
\\i util_meta/function/_snip_procedure_frontmatter.sql

\\i util_meta/function/_snip_get_permissions.sql
\\i util_meta/function/_snip_permissions_check.sql

--------------------------------------------------------------------------------
-- "Final" DDL generating functions for "regular API" objects
\\i util_meta/function/mk_view.sql
\\i util_meta/function/mk_user_type.sql
\\i util_meta/function/mk_object_migration.sql

\\i util_meta/function/mk_resolve_id_function.sql
\\i util_meta/function/mk_can_do_function_shell.sql

\\i util_meta/function/mk_find_function.sql
\\i util_meta/function/mk_get_function.sql
\\i util_meta/function/mk_list_function.sql
\\i util_meta/function/mk_list_children_function.sql

\\i util_meta/function/mk_priv_delete_procedure.sql
\\i util_meta/function/mk_priv_insert_procedure.sql
\\i util_meta/function/mk_priv_update_procedure.sql
\\i util_meta/function/mk_priv_upsert_procedure.sql

\\i util_meta/function/mk_api_procedure.sql

--------------------------------------------------------------------------------
-- JSON utility functions
\\i util_meta/function/_json_identifier.sql

-- JSON snippet functions
\\i util_meta/function/_snip_json_agg_build_object.sql
\\i util_meta/function/_snip_json_build_object.sql

-- "Final" DDL generating functions for "JSON API" objects
\\i util_meta/function/mk_json_view.sql
\\i util_meta/function/mk_json_user_type.sql

\\i util_meta/function/mk_json_function_wrapper.sql

--------------------------------------------------------------------------------
-- Testing functions
\\i util_meta/function/mk_test_procedure_wrapper.sql
EOT

        fi
    fi

    fileName=006_create_util_schemas
    psqlFile="${targetDir}"/"${fileName}".sql

    if [[ -f ${psqlFile} ]]; then
        echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    else
        cat <<EOT >"${psqlFile}"
/**
## Create the utility schemas

[${fileName}](${fileName}.sql)

*/

\\connect ${dbName}
${preamble}
EOT

        ls "${targetDir}" | grep -P "^1.+sql" | awk '{print "\\i " $1}' >>"${psqlFile}"
    fi
}

################################################################################
function init_create_data_schemas() {

    fileName=007_create_data_schemas
    psqlFile="${targetDir}"/"${fileName}".sql

    if [[ -f ${psqlFile} ]]; then
        echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    else
        cat <<EOT >"${psqlFile}"
/**
## Create the data schemas

[${fileName}](${fileName}.sql)

*/

\\connect ${dbName}
${preamble}

EOT
    fi
}

################################################################################
function init_create_api_schemas() {
    fileName=008_create_api_schemas
    psqlFile="${targetDir}"/"${fileName}".sql

    if [[ -f ${psqlFile} ]]; then
        echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    else
        cat <<EOT >"${psqlFile}"
/**
## Create the API schemas

[${fileName}](${fileName}.sql)

*/

\\connect ${dbName}
${preamble}

EOT
    fi
}

################################################################################
function init_ownership_and_permissions() {
    fileName=501_ownership_and_permissions
    psqlFile="${targetDir}"/"${fileName}".sql

    if [[ -f ${psqlFile} ]]; then
        echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    else
        cat <<EOT >"${psqlFile}"
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

\\connect ${dbName}
${preamble}
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
        ( '${dbName}_owner', 'owner' ),
        ( '${dbName}_developer', 'developer' ),
        ( '${dbName}_bend', 'backend' ),
        ( '${dbName}_logger', 'logger' ),
        ( '${dbName}_read', 'read' ),
        ( '${dbName}_updt', 'update' ) ;

INSERT INTO tt_developers
    VALUES ( current_user::text ) ;

--INSERT INTO tt_developers
--    VALUES
--        ( 'alice' ),
--        ( 'bob' ),
--        ( 'eve' ) ;

-- Schema type labels used: api, private, util
INSERT INTO tt_object_schemas
    VALUES
        --( 'example_admin', 'api' ),
        --( 'example_admin_json', 'api' ),
        --( 'priv_example_admin', 'private' ),
        --( 'priv_example_api', 'private' ),
        --( 'example', 'api' ),
        --( 'example_data', 'private' ),
        --( 'example_json', 'api' ),
        --( 'priv_example', 'private' ),
        ( 'util_log', 'util' ),
        ( 'util_meta', 'util' ) ;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
* RULE: Database objects should all be owned by the same NOLOGIN role

*/
DO \$\$
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
\$\$ ;

/**
* RULE: The public role should have minimal permissions

*/
DO \$\$
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
\$\$ ;

/**
* RULE: Developer users should have developer role membership
    * QUESTION: developer role in production???
    * NOTE: To be really thorough this could be recursive

* RULE: Non-developer users should NOT have developer role membership
    * NOTE: To be really thorough this should be recursive

*/
DO \$\$
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
\$\$ ;

/**
* RULE: "Private" and util database objects should only be accessible to schema owners and the developer role.
    * QUESTION: developer role in production???
    * EXCEPTION: The back-end maintenance role needs execute on util_log.manage_partitions
    * EXCEPTION: The logging user needs insert on util_log.dt_proc_log

*/
DO \$\$
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
\$\$ ;

/**
* RULE: External (login) users should not have any privileges on tables
  * NOTE: Direct table privileges, if any, should be done through nologin role membership

*/
DO \$\$
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
\$\$ ;

/**
* RULE: Update roles should have execute on (non-private) API functions and procedures

*/
DO \$\$
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
\$\$ ;

/**
* RULE: Read roles should have execute on (non-private) API find, list, and get functions

*/
DO \$\$
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
\$\$ ;

/**
* RULE: util_log does need to work for the logger and backend roles

*/
DO \$\$
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
\$\$ ;

/**
* RULE: If a role has grants to an object in a schema then it should also have usage on the schema.

* RULE: If a role does not have grants to any objects in a schema then it should not have usage on the schema.

*/
DO \$\$
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
\$\$ ;

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

EOT
    fi
}

################################################################################
function init_role_passwords() {
    fileName=601_role_passwords
    psqlFile="${targetDir}"/"${fileName}".sql

    if [[ -f ${psqlFile} ]]; then
        echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    else
        cat <<EOT >"${psqlFile}"
/**
## Role Passwords

[${fileName}](${fileName}.sql)

If it is necessary to hard-code some role passwords, ensure that they are not
hard-coded in any files that are version controlled as they then become visible
to anyone who has access to the code repository. Examples of this would include
credentials for foreign data wrappers to databases on different servers.

Instead, consider using files that are not version controlled to set the
passwords and set up some other mechanism for sharing them as needed.

*/

EOT
    fi
}

function init_run_all() {
    fileName=000_run_all

    shFile="${targetDir}"/"${fileName}".sh
    if [[ -f ${shFile} ]]; then
        echo "${shFile} already exists. Cowardly refusing to overwrite it."
    else
        cat <<EOT >"${shFile}"
#!/usr/bin/env bash

cd "\$(dirname "\$0")" || exit 1

psql -f 000_run_all.sql postgres
EOT

        chmod 700 "${shFile}"
    fi

    fileName=000_run_all
    psqlFile="${targetDir}"/"${fileName}".sql

    if [[ -f ${psqlFile} ]]; then
        echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    else
        cat <<EOT >"${psqlFile}"
\\i 001_drop_database.sql
\\i 002_drop_roles.sql
\\i 003_create_roles.sql
\\i 004_create_database.sql
\\i 006_create_util_schemas.sql
\\i 007_create_data_schemas.sql
\\i 008_create_api_schemas.sql

\\i 501_ownership_and_permissions.sql
\\i 601_role_passwords.sql
EOT
    fi
}

################################################################################
init_drop_database
init_drop_roles
init_create_roles
init_create_database
init_util_schema
init_create_data_schemas
init_create_api_schemas
init_ownership_and_permissions
init_role_passwords
init_run_all
