#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

init_database_scripts.sh

SYNOPSIS

    init_database_scripts.sh database_name

DESCRIPTION

    Creates the initial scripts for creating a database.

EOT
    exit 0
}

################################################################################
# Calling arguments and initialization
cd "$(dirname "$0")" || exit 1

targetDir=../../schema
if [ ! -d "${targetDir}" ]; then
    mkdir -p "${targetDir}"
fi

dbName="${1}"

if [[ -z ${dbName} ]]; then
    echo "Please specify a name for the new database"
    usage
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
fileName=001_drop_database
psqlFile="${targetDir}"/"${fileName}".sql

if [[ -f ${psqlFile} ]]; then
    echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    exit 1
fi

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

################################################################################
fileName=002_drop_roles
psqlFile="${targetDir}"/"${fileName}".sql

if [[ -f ${psqlFile} ]]; then
    echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    exit 1
fi

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

################################################################################
fileName=003_create_roles
psqlFile="${targetDir}"/"${fileName}".sql

if [[ -f ${psqlFile} ]]; then
    echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    exit 1
fi

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

################################################################################
fileName=004_create_database
psqlFile="${targetDir}"/"${fileName}".sql

if [[ -f ${psqlFile} ]]; then
    echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    exit 1
fi

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

################################################################################
fileName=006_create_util_schemas
psqlFile="${targetDir}"/"${fileName}".sql

if [[ -f ${psqlFile} ]]; then
    echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    exit 1
fi

cat <<EOT >"${psqlFile}"
/**
## Create the utility schemas

[${fileName}](${fileName}.sql)

*/

${preamble}

\connect ${dbName}

EOT

ls "${targetDir}" | grep -P "^1.+sql" | awk '{print "\\i " $1}' >>${psqlFile}

################################################################################
fileName=007_create_data_schemas
psqlFile="${targetDir}"/"${fileName}".sql

if [[ -f ${psqlFile} ]]; then
    echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    exit 1
fi

cat <<EOT >"${psqlFile}"
/**
## Create the data schemas

[${fileName}](${fileName}.sql)

*/

${preamble}

\connect ${dbName}

EOT

################################################################################
fileName=008_create_api_schemas
psqlFile="${targetDir}"/"${fileName}".sql

if [[ -f ${psqlFile} ]]; then
    echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
    exit 1
fi

cat <<EOT >"${psqlFile}"
/**
## Create the API schemas

[${fileName}](${fileName}.sql)

*/

${preamble}

\connect ${dbName}

EOT
