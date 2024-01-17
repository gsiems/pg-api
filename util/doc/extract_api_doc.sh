#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

extract_api_doc.sh

SYNOPSIS

    extract_api_doc.sh [-H] [-d] [-p] [-u] [-s] [-t] [-h]

DESCRIPTION

    Generates API documentstion by extracting comment blocks from object DDL
    files (as markdoown files).

    Blocks to extract consist of a separate comment start line that has two or
    more asteriscs and end with a separate end line '*/'.

    /**
    Comments to extract
    */

    /*
    Comments to ignore
    */

OPTIONS

    -H host

        The host to connect to (defaults to localhost)

    -d database_name

        The name of the database to connect to (defaults to $USER)

    -p port

        The port to connect as (defaults to $PGPORT then 5432)

    -u user

        The name of the user to connect as (defaults to $USER)

    -s source_directory

        The directory to read the source code from (defaults to the project schema directory)

    -t target_directory

        The directory to write the API documentation to ( defaults to the doc/api directory)

    -h

        Displays this help

EOT
    exit 0
}

################################################################################
# Calling arguments and initialization
cd "$(dirname "$0")"

while getopts 'hd:p:s:t:u:' arg; do
    case ${arg} in
        d) db=${OPTARG} ;;
        H) hostName=${OPTARG} ;;
        h) usage=1 ;;
        p) port=${OPTARG} ;;
        s) sourceDir=${OPTARG} ;;
        t) targetDir=${OPTARG} ;;
        u) usr=${OPTARG} ;;
    esac
done

if [ ! -z "${usage}" ]; then
    usage
fi

if [ -z "${usr}" ]; then
    if [ ! -z "${PGUSER}" ]; then
        usr=${PGUSER}
    else
        usr=${USER}
    fi
fi
if [ -z "${db}" ]; then
    if [ ! -z "${PGDATABASE}" ]; then
        db=${PGDATABASE}
    else
        db=${USER}
    fi
fi
if [ -z "${port}" ]; then
    if [ ! -z "${PGPORT}" ]; then
        port=${PGPORT}
    else
        port=5432
    fi
fi

if [ -z "${hostName}" ]; then
    hostName=localhost
fi
if [ -z "${sourceDir}" ]; then
    sourceDir=../../schema
fi

if [ -z "${targetDir}" ]; then
    targetDir=../../doc/api
fi

if [ ! -d ${sourceDir} ]; then
    echo "Source directory (${sourceDir}) does not exist"
    exit 1
fi

if [ ! -d ${targetDir} ]; then
    mkdir -p ${targetDir}
fi

################################################################################
function extract_schema_toc() {
    local ddlFile=${1}
    local docFile=${2}

    # Build the TOC
    while read rec; do

        local objectType=$(echo $rec | cut -d ":" -f 1)
        local objectName=$(echo $rec | cut -d ":" -f 2)
        local returnType=$(echo $rec | cut -d ":" -f 4)
        local link=$(echo "${objectType}-${objectName}" | tr "[A-Z]" "[a-z]")

        case "${objectType}" in
            "function")
                echo " * Function [${objectName}](#${link}) returns ${returnType}" >>${docFile}
                ;;
            "procedure")
                echo " * Procedure [${objectName}](#${link})" >>${docFile}
                ;;
        esac

    done <${ddlFile}
    wait
}

function extract_object_comments() {
    local ddlFile=${1}
    local docFile=${2}

    # Extract the doc
    while read rec; do

        local objectType=$(echo $rec | cut -d ":" -f 1)
        local objectName=$(echo $rec | cut -d ":" -f 2)
        local objectPath=$(echo $rec | cut -d ":" -f 3)
        local returnType=$(echo $rec | cut -d ":" -f 4)
        local sourceLink

        filePath="${sourceDir}/"$(echo $objectPath | cut -d "/" -f 2-)

        echo "" >>${docFile}
        echo "[top](#top)" >>${docFile}

        if [ -f "${filePath}" ]; then
            sourceLink="[${objectName}](../../${objectPath})"
        else
            sourceLink="${objectName}"
        fi

        case "${objectType}" in
            "function")
                echo "## Function ${sourceLink}" >>${docFile}
                echo "Returns ${returnType}" >>${docFile}
                ;;
            "procedure")
                echo "## Procedure ${sourceLink}" >>${docFile}
                ;;
        esac
        echo "" >>${docFile}

        if [ -f "${filePath}" ]; then

            local inDoc=0

            while read line; do

                case ${line} in

                    /\*\**)
                        inDoc=1
                        ;;
                    *\*/)
                        inDoc=0
                        ;;
                    *)
                        if [ "${inDoc}" == "1" ]; then
                            echo "${line}" | sed 's/\+[[:space:]]*$//;s/[[:space:]]*$//' >>${docFile}
                        fi
                        ;;
                esac

            done <${filePath}
            wait

        else

            echo "No source file found" >>${docFile}

        fi

    done <${ddlFile}
    wait
}

function extract_schema_documentation() {
    local dir=${1}
    local schema=${2}

    local psqlFile=$(mktemp -p . XXXXXXXXXX.sql.tmp)
    local outFile=$(mktemp -p . XXXXXXXXXX.sql.tmp)
    local docFile="${dir}/${schema}.md"
    local lastType=""

    echo "| [Home](../readme.md) | [API](readme.md) | ${schema} |" >${docFile}
    echo "" >>${docFile}
    echo '## Index<a name="top"></a>' >>${docFile}
    echo "" >>${docFile}

    cat <<EOT >${psqlFile}
SELECT DISTINCT concat_ws ( ':',
            object_type,
            object_name,
            concat_ws ( '/', directory_name, file_name ),
            CASE
                WHEN result_data_type IS NULL THEN 'none'
                ELSE result_data_type
                END
             )
    FROM util_meta.objects
    WHERE schema_name = '${schema}'
        AND object_type IN ( 'function', 'procedure' )
        -- exclude private objects
        AND object_name !~ '^_'
        AND object_name !~ '^priv_'
    ORDER BY 1 ;
EOT

    psql -t -A -U $usr -h ${hostName} -f ${psqlFile} -d ${db} >${outFile}

    extract_schema_toc ${outFile} ${docFile}
    extract_object_comments ${outFile} ${docFile}

    rm ${psqlFile}
    rm ${outFile}
}

function extract_documentation() {

    local tmpDir=$(mktemp -d -p . XXXXXXXXXX.tmp)
    local psqlFile=$(mktemp -p . XXXXXXXXXX.sql.tmp)
    local outFile=$(mktemp -p . XXXXXXXXXX.out.tmp)
    local readmeFile="${tmpDir}/readme.md"

    echo "| [Home](../readme.md) | API |" >${readmeFile}
    echo "" >>${readmeFile}

    cat <<EOT >${psqlFile}
SELECT schema_name
    FROM util_meta.schemas
    WHERE schema_name NOT IN ( 'public', 'util_log', 'util_meta' )
        ---- Exclude private schemas
        --AND schema_name !~ '^_'
        --AND schema_name !~ '^priv_'
        --AND schema_name !~ '_priv$'
        ---- Exclude "backup" schemas
        --AND schema_name !~ '^bak_'
        ---- Other schemas to exclude
        --AND schema_name IN (  )
        AND EXISTS (
            SELECT 1
                FROM util_meta.objects o
                WHERE o.schema_oid = schemas.schema_oid
                    AND o.object_type IN ( 'function', 'procedure' )
                    -- Exclude private functions and procedures
                    AND o.object_name !~ '^_'
                    AND o.object_name !~ '^priv_'
                    -- Exclude trigger functions
                    AND ( o.result_data_type IS NULL
                        OR o.result_data_type <> 'trigger' )
        )
    ORDER BY schema_name ;
EOT

    psql -t -A -U $usr -h ${hostName} -f ${psqlFile} -d ${db} >>${outFile}

    while read schema; do

        echo " * [${schema}](${schema}.md)" >>${readmeFile}

        extract_schema_documentation ${tmpDir} ${schema}

    done <${outFile}
    wait

    [ -d ${targetDir} ] && rm -rf ${targetDir}

    mv ${tmpDir} ${targetDir}

    rm ${psqlFile}
    rm ${outFile}
}

extract_documentation
