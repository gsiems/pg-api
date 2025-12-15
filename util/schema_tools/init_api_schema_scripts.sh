#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

init_api_schema_scripts.sh

SYNOPSIS

    init_api_schema_scripts.sh schema_name [schema_name] [schema_name] [schema_name] [...]

DESCRIPTION

    Creates both the directory structure for one or more new API schemas
    and the initial scripts for creating the schemas and schema objects.

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

if [[ -z ${1} ]]; then
    echo "Please specify a name for the new schema"
    usage
fi

for schema in "$@"; do
    mkdir "${targetDir}/${schema}"
    mkdir -p "${targetDir}"/{,as_generated/}"${schema}"/{function,materialized_view,procedure,type,view}


    lastNum=$(ls "${targetDir}" | grep -P "^3.+sql" | cut -d '_' -f 1 | tail -n 1)
    if [[ -z ${lastNum} ]]; then
        newNum=301
    else
        newNum=$((lastNum + 1))
    fi

    fileName="${newNum}_create-${schema}"
    psqlFile="${targetDir}"/"${fileName}".sql

    cat <<EOT >"${psqlFile}"
/**
## Create the ${schema} schema

[${fileName}](${fileName}.sql)

*/

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;

CREATE SCHEMA IF NOT EXISTS ${schema} ;

COMMENT ON SCHEMA ${schema} IS 'TBD' ;

--ALTER SCHEMA ${schema} OWNER TO TBD ;
--GRANT USAGE ON SCHEMA ${schema} TO TBD ;
REVOKE USAGE ON SCHEMA ${schema} FROM public ;

-- Types -----------------------------------------------------------------------

-- Tables ----------------------------------------------------------------------

-- Views and Materialized Views ------------------------------------------------

-- Functions -------------------------------------------------------------------

-- Procedures ------------------------------------------------------------------

EOT

echo "\\i ${fileName}.sql">>"${targetDir}"/008_create_api_schemas.sql

done
