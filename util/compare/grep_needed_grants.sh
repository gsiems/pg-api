#!/usr/bin/env bash

################################################################################
# grep_needed_grants.sh
#
# The purpose is to try to determine the list of grants needed by the various
# schema owners in order for the objects that they own to function properly.
#
# ASSERTION: This is being run from the compare directory and is being run
#   against the DDL exported by export_db_ddl.sh. Running from a different
#   location or against a different exported DDL directory structure will mess
#   with the output of the awk print commands.
#
# ASSERTION: The schema and objects within the schema are owned by the same role.
#
# ASSERTION: There is no functional overloading going on, so it possible to
#   extract the function/procedure signatures from the exported DDL.
#
################################################################################

dir=$1

case "${dir}" in
    ./*) dir=$(echo "${dir}" | sed 's/^\.\///') ;;
esac

function find_ddl_file() {
    local dir="${1}"
    local obj="${3}"

    local type
    local objSchema
    local objName

    type="$(echo "${2}" | tr "[:upper:]" "[:lower:]")"

    objSchema="$(echo "${obj}" | cut -d '.' -f 1)"
    objName="$(echo "${obj}" | cut -d '.' -f 2)"

    schemaDir=$(find "${dir}" -type d -name "${objSchema}")
    if [[ -d ${schemaDir} ]]; then
        sqlFile="${schemaDir}/${type}/${objName}.sql"
        if [[ -f ${sqlFile} ]]; then
            echo "${sqlFile}"
        fi
    fi
}

function get_proc_signature() {
    local dir="${1}"
    local type="${2}"
    local obj="${3}"

    sqlFile=$(find_ddl_file "${dir}" "${type}" "${obj}")
    if [[ -f ${sqlFile} ]]; then
        local sig
        sig="$(grep -P "(OWNER TO|GRANT EXECUTE|REVOKE)" "${sqlFile}" | head -n 1 | cut -d '(' -f 2 | cut -d ')' -f 1)"
        echo "${sig}"
    fi
}

tmpFile=$(mktemp -p . tmp.XXXXXXXXXX.temp.tmp)
schemaOwners=$(mktemp -p . tmp.XXXXXXXXXX.temp.tmp)
neededGrants=$(mktemp -p . tmp.XXXXXXXXXX.temp.tmp)
usageGrants=$(mktemp -p . tmp.XXXXXXXXXX.temp.tmp)

grep -irP 'alter schema.+owner to' "${dir}" | sed 's/;//' | awk '{print $3 " " $6}' >"${schemaOwners}"

# FUNCTION (select from):
grep -riP '^[\t ]+from[\t ].+[a-z0-9_]+\.[a-z0-9_]+[\t ]*\(' "${dir}" |
    perl -pe 's/[\t ]+/ /g' |
    perl -pe 's/\(.*//g' |
    perl -pe 's/  +/ /g' | tr '/' ' ' |
    awk '{print $4 " FUNCTION " $8}' >>"${tmpFile}"

# PROCEDURE:
grep -riP '\bcall[\t ]+[^\.]+\.[^\.]+[\t ]*\(' "${dir}" |
    perl -pe 's/[\t ]+/ /g' |
    perl -pe 's/\(.*//g' |
    perl -pe 's/  +/ /g' | tr '/' ' ' |
    awk '{print $4 " PROCEDURE " $8}' >>"${tmpFile}"

# DELETE:
grep -riP '^[\t ]*delete[\t ]+from' "${dir}" |
    perl -pe 's/[\t ]+/ /g' |
    perl -pe 's/\(.*//g' |
    perl -pe 's/  +/ /g' | tr '/' ' ' |
    awk '{print $4 " " $7 " " $9}' >>"${tmpFile}"

# INSERT:
grep -riP '^[\t ]*insert[\t ]+into' "${dir}" |
    perl -pe 's/[\t ]+/ /g' |
    perl -pe 's/\(.*//g' |
    perl -pe 's/  +/ /g' | tr '/' ' ' |
    awk '{print $4 " " $7 " " $9}' >>"${tmpFile}"

# UPDATE:
grep -riP '^[\t ]*update[\t ]' "${dir}" |
    perl -pe 's/[\t ]+/ /g' |
    perl -pe 's/\(.*//g' |
    perl -pe 's/  +/ /g' | tr '/' ' ' |
    awk '{print $4 " " $7 " " $8}' >>"${tmpFile}"

# SELECT (table, view):
grep -riP '^[\t ]*from[\t ]+[a-z0-9_]+\.[a-z0-9_]+[\t ]' "${dir}" |
    perl -pe 's/[\t ]+/ /g' |
    grep -vP '\(' |
    perl -pe 's/  +/ /g' | tr '/' ' ' |
    awk '{print $4 " SELECT " $8}' >>"${tmpFile}"

# SELECT (join table, view):
grep -riP '\bjoin[\t ]+[a-z0-9_]+\.[a-z0-9_]+[\t ]' "${dir}" |
    perl -pe 's/[\t ]+/ /g' |
    perl -pe 's/:.+join /: JOIN /ig' | perl -pe 's/ on\b.+//ig' | perl -pe 's/\blateral\b//ig' |
    grep -vP '\(' |
    perl -pe 's/  +/ /g' | tr '/' ' ' |
    awk '{print $4 " SELECT " $8}' >>"${tmpFile}"

# FUNCTION (join):
grep -riP '\bjoin[\t ]+[a-z0-9_]+\.[a-z0-9_]+[\t ]' "${dir}" |
    perl -pe 's/[\t ]+/ /g' |
    perl -pe 's/:.+join /: JOIN /ig' | perl -pe 's/ on\b.+//ig' | perl -pe 's/\blateral\b//ig' |
    grep -P '\(' |
    perl -pe 's/\(.*//g' |
    perl -pe 's/  +/ /g' | tr '/' ' ' |
    awk '{print $4 " FUNCTION " $8}' >>"${tmpFile}"

# SEQUENCE:
grep -ri nextval "${dir}" | grep -viP '\balter\b' |
    perl -pe 's/[\t ]+/ /g' |
    tr "/\(\)'" ' ' | perl -pe 's/:.+nextval +/: nextval /g' | grep -iP 'nextval [a-z0-9_]+\.[a-z0-9_]+' |
    perl -pe 's/  +/ /g' | tr '/' ' ' |
    awk '{print $4 " SEQUENCE " $8}' >>"${tmpFile}"

# TYPE

sort -u "${tmpFile}" >"${neededGrants}"

while read -r rec; do
    schema=$(echo "${rec}" | cut -d " " -f 1)
    type=$(echo "${rec}" | cut -d " " -f 2)
    obj=$(echo "${rec}" | cut -d " " -f 3)

    if [[ -n ${obj} ]]; then

        objSchema=$(echo "${obj}" | cut -d "." -f 1)
        schemaOwner=$(grep "^${objSchema} " "${schemaOwners}" | cut -d " " -f 2)
        codeOwner=$(grep "^${schema} " "${schemaOwners}" | cut -d " " -f 2)

        if [[ -n ${codeOwner} ]] &&
            [[ -n ${schemaOwner} ]] &&
            [[ ${codeOwner} != "${schemaOwner}" ]]; then

            #echo "'${codeOwner}', '${schemaOwner}', '${objSchema}': '${rec}'"

            echo "GRANT USAGE ON SCHEMA ${objSchema} TO ${codeOwner} ;" >>"${usageGrants}"

            case "${type}" in
                FUNCTION)
                    sig=$(get_proc_signature "${dir}" "${type}" "${obj}")
                    if [[ -n ${sig} ]]; then
                        echo "GRANT EXECUTE ON ${type} ${obj}(${sig}) TO ${codeOwner};"
                    else
                        echo "GRANT EXECUTE ON ${type} ${obj} TO ${codeOwner};"
                    fi
                    ;;
                PROCEDURE)
                    sig=$(get_proc_signature "${dir}" "${type}" "${obj}")
                    if [[ -n ${sig} ]]; then
                        echo "GRANT EXECUTE ON ${type} ${obj}(${sig}) TO ${codeOwner};"
                    else
                        echo "GRANT EXECUTE ON ${type} ${obj} TO ${codeOwner};"
                    fi
                    ;;
                SEQUENCE) echo "GRANT USAGE,SELECT ON ${type} ${obj} TO ${codeOwner};" ;;
                *) echo "GRANT ${type} ON ${obj} TO ${codeOwner};" ;;
            esac

        fi
    fi

done <"${neededGrants}"

sort -u "${usageGrants}"

rm "${tmpFile}"
rm "${schemaOwners}"
rm "${neededGrants}"
rm "${usageGrants}"
