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

cd "$(dirname "$0")"

source ./set_env.sh

if [ ! -z "${usage}" ]; then
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

cat <<EOT >${psqlFile}

\x on
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
        SELECT plpgsql_check_function_tb ( pg_proc.oid, coalesce ( trig.tgrelid, 0 ) ) AS pcf
            FROM pg_catalog.pg_proc
            JOIN pg_catalog.pg_namespace nsp
                ON ( nsp.oid = pg_proc.pronamespace )
            JOIN pg_catalog.pg_type typ
                ON ( typ.oid = pg_proc.prorettype )
            JOIN pg_catalog.pg_language lang
                ON ( lang.oid = pg_proc.prolang )
            LEFT JOIN pg_catalog.pg_trigger trig
                ON ( trig.tgfoid = pg_proc.oid )
            WHERE lang.lanname = 'plpgsql'
                AND nsp.nspname NOT IN ( 'pg_catalog', 'public',
                    'tap', 'ddlx', 'plprofiler', 'plprofiler_client' )
                -- ignore unused triggers
                AND ( typ.typname <> 'trigger'
                    OR trig.tgfoid IS NOT NULL )
            --OFFSET 0
        ) ss
    ORDER BY (pcf).functionid::regprocedure::text,
        (pcf).lineno ;
EOT

psql -U ${usr} -d ${db} -p ${port} -f >${psqlFile} | sed 's/\+[[:blank:]]*$//;s/[[:blank:]]*$//'

rm >${psqlFile}
