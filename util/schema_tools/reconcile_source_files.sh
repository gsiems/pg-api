#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

reconcile_source_files.sh

SYNOPSIS

    reconcile_source_files.sh

DESCRIPTION

    Reconciles the current list of DDL files in the schema directories with the
    includes '\i' file list contained in the create-[schema_name].sql files.

    Included files that no longer exist should get commented out and new files
    should get appended to the end of the appropriate create-[schema_name].sql
    file.

EOT
    exit 0
}

cd "$(dirname "$0")" || exit 1

targetDir=../../schema
cd "$(targetDir "$0")" || exit 1

function append_includes_list() {
    local schema="${1}"
    local fileName="${2}"

    # For each object type that we care about
    for objType in Sequence Table Foreign_Table View Materialized_View Type Function Procedure; do

        objLabel="$(echo "${objType}" | tr '_' ' ')"
        typeDir=$(echo "${objType}" | tr '[:upper:]' '[:lower:]')

        # Check if there is a sub-directory for the object type
        for sd in $(find "${schema}" -mindepth 1 -maxdepth 2 -type d ! -empty -name "${typeDir}"); do

            echo "" >>"${fileName}"
            tmp="-- ${objLabel}s ------------------------------------------------------------------------------"
            echo "${tmp:0:80}" >>"${fileName}"

            # Add the DDL (sql) files
            for sqlFile in $(find "${sd}" -mindepth 1 -maxdepth 2 -type f ! -empty -name "*.sql" | sort); do
                echo "\i ${sqlFile}" >>"${fileName}"
            done
        done
    done
}

function new_create_schema_file() {
    local schema="${1}"

    local newFile="xxx_create-${schema}.sql"

    cat <<EOT >"${newFile}"
DROP SCHEMA IF EXISTS ${schema} CASCADE ;

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = on ;
SET check_function_bodies = true ;
SET client_min_messages = warning ;

CREATE SCHEMA IF NOT EXISTS ${schema} ;

COMMENT ON SCHEMA ${schema} IS 'TBD' ;

EOT

    append_includes_list "${schema}" "${newFile}"
}

function update_schema_file() {
    local schema="${1}"
    local currentFile="${2}"
    local newFilesList
    local newFile

    newFilesList=$(mktemp -p . XXXXXXXXXX.tmp.tmp)
    newFile=$(mktemp -p . XXXXXXXXXX.sql.tmp)

    append_includes_list "${schema}" "${newFilesList}"

    local fileChanged=0
    local oldIFS="${IFS}"
    IFS=

    # Compare the current file to the new list of files. If line is a file
    # include '\i ...' and the included file isn't in new list then comment it
    # out
    while read -r line; do

        case "${line}" in

            '\i '*)
                # if \i and not for any currently existing sql file then comment out
                local trimmed
                local matched
                trimmed=$(echo "${line}" | sed 's/[[:space:]]*$//')
                matched=$(grep "${trimmed}" "${newFilesList}")

                if [ -z "${matched}" ]; then
                    echo "--${trimmed}" >>"${newFile}"
                    fileChanged=1
                else
                    echo "${trimmed}" >>"${newFile}"
                    if [ "${trimmed}" != "${line}" ]; then
                        # cleanup trailing whitespace
                        fileChanged=1
                    fi
                fi
                ;;

            *)
                echo "${line}" >>"${newFile}"
                ;;
        esac

    done <"${currentFile}"

    # Compare the new list of files to the current file. If the new file isn't
    # in the current file then append it to the current file
    local hasNew
    hasNew=0

    while read -r line; do

        case "${line}" in

            '\i '*)
                local matched
                matched=$(grep "${line}" "${currentFile}")
                if [ -z "${matched}" ]; then

                    if [ "${hasNew}" == "0" ]; then
                        local hdr
                        echo "" >>"${newFile}"
                        hdr="-- NEW FILES: $(date) -------------------------------------------------------------------------" >>"${newFile}"
                        echo "${hdr:0:80}" >>"${newFile}"
                        hasNew=1
                    fi

                    echo "${line}" >>"${newFile}"
                    fileChanged=1

                fi
                ;;
        esac

    done <"${newFilesList}"

    IFS="${oldIFS}"

    if [ "${fileChanged}" == "1" ]; then
        mv "${newFile}" "${currentFile}"
    else
        rm "${newFile}"
    fi

    rm "${newFilesList}"
}

for schema in $(find . -mindepth 1 -maxdepth 1 -type d ! -empty | sed 's/^\.\///'); do

    currentFile=$(ls | grep -P "[0-9]+_create-${schema}.sql")

    if [ -z "${currentFile}" ]; then
        new_create_schema_file "${schema}"
    else
        update_schema_file "${schema}" "${currentFile}"
    fi

done
