#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

export_db_ddl.sh

SYNOPSIS

    export_db_ddl.sh [-H] [-d] [-p] [-u] [-t] [-h]

DESCRIPTION

    Export the DDL for the specified database using the ddlx extension

    -H host

        The host to connect to (defaults to localhost)

    -d database_name

        The name of the database to connect to (defaults to $USER)

    -p port

        The port to connect as (defaults to $PGPORT then 5432)

    -u user

        The name of the user to connect as (defaults to $USER)

    -t target_directory

        The directory to write exported DDL files to

    -h

        Displays this help

REFERENCES

    https://pgxn.org/dist/ddlx/
    https://github.com/lacanoid/pgddl

EOT

    exit 0
}

################################################################################
# Calling arguments and initialization
while getopts 'hH:d:p:t:u:' arg; do
    case ${arg} in
        d) db=${OPTARG} ;;
        H) hostName=${OPTARG} ;;
        h) usage=1 ;;
        p) port=${OPTARG} ;;
        t) targetDir=${OPTARG} ;;
        u) usr=${OPTARG} ;;
    esac
done

if [ ! -z "${usage}" ]; then
    usage
fi

if [ -z "${hostName}" ]; then
    hostName=localhost
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
if [ -z "${targetDir}" ]; then
    targetDir="${hostName}/${db}"
fi

######################################################
function ensure_ddlx() {

    local psqlFile=$(mktemp -p . XXXXXXXXXX.sql.1.tmp)
    local cmdFile=$(mktemp -p . XXXXXXXXXX.sql.2.tmp)

    cat <<EOT >${psqlFile}
SELECT 'CREATE SCHEMA IF NOT EXISTS ddlx ;
COMMENT ON SCHEMA ddlx IS ''Schema for ddlx objects'' ;'
    WHERE NOT EXISTS (
            SELECT 1
                FROM pg_catalog.pg_namespace
                WHERE nspname = 'ddlx'
        ) ;

SELECT 'CREATE EXTENSION IF NOT EXISTS ddlx SCHEMA ddlx ;'
    WHERE NOT EXISTS (
            SELECT 1
                FROM pg_catalog.pg_extension
                WHERE extname = 'ddlx'
        ) ;

SELECT 'CREATE SCHEMA IF NOT EXISTS util_meta ;
COMMENT ON SCHEMA util_meta IS ''Schema for metadata objects'' ;'
    WHERE NOT EXISTS (
            SELECT 1
                FROM pg_catalog.pg_namespace
                WHERE nspname = 'util_meta'
        ) ;
EOT

    if [ "${hostName}" == "localhost" ]; then
        psql -U ${usr} -d ${db} -p ${port} -t -A -f ${psqlFile} >${cmdFile}
        if [ -s ${cmdFile} ]; then
            psql -U ${usr} -d ${db} -p ${port} -t -A -f ${cmdFile}
        fi

    else
        psql -U ${usr} -d ${db} -h ${hostName} -p ${port} -t -A -f ${psqlFile} >${cmdFile}
        if [ -s ${cmdFile} ]; then
            psql -U ${usr} -d ${db} -h ${hostName} -p ${port} -t -A -f ${cmdFile}
        fi

    fi

    rm ${psqlFile}
    rm ${cmdFile}
}

function prep_directories() {

    if [ -d ${targetDir} ]; then
        rm -rf ${targetDir}
    fi

    local psqlFile=$(mktemp -p . XXXXXXXXXX.sql.3.tmp)
    local cmdFile=$(mktemp -p . XXXXXXXXXX.sh.4.tmp)

    cat <<EOT >${psqlFile}
SELECT DISTINCT 'mkdir -p ' || concat_ws ( '/', '${targetDir}', mdo.directory_name )
    FROM util_meta.objects mdo
    JOIN util_meta.schemas sdo
        ON ( sdo.schema_oid = mdo.schema_oid )
    WHERE mdo.directory_name IS NOT NULL
        AND sdo.schema_name NOT IN ( 'information_schema', 'public', 'ddlx' )
        AND sdo.schema_name !~ '^bak_'
    ORDER BY 1 ;
EOT

    if [ "${hostName}" == "localhost" ]; then
        psql -U ${usr} -d ${db} -p ${port} -t -A -f ${psqlFile} >${cmdFile}
    else
        psql -U ${usr} -d ${db} -h ${hostName} -p ${port} -t -A -f ${psqlFile} >${cmdFile}
    fi

    sh ${cmdFile}
    rm ${cmdFile}
    rm ${psqlFile}
}

function extract_ddl() {

    local psqlFile1=$(mktemp -p . XXXXXXXXXX.sql.5.tmp)
    local psqlFile2=$(mktemp -p . XXXXXXXXXX.sql.6.tmp)
    local psqlFile3=$(mktemp -p . XXXXXXXXXX.sql.7.tmp)
    local psqlFile4=$(mktemp -p . XXXXXXXXXX.sql.8.tmp)

    cat <<EOT >${psqlFile2}
CREATE TEMPORARY TABLE temp_object_ddl (
    obj_oid oid,
    file_name text,
    ddl_code text ) ;

WITH db AS (
    SELECT oid,
            concat_ws ( '/', '${targetDir}', 'database.sql' ) AS file_name
            FROM pg_catalog.pg_database
            WHERE datname = '${db}'
),
schemas AS (
    SELECT sdo.schema_oid,
            concat_ws ( '/', '${targetDir}', sdo.directory_name, 'schema.sql' ) AS file_name
        FROM util_meta.schemas sdo
        WHERE sdo.schema_name NOT IN ( 'information_schema', 'public', 'ddlx' )
            AND sdo.schema_name !~ '^bak_'
            AND EXISTS (
                -- not interested in exporting empty schemas
                SELECT 1
                    FROM util_meta.objects mdo
                    WHERE mdo.schema_oid = sdo.schema_oid )
),
objs AS (
    SELECT mdo.object_oid,
            concat_ws ( '/', '${targetDir}', mdo.directory_name, mdo.file_name ) AS file_name
    FROM util_meta.objects mdo
    JOIN schemas
        ON ( schemas.schema_oid = mdo.schema_oid )
    WHERE mdo.directory_name IS NOT NULL
        AND mdo.file_name IS NOT NULL
),
all_objs AS (
    SELECT oid,
            file_name
        FROM db
    UNION
    SELECT schema_oid,
            file_name
        FROM schemas
    UNION
    SELECT object_oid,
            file_name
        FROM objs
)
INSERT INTO temp_object_ddl (
        obj_oid,
        file_name )
    SELECT ao.oid,
            ao.file_name
        FROM all_objs ao ;

WITH n AS (
    SELECT o.obj_oid,
            o.file_name,
            ddlx_create ( o.obj_oid ) AS ddl_code
        FROM temp_object_ddl o
)
UPDATE temp_object_ddl o
    SET ddl_code = n.ddl_code
    FROM n
    WHERE n.obj_oid = o.obj_oid
        AND n.file_name = o.file_name ;

EOT

    cat <<EOT >${psqlFile3}
SELECT concat_ws ( E'\n\n',
            '\o ' || quote_literal ( file_name ),
            concat_ws ( E'\n    ',
                'SELECT ddl_code',
                'FROM temp_object_ddl',
                'WHERE file_name = ' || quote_literal ( file_name ),
                'ORDER BY ddl_code ;' ),
            '' )
    FROM temp_object_ddl
    GROUP BY file_name ;
EOT

    cat <<EOT >${psqlFile4}

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = on ;
SET client_min_messages = warning ;
SET search_path = ddlx, pg_catalog, public ;

\\i ${psqlFile2}

\\o ${psqlFile1}

\\i ${psqlFile3}

\\o

\\i ${psqlFile1}
EOT

    if [ "${hostName}" == "localhost" ]; then
        psql -U ${usr} -d ${db} -p ${port} -t -A -f ${psqlFile4} &>/dev/null
    else
        psql -U ${usr} -d ${db} -h ${hostName} -p ${port} -t -A -f ${psqlFile4} &>/dev/null
    fi

    rm ${psqlFile1}
    rm ${psqlFile2}
    rm ${psqlFile3}
    rm ${psqlFile4}
}

# echo "hostName: ${hostName}"
# echo "db: ${db}"
# echo "usr: ${usr}"
# echo "targetDir: ${targetDir}"

if [ ! -z "${hostName}" ] && [ ! -z "${db}" ] && [ ! -z "${usr}" ] && [ ! -z "${targetDir}" ]; then

    echo "Exporting ${db} from ${hostName} to ${targetDir}"

    ensure_ddlx
    prep_directories
    extract_ddl

fi
