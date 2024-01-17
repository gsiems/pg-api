#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

02_run_tests.sh

SYNOPSIS

    02_run_tests.sh [-f] [-c] [-d] [-p] [-q] [-u] [-T] [-h]

DESCRIPTION

    Runs a set of one or more pgTap test files on the localhost pg instance

OPTIONS

    -f [filename|directory]

        The file name or directory to test.

            - If a directory is specified then all pgTap sql files in that
            directory are run.

            - If a file is specified then just that file is run.

            - If not specified then tests are run for all directories
            (in alpha-numeric order)

    -c

        Run plprofiler to obtain performance and coverage data

    -d database_name

        The name of the database to connect to (defaults to $PGDATABASE then $USER)

    -p port

        The port to connect as (defaults to $PGPORT then 5432)

    -u user

        The name of the user to connect as (defaults to $PGUSER then $USER)

    -q

        Quieter. Requce the amount printed to stdout. Can be repeated
        to increase the quietness.

            - 0 Print everything to standard out
            - 1 Only print the failing tests and summaries to standard out
            - 2 Only print summaries to standard out
            - 3 Only print the final summary to standard out

    -T

        Truncate logs. Truncate the util_log.dt_proc_log table before
        running the tests

    -h

        Displays this help

EOT
    exit 0
}

################################################################################
# Calling arguments and initialization
cd "$(dirname "$0")"

source ./set_env.sh

if [ ! -z "${usage}" ]; then
    usage
fi

exitCode=0
totalFailed=0
totalPassed=0
profileFile=test_profile.html
coveredFile=test_covered.html
profileName=test_profile

tmsp=$(date +'%F %T')

################################################################################
function print_summary() {
    local label="${1}"
    local outFile="${2}"
    local logFile="${3}"

    local passed=$(grep -c "^ok " ${outFile})
    local failed=$(grep -c "^not ok " ${outFile})
    local total=$((passed + failed))

    totalPassed=$((totalPassed + passed))
    totalFailed=$((totalFailed + failed))

    # quieter
    # 0 Print everything to standard out
    # 1 Only print the failing tests and summaries to standard out
    # 2 Only print summaries to standard out
    # 3 Only print the final summary to standard out

    case "${quieter}" in
        0)
            cat ${outFile}
            ;;

        1)
            echo ""
            echo ${banner}
            echo "# ${label}"
            if [ "${failed}" != "0" ]; then
                grep "# Failed test " ${outFile}
                echo ""
            fi
            echo "# Passed ${passed} of ${total}"
            if [ "${failed}" != "0" ]; then
                echo "# Failed ${failed} of ${total}"
            fi
            ;;

        *)
            echo ""
            echo ${banner}
            echo "# ${label}"
            echo "# Passed ${passed} of ${total}"
            if [ "${failed}" != "0" ]; then
                echo "# Failed ${failed} of ${total}"
            fi
            ;;

    esac

}

################################################################################
function run_test_file() {
    local testFile="${1}"
    local outFile="${2}"
    local logFile="${3}"

    echo "" >>${outFile}
    echo ${banner} >>${outFile}
    if [ -f ${testFile} ]; then

        local testPlanned=$(grep -i "^select plan " ${testFile} | awk '{ print $4 }')
        if [ -z "${testPlanned}" ]; then
            testPlanned=0
        fi

        local testOut=$(mktemp -p . XXXXXXXXXX.out.tmp)

        echo "# Running $testFile" >>${outFile}
        psql -U ${usr} -d ${db} -p ${port} -f ${testFile} >${testOut}

        local testPassed=$(grep -c "^ok " ${testOut})
        local testFailed=$(grep -c "^not ok " ${testOut})
        local testTotal=$((testPassed + testFailed))

        if [ $testPlanned -ne $testTotal ]; then
            if [ $testPlanned -eq 1 ]; then
                echo "# Planned ${testPlanned} test but ran ${testTotal} in ${testFile}" >>${logFile}
            else
                echo "# Planned ${testPlanned} tests but ran ${testTotal} in ${testFile}" >>${logFile}
            fi
            exitCode=2
        fi

        cat ${testOut} >>${outFile}

        rm ${testOut}
    else
        echo "# No such file ($testFile)" >>${logFile}
        exitCode=2
    fi

}

################################################################################
function test_dir() {
    local source="${1}"
    local logFile="${2}"

    local dir=$(echo "${source}" | sed -e 's/\/$//' -e 's/^\.\///')

    local resultFile=$(mktemp -p . XXXXXXXXXX.out.tmp)

    echo "" >>${resultFile}
    echo ${banner} >>${resultFile}
    echo ${banner} >>${resultFile}
    echo "# Testing ${dir}" >>${resultFile}

    for testFile in $(ls ${dir}/*.sql); do
        run_test_file ${testFile} ${resultFile} ${logFile}
    done

    print_summary ${dir} ${resultFile} ${logFile}
    rm ${resultFile}

}

################################################################################
function run_tests() {

    local logFile=$(mktemp -p . XXXXXXXXXX.log.tmp)

    if [ -z "${file}" ]; then

        # Nothing specified, run everything
        for directory in $(find . -maxdepth 1 -type d ! -name test_data ! -name plprofiler_client ! -name '\.*' | sort); do
            test_dir ${directory} ${logFile}
        done

    elif [ -d "${file}" ]; then

        # A directory was specified, run everything in the directory
        test_dir ${file} ${logFile}

    else

        # A single file was specified, run it
        local resultFile=$(mktemp -p . XXXXXXXXXX.out.tmp)
        run_test_file ${file} ${resultFile} ${logFile}
        print_summary ${file} ${resultFile} ${logFile}
        rm ${resultFile}

    fi

    echo ""
    echo ${banner}
    echo "### Totals"
    echo "Total Passed: ${totalPassed} of" $((totalPassed + totalFailed))
    echo ""

    if [ "${totalFailed}" != "0" ]; then
        echo "Total Failed: ${totalFailed} of" $((totalPassed + totalFailed))
        exitCode=1
    fi

    if [ -s "${logFile}" ]; then
        echo ${banner}
        cat ${logFile}
        echo ""
    fi

    rm ${logFile}

}

################################################################################
################################################################################

function init_plprofiler() {

    cmd="
select plprofiler_client.disable_monitor () ;

select plprofiler_client.reset_shared () ;

delete from plprofiler.pl_profiler_saved
    where s_name = '${profileName}' ;

select plprofiler_client.enable_monitor () ;
"
    echo ${cmd} | psql -U ${usr} -d ${db} -p ${port} -f - >/dev/null

}

function plprofiler_report() {

    local psqlFile=$(mktemp -p . XXXXXXXXXX.sql.tmp)

    cat <<EOT >${psqlFile}

\pset pager off

WITH ps AS (
    SELECT s_id,
            s_name,
            s_options,
            s_callgraph_overflow,
            s_functions_overflow,
            s_lines_overflow
        FROM plprofiler.pl_profiler_saved
        WHERE s_name = '${profileName}'
),
cg AS (
    SELECT c.c_s_id,
            ( split_part ( c.c_stack [ array_upper ( c.c_stack, 1 ) ], '=', 2 ) )::bigint AS func_oid,
            sum ( c.c_us_self ) AS self_time,
            row_number () over () AS rn
        FROM ps
        JOIN plprofiler.pl_profiler_saved_callgraph c
            ON ( c.c_s_id = ps.s_id )
        GROUP BY c.c_s_id,
                func_oid
),
src AS (
    SELECT psl.l_s_id,
            psl.l_funcoid,
            min ( CASE WHEN psl.l_line_number = 0 THEN psl.l_total_time END ) AS total_time,
            min ( CASE WHEN psl.l_line_number = 0 THEN psl.l_exec_count END ) AS exec_count,
            min ( CASE WHEN psl.l_line_number = 0 THEN psl.l_longest_time END ) AS longest_time,
            max ( psl.l_line_number ) AS line_count,
            string_agg ( concat (
                '<tr>',
                '<td align="right">', psl.l_line_number::text, '</td>',
                '<td align="right">', psl.l_exec_count::text, '</td>',
                '<td align="right">', psl.l_total_time::text, '</td>',
                '<td align="right">', psl.l_longest_time::text, '</td>',
                '<td align="left"><code>',
                    replace (
                        replace (
                            replace (
                                replace (
                                    replace (
                                        replace (
                                            replace ( psl.l_source, '&', '&amp;' ),
                                            '>', '&gt;' ),
                                        '<', '&lt;' ),
                                    '"', '&quot;' ),
                                '''', '&apos;' ),
                            ' ', '&nbsp;' ),
                        E'\t', repeat ( '&nbsp;', 4 ) ),
                '</code></td>',
                '</tr>'
                ), E'\n' ORDER BY psl.l_line_number ) AS src
        FROM plprofiler.pl_profiler_saved_linestats psl
        JOIN ps
            ON ( ps.s_id = psl.l_s_id )
        GROUP BY psl.l_s_id,
            psl.l_funcoid
)
SELECT concat_ws ( E'\n',
            concat (
                '<tr id="g', cg.rn::text, '">',
                '<td>',
                CASE
                    WHEN proc.prokind = 'f' THEN 'Function'
                    WHEN proc.prokind = 'p' THEN 'Procedure'
                    END,
                '</td>',
                '<td>', psf.f_schema, '</td>',
                '<td>', psf.f_funcname, '</td>',
                '<td align="right">', psf.f_funcoid::text, '</td>',
                '<td align="right">', src.line_count::text, '</td>',
                '<td align="right">', cg.self_time::text, '</td>',
                '<td align="right">', src.total_time::text, '</td>',
                '<td align="right">', src.exec_count::text, '</td>',
                '<td align="right">',
                    CASE
                        WHEN coalesce ( src.exec_count, 0 ) = 0 OR coalesce ( cg.self_time, 0 ) = 0 THEN '0'
                        ELSE ( round ( cg.self_time::numeric / src.exec_count::numeric, 0 ) )::text
                        END,
                    '</td>',
                '<td align="right">',
                    CASE
                        WHEN coalesce ( src.exec_count, 0 ) = 0 OR coalesce ( src.total_time, 0 ) = 0 THEN '0'
                        ELSE ( round ( src.total_time::numeric / src.exec_count::numeric, 0 ) )::text
                        END,
                    '</td>',
                '<td>',
                '(<a id="toggle_', cg.rn::text, '" href="javascript:toggle_div(''toggle_', cg.rn::text, ''', ''dtl_', cg.rn::text, ''')">show</a>)',
                '</tr>' ),
            --------------------------------------------------------------------------------
            -- Function details
            concat (
                '<tr>',
                '<td colspan="11">',
                '<table class="linestats" id="dtl_', cg.rn::text, '" align="right" style="display: none">' ),
            --------------------------------------------------------------------------------
            -- Function signature
            concat (
                '<tr>',
                '<td colspan="5"><b><code>',
                psf.f_schema,
                '.',
                psf.f_funcname,
                CASE
                    WHEN coalesce ( psf.f_funcargs, '' ) = '' THEN ' ()'
                    ELSE concat (
                        E' (<br/>&nbsp;&nbsp;&nbsp;&nbsp;',
                        replace ( psf.f_funcargs, ', ', ',<br/>&nbsp;&nbsp;&nbsp;&nbsp;'),
                        ' )' )
                    END,
                CASE
                    WHEN proc.prokind = 'f' THEN ' returns ' || psf.f_funcresult
                    ELSE ''
                    END,
                '</code></b></td>',
                '</tr>' ),
            -- /Function signature
            --------------------------------------------------------------------------------
            -- Source code data
            concat (
                '<tr>',
                '<th>Line</th>',
                '<th>Exec<br>count</th>',
                '<th>Total<br>time (µs)</th>',
                '<th>Longest<br>time (µs)</th>',
                '<th>Source code</th>',
                '</tr>' ),
            src.src,
            '</table>',
            '</td>',
            '</tr>'
            -- /Source code data
            --------------------------------------------------------------------------------
            -- /Function details
            --------------------------------------------------------------------------------
            ) AS tbl
    FROM ps
    JOIN cg
        ON ( cg.c_s_id = ps.s_id )
    JOIN plprofiler.pl_profiler_saved_functions psf
        ON ( psf.f_s_id = cg.c_s_id
            AND psf.f_funcoid = cg.func_oid )
    JOIN src
        ON ( psf.f_funcoid = src.l_funcoid
            AND psf.f_s_id = src.l_s_id )
    LEFT JOIN pg_catalog.pg_proc proc
        ON ( proc.oid = psf.f_funcoid )
    ORDER BY psf.f_schema,
        proc.prokind,
        psf.f_funcname,
        psf.f_funcoid ;
EOT

    cat <<EOT >${profileFile}
<html>
<head>
  <title>PL Profiler Report for pgTap test</title>
  <script language="javascript">
    // ----
    // toggle_div()
    //
    //  JS function to toggle one of the functions to show/block.
    // ----
    function toggle_div(tog_id, dtl_id) {
        var tog_elem = document.getElementById(tog_id);
        var dtl_elem = document.getElementById(dtl_id);
        if (dtl_elem.style.display == "block") {
            dtl_elem.style.display = "none";
            tog_elem.innerHTML = "show";
        } else {
            dtl_elem.style.display = "block";
            tog_elem.innerHTML = "hide";
        }
    }
    </script>

    <style>
    body {
        background-color: hsl(0, 0%, 97%);;
        font-family: verdana,helvetica,sans-serif;
        margin: 0;
        padding: 0;
    }

    table.funclist thead tr th {
        background-color: hsl(0, 0%, 85%);
        border-bottom: 2px solid hsl(0, 0%, 50%);
        border-right: 2px solid hsl(0, 0%, 50%);
        color: hsl(213, 48%, 38%);
        padding-left: 4px;
        padding-right: 4px;
    }

    code {
        padding-left: 10px;
        padding-right: 10px;
    }
    table.linestats td {
        padding-left: 10px;
        padding-right: 10px;
    }
    table.linestats tr:nth-child(odd) {
        background-color: hsl(240, 67%, 94%);
    }
    table.linestats tr:nth-child(even) {
        background-color: hsl(0, 0%, 85%);
    }
    </style>

</head>
<body>

<h1>PL Profiler Report for pgTap tests - ${tmsp}</h1>


<table class="funclist" id="funcList" width="100%">
<thead>
<tr>
    <th align="left">Type</th>
    <th align="left">Schema</th>
    <th align="left">Name</th>
    <th align="right">OID</th>
    <th align="right">Line count</th>
    <th align="right">Self time (µs)</th>
    <th align="right">Total time (µs)</th>
    <th align="right">Exec count</th>
    <th align="right">Self time/exec (µs)</th>
    <th align="right">Total time/exec (µs)</th>
    <th></th>
</tr>
</thead>
<tbody>
EOT

    psql -X -U ${usr} -d ${db} -p ${port} -q -t -A -f ${psqlFile} >>${profileFile}

    cat <<'EOT' >>${profileFile}

</tbody>
</table>
</body>
</html>

EOT

    rm ${psqlFile}

}

######################################################

function plprofiler_coverage_report() {

    local psqlFile=$(mktemp -p . XXXXXXXXXX.sql.tmp)

    cat <<EOT >${psqlFile}
\pset pager off

WITH ps AS (
    SELECT s_id,
            s_name,
            s_options,
            s_callgraph_overflow,
            s_functions_overflow,
            s_lines_overflow
        FROM plprofiler.pl_profiler_saved
        WHERE s_name = '${profileName}'
),
sf AS (
    SELECT f.f_s_id,
            f.f_funcoid
        FROM ps
        JOIN plprofiler.pl_profiler_saved_functions f
            ON ( f.f_s_id = ps.s_id )
        GROUP BY f.f_s_id,
            f.f_funcoid
),
x AS (
    SELECT DISTINCT initcap ( obj.object_type ) AS object_type,
            obj.schema_name,
            obj.object_name,
            obj.object_oid,
            CASE
                WHEN obj.object_type = 'function' THEN obj.result_data_type
                ELSE ''
                END AS return_type,
            obj.procedure_language,
            CASE
                WHEN sf.f_s_id IS NOT NULL THEN 'Y'
                ELSE 'N'
                END AS was_tested,
            CASE
                WHEN obj.result_data_type = 'trigger' AND pg_trigger.tgfoid IS NULL THEN 'Y'
                WHEN obj.result_data_type = 'trigger' THEN 'N'
                ELSE '-'
                END AS is_unused_trigger
        FROM util_meta.objects obj
        LEFT JOIN pg_catalog.pg_trigger
            ON ( pg_trigger.tgfoid = obj.object_oid )
        LEFT JOIN sf
            ON ( sf.f_funcoid = obj.object_oid )
        WHERE obj.object_type IN ( 'function', 'procedure' )
            AND obj.schema_name NOT IN (
                    'pg_catalog', 'public', 'tap', 'ddlx', 'plprofiler', 'plprofiler_client',
                    'sde', 'util_meta_data', 'util_meta' )
)
SELECT concat (
        '<tr valign="top">',
        '<td>', x.object_type, '</td>',
        '<td>', x.schema_name, '</td>',
        '<td>', x.object_name, '</td>',
        '<td>', x.object_oid, '</td>',
        '<td>', x.return_type, '</td>',
        '<td>', x.procedure_language, '</td>',
        '<td>', x.was_tested, '</td>',
        '<td>', x.is_unused_trigger, '</td>',
        '</tr>' ) AS tbl
    FROM x
    ORDER BY x.schema_name,
        x.object_name,
        x.object_oid ;
EOT

    cat <<EOT >${coveredFile}
<html>
<head>
  <title>PL Covered Report for pgTap test</title>
    <style>
    body {
        background-color: hsl(0, 0%, 97%);;
        font-family: verdana,helvetica,sans-serif;
        margin: 0;
        padding: 0;
    }
    table.funclist thead tr th {
        background-color: hsl(0, 0%, 85%);
        border-bottom: 2px solid hsl(0, 0%, 50%);
        border-right: 2px solid hsl(0, 0%, 50%);
        color: hsl(213, 48%, 38%);
        padding-left: 4px;
        padding-right: 4px;
    }
    table.funclist td {
        padding-left: 10px;
        padding-right: 10px;
    }
    table.funclist tr:nth-child(odd) {
        background-color: hsl(240, 67%, 94%);
    }
    table.funclist tr:nth-child(even) {
        background-color: hsl(0, 0%, 85%);
    }
    </style>

</head>
<body>

<h1>PL Covered Report for pgTap tests - ${tmsp}</h1>


<table class="funclist" id="funcList" width="100%">
<thead>
<tr>
    <th>Type</th>
    <th>Schema</th>
    <th>Name</th>
    <th>OID</th>
    <th>Return Type</th>
    <th>Language</th>
    <th>Was tested</th>
    <th>Is unused trigger</th>
</tr>
</thead>
<tbody>

EOT

    psql -X -U ${usr} -d ${db} -p ${port} -q -t -A -f ${psqlFile} >>${coveredFile}

    cat <<'EOT' >>${coveredFile}

</tbody>
</table>
</body>
</html>

EOT

    rm ${psqlFile}

}

function generate_plprofiler_reports() {

    echo ""
    echo ${banner}
    echo "Generating the plprofiler reports"
    echo ""
    cmd="
select plprofiler_client.save_dataset_from_shared ( a_opt_name => '${profileName}', a_overwrite => true ) ;

select plprofiler_client.disable_monitor () ;

select plprofiler_client.reset_shared () ;
"
    echo ${cmd} | psql -U ${usr} -d ${db} -p ${port} -f - >/dev/null

    plprofiler_report

    plprofiler_coverage_report

    # delete the profileName profile?
    # Use the same profileName for each run or dynamically generate a profileName
    # for each run (implies deleting profile when done)

}

################################################################################

if [ "${truncateLogs}" == "1" ]; then
    psql -U ${usr} -d ${db} -p ${port} -c 'truncate table util_log.dt_proc_log ;'
fi

psql -U ${usr} -d ${db} -p ${port} -f 10_init_testrun.sql 2>&1 >/dev/null

if [ "${coverage}" == "1" ]; then
    init_plprofiler
    run_tests
    generate_plprofiler_reports
else
    run_tests
fi

psql -U ${usr} -d ${db} -p ${port} -f 40_finalize_testrun.sql 2>&1 >/dev/null

exit ${exitCode}
