#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

02_run_tests.sh

SYNOPSIS

    02_run_tests.sh [-f] [-c] [-d] [-p] [-q] [-u] [-T] [-h]

DESCRIPTION

    Runs a set of one or more pgTap test files from the tests directory on the
    localhost pg instance

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
cd "$(dirname "$0")" || exit

source ./set_env.sh

if [[ -n ${usage} ]]; then
    usage
fi

exitCode=0
totalFailed=0
totalPassed=0
profileFile=test_profile.html
coveredFile=test_covered.html
profileName='pgTap tests'

################################################################################
function print_summary() {
    local label="${1}"
    local outFile="${2}"
    local logFile="${3}"
    local passed
    local failed
    local total

    passed=$(grep -c "^ok " "${outFile}")
    failed=$(grep -c "^not ok " "${outFile}")
    total=$((passed + failed))

    totalPassed=$((totalPassed + passed))
    totalFailed=$((totalFailed + failed))

    # quieter
    # 0 Print everything to standard out
    # 1 Only print the failing tests and summaries to standard out
    # 2 Only print summaries to standard out
    # 3 Only print the final summary to standard out

    case "${quieter}" in
        0)
            cat "${outFile}"
            ;;

        1)
            echo ""
            echo "${banner}"
            echo "# ${label}"
            if [[ ${failed} != "0" ]]; then
                grep "# Failed test " "${outFile}"
                echo ""
            fi
            echo "# Passed ${passed} of ${total}"
            if [[ ${failed} != "0" ]]; then
                echo "# Failed ${failed} of ${total}"
            fi
            ;;

        *)
            echo ""
            echo "${banner}"
            echo "# ${label}"
            echo "# Passed ${passed} of ${total}"
            if [[ ${failed} != "0" ]]; then
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

    local testFailed
    local testOut
    local testPassed
    local testPlanned
    local testTotal

    echo "" >>"${outFile}"
    echo "${banner}" >>"${outFile}"
    if [[ -f ${testFile} ]]; then

        testPlanned=$(grep -i "^select plan " "${testFile}" | awk '{ print $4 }')
        if [[ -z ${testPlanned} ]]; then
            testPlanned=0
        fi

        testOut=$(mktemp -p . XXXXXXXXXX.out.tmp)

        echo "# Running ${testFile}" >>"${outFile}"
        psql -U "${usr}" -d "${db}" -p "${port}" -f "${testFile}" >"${testOut}"

        testPassed=$(grep -c "^ok " "${testOut}")
        testFailed=$(grep -c "^not ok " "${testOut}")
        testTotal=$((testPassed + testFailed))

        if [[ ${testPlanned} -ne ${testTotal} ]]; then
            if [[ ${testPlanned} -eq 1 ]]; then
                echo "# Planned ${testPlanned} test but ran ${testTotal} in ${testFile}" >>"${logFile}"
            else
                echo "# Planned ${testPlanned} tests but ran ${testTotal} in ${testFile}" >>"${logFile}"
            fi
            exitCode=2
        fi

        cat "${testOut}" >>"${outFile}"

        rm "${testOut}"
    else
        echo "# No such file (${testFile})" >>"${logFile}"
        exitCode=2
    fi

}

################################################################################
function test_dir() {
    local source="${1}"
    local logFile="${2}"
    local dir
    local resultFile

    dir=$(echo "${source}" | sed -e 's/\/$//' -e 's/^\.\///')

    resultFile=$(mktemp -p . XXXXXXXXXX.out.tmp)

    cat <<EOT >>"${resultFile}"

"${banner}"
"${banner}"
"# Testing ${dir}"
EOT

    for testFile in "${dir}"/*.sql; do
        run_test_file "${testFile}" "${resultFile}" "${logFile}"
    done

    print_summary "${dir}" "${resultFile}" "${logFile}"
    rm "${resultFile}"

}

################################################################################
function run_tests() {

    logFile=$(mktemp -p . XXXXXXXXXX.log.tmp)

    if [[ -z ${file} ]]; then

        # Nothing specified, run everything
        for directory in $(find tests -mindepth 1 -maxdepth 1 -type d ! -name '\.*' | sort); do
            test_dir "${directory}" "${logFile}"
        done

    elif [[ -d ${file} ]]; then

        # A directory was specified, run everything in the directory
        test_dir "${file}" "${logFile}"

    else

        # A single file was specified, run it
        resultFile=$(mktemp -p . XXXXXXXXXX.out.tmp)
        run_test_file "${file}" "${resultFile}" "${logFile}"
        print_summary "${file}" "${resultFile}" "${logFile}"
        rm "${resultFile}"

    fi

    echo ""
    echo "${banner}"
    echo "### Totals"
    echo "Total Passed: ${totalPassed} of" $((totalPassed + totalFailed))
    echo ""

    if [[ ${totalFailed} != "0" ]]; then
        echo "Total Failed: ${totalFailed} of" $((totalPassed + totalFailed))
        exitCode=1
    fi

    if [[ -s ${logFile} ]]; then
        echo "${banner}"
        cat "${logFile}"
        echo ""
    fi

    rm "${logFile}"

}

################################################################################
################################################################################

function init_plprofiler() {

    cmd="select plprofiler_client.init_profile ( a_name => '${profileName}' ) ;"

    echo "${cmd}" | psql -U "${usr}" -d "${db}" -p "${port}" -f - >/dev/null

}

function plprofiler_report() {

    echo "## Creating ${profileFile}"

    cmd="select plprofiler_client.generate_profiler_report ( a_name => '${profileName}', a_max_rank => 5 ) ;"

    echo "${cmd}" | psql -X -U "${usr}" -d "${db}" -p "${port}" -q -t -A >"${profileFile}"

}

######################################################

function plprofiler_coverage_report() {

    echo "## Creating ${coveredFile}"

    cmd="select plprofiler_client.generate_coverage_report ( a_name => '${profileName}' ) ;"

    echo "${cmd}" | psql -X -U "${usr}" -d "${db}" -p "${port}" -q -t -A >"${coveredFile}"

}

function generate_plprofiler_reports() {

    echo ""
    echo "${banner}"
    echo "# Generating the plprofiler reports"
    cmd="
select plprofiler_client.save_dataset_from_shared ( a_opt_name => '${profileName}', a_overwrite => true ) ;

select plprofiler_client.disable_monitor () ;

select plprofiler_client.reset_shared () ;
"
    echo "${cmd}" | psql -U "${usr}" -d "${db}" -p "${port}" -f - >/dev/null

    plprofiler_report

    plprofiler_coverage_report

    echo ""

    # delete the profileName profile?
    # Use the same profileName for each run or dynamically generate a profileName
    # for each run (implies deleting profile when done)

}

################################################################################

if [[ ${truncateLogs} == "1" ]]; then
    psql -U "${usr}" -d "${db}" -p "${port}" -c 'truncate table util_log.dt_proc_log ;'
fi

psql -U "${usr}" -d "${db}" -p "${port}" -f 10_init_testrun.sql >/dev/null 2>&1

if [[ ${coverage} == "1" ]]; then
    init_plprofiler
    run_tests
    generate_plprofiler_reports
else
    run_tests
fi

psql -U "${usr}" -d "${db}" -p "${port}" -f 40_finalize_testrun.sql >/dev/null 2>&1

exit "${exitCode}"
