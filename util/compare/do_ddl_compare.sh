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

function change_log() {
    cat <<'EOT'

2023-07-13 - refactor to accommodate comparing up to four DBs
            (local, development, test, and production).

2023-10-04 - Update variable names.
            Dynamically generate query for setting up the ddlx extension as needed.
            Fix database name in export_db_def function.
            Move database parameters to separate config file.
            Remove hard-coding of diff tool.

2023-12-06 - Rewrite to:
            1 - minimize the number of database connections used
                (from exported_object_count + 4 to a max of 4)
            2 - reduce the runtime (from ~25 minutes to ~8 minutes
                (at time of testing))
            3 - separate the DDL extraction functionality into a separate script
                that can be used independently of the DDL compare
            4 - properly deal with object names that contain spaces
            5 - extract the privilege commands (GRANT, REVOKE) from the DDL files
                to a separate file

2024-01-11 - Make the grants extraction optional

2024-01-16 - Remove usage of perl one-liners (use sed instead).
            Make the diffing portion smarter (query system for common diff tools
            to determine which one to use)

2024-06-06 - Add sorting or grants/revokes.

2024-06-21 - Add call to grep_needed_grants script

2025-11-22 - Cleanup using
            `shfmt -i 4 -s -ci -w %f` and
            `shellcheck -x --format=gcc "%f"`

EOT

}

################################################################################

function absolute_path() {
    case $(basename "$1") in
        ..) "$(dirname "$(pwd)")" ;;
        .) "$(pwd)" ;;
        *) "$(pwd)/$(basename "$1")" ;;
    esac
}

# Remove the path and extension from the specified pathname and return just the file name portion
function file_name() {
    local fn
    fn="$(basename "$1" | sed 's/\(.*\)\.\(.*\)$/\1/')"
    echo "${fn}"
}

# Convert a (potentially fully-qualified) hostname to a directory name
function hn2dn() {
    local hostName="${1}"
    local dn
    dn="$(echo "${hostName}" | cut -d '.' -f 1)"
    echo "./${dn}"
}

function resolve_dir() {
    local dirName="${1}"
    local dbName="${2}"

    if [ -n "${dirName}" ] && [ -n "${dbName}" ]; then
        local dn
        dn="$(hn2dn "${dirName}")/"
        echo "${dn}${dbName}"
    fi
}

# Compare two db dumps and generate a report
function generate_report() {
    local dir1="${1}"
    local dir2="${2}"
    local diffTool="${3}"

    if [ -n "${dir1}" ] && [ -n "${dir2}" ] && [ -d "${dir1}" ] && [ -d "${dir2}" ]; then

        local label1
        local label2
        local file

        label1=$(echo -n "${dir1}" | sed 's/^\.\///' | tr '/', '-')
        label2=$(echo -n "${dir2}" | sed 's/^\.\///' | tr '/', '-')
        file="${label1}_vs_${label2}.txt"

        #diff -rq "${dir1}" "${dir2}" | sed -e 's/Files /${diffTool} /g' -e 's/ and / /g' -e 's/ differ//g' -e 's/Only in /# Only in /g' -e 's/:/\//g' | sort > ${file}
        diff -rq "${dir1}" "${dir2}" | sed -e "s/Files /${diffTool} /g" -e 's/ and / /g' -e 's/ differ//g' -e 's/Only in /# Only in /g' -e 's/:/\//g' | sort >"${file}"

    fi
}

function export_db() {
    local hostName="${1}"
    local dbName="${2}"
    local usr="${3}"
    local baseDir="${4}"
    local isolateGrants="${5}"

    # Check the parameters before exporting the database DDL
    if [ -n "${hostName}" ] && [ -n "${dbName}" ] && [ -n "${usr}" ] && [ -n "${baseDir}" ]; then

        time "${scriptDir}"/export_db_ddl.sh -H "${hostName}" -d "${dbName}" -u "${usr}" -t "${baseDir}" "$@"

        # Extract the privilege commands (GRANT, REVOKE) to a separate file.
        # This is so that it is easier to compare privileges and also to
        # avoid privilege differences muddying the DDL comparison results.
        local grantsFile
        local filesList
        local tempGrantsFile
        local tempFile

        grantsFile=$(mktemp -p . tmp.XXXXXXXXXX.grants.tmp)
        filesList=$(mktemp -p . tmp.XXXXXXXXXX.list.tmp)
        tempGrantsFile=$(mktemp -p . tmp.XXXXXXXXXX.temp.tmp)
        tempFile=$(mktemp -p . tmp.XXXXXXXXXX.temp.tmp)

        find "${baseDir}" -type f -name "*.sql" | sort >"${filesList}"

        while read -r fileName; do

            grep -P "^(REVOKE .+ FROM|GRANT .+ TO) " "${fileName}" >"${tempGrantsFile}"
            grep -vP "^(REVOKE .+ FROM|GRANT .+ TO) " "${fileName}" >"${tempFile}"

            if [[ ${isolateGrants} == "1" ]]; then
                # move the grants to the global file
                grep -P "^REVOKE " "${tempGrantsFile}" | sort >>"${grantsFile}"
                grep -P "^GRANT " "${tempGrantsFile}" | sort >>"${grantsFile}"
            else
                # sort the grants and return them to the original file
                grep -P "^REVOKE " "${tempGrantsFile}" | sort >>"${tempFile}"
                grep -P "^GRANT " "${tempGrantsFile}" | sort >>"${tempFile}"
            fi

            mv "${tempFile}" "${fileName}"

        done <"${filesList}"

        if [[ ${isolateGrants} == "1" ]]; then
            if [[ -f ${grantsFile} ]]; then
                sort "${grantsFile}" >"${baseDir}/grants.sql"
            fi
        fi

        [[ -f ${grantsFile} ]] && rm "${grantsFile}"
        [[ -f ${tempGrantsFile} ]] && rm "${tempGrantsFile}"
        [[ -f ${tempFile} ]] && rm "${tempFile}"

        rm "${filesList}"

        ################################################################
        # Guess at the needed grants for the database objects

        gngFile="$scriptDir/grep_needed_grants.sh"
        if [ -x "${gngFile}" ]; then
            "${scriptDir}"/grep_needed_grants.sh "${baseDir}" >"${baseDir}/needed_grants.txt"
        fi

    fi
}

function resolve_diff_tool() {

    for dtool in meld diffuse tkdiff kompare diffuse kdiff3 diff; do

        for dfile in $(which "${dtool}"); do

            if [ -x "$(dfile)" ]; then
                echo "${dfile}"
            fi
        done
    done
}

function show_dir_diff() {
    d1="${1}"
    d2="${2}"
    d3="${3}"

    if [ -d "${d1}" ] && [ -d "${d2}" ] && [ -d "${d3}" ]; then

        for dtool in meld dirdiff; do

            for dfile in $(which ${dtool}); do

                if [ -x "${dfile}" ]; then

                    local cmd="${dfile} ${1} ${2} ${3}"
                    echo "${cmd}"
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

devlDB=''
devlHost=''
devlUser=''
loclUser=''
loclDB=''
loclHost=''
prodDB=''
prodHost=''
prodUser=''
testDB=''
testHost=''
testUser=''

if [ -z "${scriptDir}" ]; then
    scriptDir='.'
fi

cfgFile="$scriptDir/${scriptName}.conf"
if [ -f "${cfgFile}" ]; then
    . "${cfgFile}"
fi

########################################################################
# Export the DBs
loclDir=$(resolve_dir "${loclHost}" "${loclDB}")
devlDir=$(resolve_dir "${devlHost}" "${devlDB}")
testDir=$(resolve_dir "${testHost}" "${testDB}")
prodDir=$(resolve_dir "${prodHost}" "${prodDB}")

export_db "${loclHost}" "${loclDB}" "${loclUser}" "${loclDir}" "${isolateGrants}"
export_db "${devlHost}" "${devlDB}" "${devlUser}" "${devlDir}" "${isolateGrants}"
export_db "${testHost}" "${testDB}" "${testUser}" "${testDir}" "${isolateGrants}"
export_db "${prodHost}" "${prodDB}" "${prodUser}" "${prodDir}" "${isolateGrants}"

########################################################################
# Determine the diff tool to use

if [ -z "${diffTool}" ]; then
    diffTool=$(resolve_diff_tool)
fi

generate_report "${loclDir}" "${devlDir}" "${diffTool}"
generate_report "${devlDir}" "${testDir}" "${diffTool}"
generate_report "${testDir}" "${prodDir}" "${diffTool}"

show_dir_diff "${loclDir}" "${devlDir}" "${testDir}"
