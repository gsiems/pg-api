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

        The name directory to create the scripts in (defaults to ../../schema)

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

\connect ${dbName}
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

\connect ${dbName}
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

\connect ${dbName}
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

[${fileName}](${fileName}.sql)

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

\connect ${dbName}
${preamble}

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
