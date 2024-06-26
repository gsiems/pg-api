#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

03_run_plpgsql_check.sh

SYNOPSIS

    03_run_plpgsql_check.sh [-d] [-p] [-u] [-h]

DESCRIPTION

    Run plpgsql_check on the specified database

OPTIONS

    -d database_name

        The name of the database to connect to (defaults to $PGDATABASE then $USER)

    -p port

        The port to connect as (defaults to $PGPORT then 5432)

    -u user

        The name of the user to connect as (defaults to $PGUSER then $USER)

    -h

        Displays this help

EOT
    exit 0
}

cd "$(dirname "$0")" || exit

source ./set_env.sh

if [[ -n "${usage}" ]]; then
    usage
fi

psqlFile=$(mktemp -p . XXXXXXXXXX.sql.tmp)

# Ref: https://github.com/okbob/plpgsql_check#checking-all-of-your-code
#
# plpgsql_check_function_tb returns
#     TABLE (
#         functionid regproc,
#         lineno integer,
#         statement text,
#         sqlstate text,
#         message text,
#         detail text,
#         hint text,
#         level text,
#         "position" integer,
#         query text,
#         context text )

# TODO: Determine schema for plpgsql_check extension and dynamically set that



extCmd="SELECT n.nspname::text AS schema_name
    FROM pg_catalog.pg_extension px
    JOIN pg_catalog.pg_namespace n
        ON ( px.extnamespace = n.oid )
    WHERE px.extname = 'plpgsql_check'"

plChkSchema=$(psql -t -U "${usr}" -d "${db}" -p "${port}" -c "${extCmd}" )

if [[ -n "${plChkSchema}" ]]; then

    cat <<EOT >"${psqlFile}"

CREATE TEMPORARY TABLE temp_obj_deps AS
SELECT 0::int AS tree_depth,
        object_oid,
        schema_name,
        object_name,
        full_object_name,
        object_type,
        directory_name,
        file_name,
        calling_signature
    FROM util_meta.objects
    WHERE false ;

CREATE TEMPORARY TABLE temp_all_deps AS
SELECT object_oid,
        dep_object_oid
    FROM util_meta.dependencies
    WHERE false ;

\x

\pset pager off

SELECT  (pcf).functionid::regprocedure::text AS "procedure",
        concat_ws ( ': ',
            (pcf).level,
            (pcf).sqlstate,
            concat_ws ( '/',
                (pcf).lineno::text,
                (pcf)."position"::text ),
            (pcf).message,
            (pcf).detail ) AS message,
        concat_ws ( E'\n',
            (pcf).hint,
            (pcf).query,
            (pcf).context ) AS details
    FROM (
        SELECT ${plChkSchema}.plpgsql_check_function_tb ( pg_proc.oid, coalesce ( trig.tgrelid, 0 ), all_warnings => true ) AS pcf
            FROM pg_catalog.pg_proc
            JOIN util_meta.schemas
                ON ( schemas.schema_oid = pg_proc.pronamespace )
            JOIN pg_catalog.pg_type typ
                ON ( typ.oid = pg_proc.prorettype )
            JOIN pg_catalog.pg_language lang
                ON ( lang.oid = pg_proc.prolang )
            LEFT JOIN pg_catalog.pg_trigger trig
                ON ( trig.tgfoid = pg_proc.oid )
            WHERE lang.lanname = 'plpgsql'
                -- ignore unused triggers
                AND ( typ.typname <> 'trigger'
                    OR trig.tgfoid IS NOT NULL )
            --OFFSET 0
        ) ss
    ORDER BY (pcf).functionid::regprocedure::text,
        (pcf).lineno ;
EOT

    psql -X -U "${usr}" -d "${db}" -p "${port}" -f "${psqlFile}" | sed 's/\+[[:blank:]]*$//;s/[[:blank:]]*$//'

    rm "${psqlFile}"

else

    echo "Could not run plpgsql_check. Extension not found."

fi

