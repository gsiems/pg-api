#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

init_schema_scripts.sh

SYNOPSIS

    init_schema_scripts.sh [-o target_directory] [-t schema_type] -s schema_name[,schema_name[,schema_name[,...]]]

DESCRIPTION

    Creates both the directory structure for one or more new schemas and the
    initial scripts for creating the schemas and schema objects.

OPTIONS

    -o directory_name

        The name of the directory to create the scripts in (defaults to ../../schema)

    -s schema_name(s)

        The comma-separated list of schemas to create directories and scripts for

    -t schema type {data|api}

        The type of schema directories and scripts to create (defaults to api)

    -h

        Displays this help

EOT
    exit 0
}

cd "$(dirname "$0")" || exit 1

########################################################################
# Read the calling args
while getopts 'ho:s:t:' arg; do
    case ${arg} in
        h) usage=1 ;;
        o) targetDir="${OPTARG}" ;;
        s) schemas="${OPTARG}" ;;
        t) schemaType="${OPTARG}" ;;
        *) usage=1 ;;
    esac
done

if [[ -n ${usage} ]]; then
    usage
fi

if [[ -z ${schemas} ]]; then
    echo "Please specify one or more schema names"
    usage
fi

if [[ -z ${targetDir} ]]; then
    targetDir=../../schema
fi

if [[ -z ${schemaType} ]]; then
    schemaType=api
fi

if [ ! -d "${targetDir}" ]; then
    mkdir -p "${targetDir}" || exit 1
fi

dbName=$(grep -P 'ALTER DATABASE .+ OWNER TO' "${targetDir}"/004_create_database.sql | awk '{print $3}')
if [[ -z ${dbName} ]]; then
    echo "Could not determine database name."
    exit 1
fi

owner=$(grep -P 'ALTER DATABASE .+ OWNER TO' "${targetDir}"/004_create_database.sql | awk '{print $6}')
if [[ -z ${owner} ]]; then
    owner=TBD
fi

################################################################################
function get_new_num() {
    local range="${1}"

    lastFile=$(find "${targetDir}" -maxdepth 1 -name "${range}*.sql" | sort | tail -n 1)
    if [[ -z ${lastFile} ]]; then
        newNum="${range}01"
    else
        lastNum=$(echo "${lastFile}" | awk -F '/' '{print $NF}' | cut -d '_' -f 1)
        newNum=$((lastNum + 1))
    fi

    echo ${newNum}
}

function init_api_schema() {
    local schema="${1}"

    psqlFile=$(find "${targetDir}" -type f -name "3*create-${schema}.sql" | head -n 1)

    if [[ -f ${psqlFile} ]]; then
        echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
        return
    fi

    mkdir -p "${targetDir}"/"${schema}"/{function,materialized_view,procedure,type,view}

    newNum=$(get_new_num 3)
    fileName="${newNum}_create-${schema}"
    psqlFile="${targetDir}"/"${fileName}".sql

    cat <<EOT >"${psqlFile}"
/**
## Create the ${schema} schema

[${fileName}](${fileName}.sql)

*/

\\connect ${dbName}

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;

CREATE SCHEMA IF NOT EXISTS ${schema} ;

COMMENT ON SCHEMA ${schema} IS 'TBD' ;

ALTER SCHEMA ${schema} OWNER TO ${owner} ;
GRANT USAGE ON SCHEMA ${schema} TO ${owner} ;
REVOKE USAGE ON SCHEMA ${schema} FROM public ;

-- Types -----------------------------------------------------------------------

-- Views and Materialized Views ------------------------------------------------

-- Functions -------------------------------------------------------------------

-- Procedures ------------------------------------------------------------------

EOT

    echo "\\i ${fileName}.sql" >>"${targetDir}"/008_create_api_schemas.sql
}

function init_data_schema() {
    local schema="${1}"

    psqlFile=$(find "${targetDir}" -type f -name "2*create-${schema}.sql" | head -n 1)

    if [[ -f ${psqlFile} ]]; then
        echo "${psqlFile} already exists. Cowardly refusing to overwrite it."
        return
    fi

    mkdir -p "${targetDir}"/"${schema}"/{foreign_server,foreign_table,function,sequence,table}

    newNum=$(get_new_num 2)
    fileName="${newNum}_create-${schema}"
    psqlFile="${targetDir}"/"${fileName}".sql

    cat <<EOT >"${psqlFile}"
/**
## Create the ${schema} schema

[${fileName}](${fileName}.sql)

*/

\\connect ${dbName}

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;

CREATE SCHEMA IF NOT EXISTS ${schema} ;

COMMENT ON SCHEMA ${schema} IS 'TBD' ;

ALTER SCHEMA ${schema} OWNER TO ${owner} ;
GRANT USAGE ON SCHEMA ${schema} TO ${owner} ;
REVOKE USAGE ON SCHEMA ${schema} FROM public ;

-- Foreign Server --------------------------------------------------------------

-- Foreign Table ---------------------------------------------------------------

-- Sequences -------------------------------------------------------------------

-- Functions -------------------------------------------------------------------

-- Tables ----------------------------------------------------------------------

EOT

    echo "\\i ${fileName}.sql" >>"${targetDir}"/007_create_data_schemas.sql
}

################################################################################
oldIFS="${IFS}"
IFS=','
read -r -a array <<<"$schemas"

for schema in "${array[@]}"; do

    case "${schemaType}" in
        data) init_data_schema "${schema}" ;;
        api) init_api_schema "${schema}" ;;
        *)
            echo "Unknown schema type specified"
            usage
            ;;
    esac

done

IFS="${oldIFS}"
