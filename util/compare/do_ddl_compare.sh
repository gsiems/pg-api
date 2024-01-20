#!/usr/bin/env bash

function usage() {

    cat <<'EOT'
NAME

do_ddl_compare.sh

SYNOPSIS


DESCRIPTION

    Exports the DDL from 2 to 4 databases and compares the result using
    configuration information stored in do_ddl_compare.conf

EOT

    exit 0
}

################################################################################

function absolute_path() {
    case $(basename "$1") in
        ..) echo "$(dirname $(pwd))" ;;
        .) echo "$(pwd)" ;;
        *) echo "$(pwd)/$(basename "$1")" ;;
    esac
}

# Remove the path and extension from the specified pathname and return just the file name portion
function file_name() {
    echo "$(basename "$1" | sed 's/\(.*\)\.\(.*\)$/\1/')"
}

# Convert a (potentially fully-qualified) hostname to a directory name
function hn2dn() {
    local hostName="${1}"
    echo "./"$(echo ${hostName} | cut -d '.' -f 1)
}

function resolve_dir() {
    local dirName="${1}"
    local dbName="${2}"

    if [ ! -z "${dirName}" ] && [ ! -z "${dbName}" ]; then
        echo $(hn2dn ${dirName})/${dbName}
    fi
}

# Compare two db dumps and generate a report
function generate_report() {
    local dir1="${1}"
    local dir2="${2}"
    local diffTool="${3}"

    if [ ! -z "${dir1}" ] && [ ! -z "${dir2}" ] && [ -d ${dir1} ] && [ -d ${dir2} ]; then

        local label1=$(echo -n ${dir1} | sed 's/^\.\///' | tr '/', '-')
        local label2=$(echo -n ${dir2} | sed 's/^\.\///' | tr '/', '-')
        local file="${label1}_vs_${label2}.txt"

        diff -rq ${dir1} ${dir2} | sed -e 's/Files /${diffTool} /g' -e 's/ and / /g' -e 's/ differ//g' -e 's/Only in /# Only in /g' -e 's/:/\//g' | sort > ${file}

    fi
}

function export_db() {
    local hostName="${1}"
    local dbName="${2}"
    local usr="${3}"
    local baseDir="${4}"
    local isolateGrants="${5}"

    # Check the parameters before exporting the database DDL
    if [ ! -z "${hostName}" ] && [ ! -z "${dbName}" ] && [ ! -z "${usr}" ] && [ ! -z "${baseDir}" ]; then

        time ${scriptDir}/export_db_ddl.sh -H ${hostName} -d ${dbName} -u ${usr} -t ${baseDir} $@

        if [ "${isolateGrants}" == "1" ]; then

            # Extract the privilege commands (GRANT, REVOKE) to a separate file.
            # This is so that it is easier to compare privileges and also to
            # avoid privilege differences muddying the DDL comparison results.
            local grantsFile=$(mktemp -p . tmp.XXXXXXXXXX.grants.out)
            local filesList=$(mktemp -p . tmp.XXXXXXXXXX.list.out)
            local tempFile=$(mktemp -p . tmp.XXXXXXXXXX.temp.out)

            find ${baseDir} -type f -name "*.sql" | sort >${filesList}

            while read fileName; do

                grep -P "^(REVOKE .+ FROM|GRANT .+ TO) " "${fileName}" >>${grantsFile}
                grep -vP "^(REVOKE .+ FROM|GRANT .+ TO) " "${fileName}" >${tempFile}
                mv ${tempFile} "${fileName}"

            done <${filesList}

            [ -f ${tempFile} ] && rm ${tempFile}

            mv ${grantsFile} ${baseDir}/grants.sql

            rm ${filesList}

        fi
    fi
}

function resolve_diff_tool() {

    for dtool in meld diffuse tkdiff kompare diffuse kdiff3 diff; do

        for dfile in $(which ${dtool}); do

            if [ -x "$(dfile)" ]; then
                echo ${dfile}
            fi
        done
    done
}

function show_dir_diff() {
    d1="${1}"
    d2="${2}"
    d3="${3}"

    if [ -d ${d1} ] && [ -d ${d2} ] && [ -d ${d3} ]; then

        for dtool in meld dirdiff; do

            for dfile in $(which ${dtool}); do

                if [ -x "${dfile}" ]; then

                    local cmd="${dfile} ${1} ${2} ${3}"
                    echo ${cmd}
                    ${cmd} &
                    return
                fi
            done
        done
    fi
}

########################################################################

scriptPath="$(absolute_path "$0")"
scriptDir="$(dirname "$scriptPath")"
scriptName="$(file_name "$scriptPath")"

if [ -z ${scriptDir} ]; then
    scriptDir='.'
fi

cfgFile="$scriptDir/${scriptName}.conf"
if [ -f "${cfgFile}" ]; then
    . "${cfgFile}"
fi

########################################################################
# Export the DBs
loclDir=$(resolve_dir ${loclHost} ${loclDB})
devlDir=$(resolve_dir ${devlHost} ${devlDB})
testDir=$(resolve_dir ${testHost} ${testDB})
prodDir=$(resolve_dir ${prodHost} ${prodDB})

export_db ${loclHost} ${loclDB} ${loclUser} ${loclDir} ${isolateGrants}
export_db ${devlHost} ${devlDB} ${devlUser} ${devlDir} ${isolateGrants}
export_db ${testHost} ${testDB} ${testUser} ${testDir} ${isolateGrants}
export_db ${prodHost} ${prodDB} ${prodUser} ${prodDir} ${isolateGrants}

########################################################################
# Determine the diff tool to use

if [ -z "${diffTool}" ]; then
    diffTool=$(resolve_diff_tool)
fi

generate_report "${loclDir}" "${devlDir}" "${diffTool}"
generate_report "${devlDir}" "${testDir}" "${diffTool}"
generate_report "${testDir}" "${prodDir}" "${diffTool}"

show_dir_diff ${loclDir} ${devlDir} ${testDir}
