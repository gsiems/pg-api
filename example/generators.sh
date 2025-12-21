#!/usr/bin/env bash

function gen_view_ddl() {
    local ddl_schema="${1}"
    local table_schema="${2}"
    local table_name="${3}"

    ddl_directory="${PWD}"/schema/as_generated/"${ddl_schema}"/view

    if [[ ! -d ${ddl_directory} ]]; then
        mkdir -p "${ddl_directory}"
    fi

    tmp_file=$(mktemp -p . XXXXXXXXXX.sql.tmp)

    cmd="SELECT util_meta.mk_view (
            a_object_schema => '${table_schema}',
            a_object_name => '${table_name}',
            a_ddl_schema => '${ddl_schema}'
        ) ;"

    echo "${cmd}"

    echo "${cmd}" | psql -q -t --csv example_db -f - >"${tmp_file}"

    obj_name="$(head -n 1 "${tmp_file}" | awk '{print $NF}' | cut -d '.' -f 2)"
    out_file="${ddl_directory}/${obj_name}.sql"

    cat "${tmp_file}" | sed -e 's/^"//' -e 's/"$//' >"${out_file}"
    rm "${tmp_file}"
}

function gen_resolve_id_func_ddl() {
    local ddl_schema="${1}"
    local table_schema="${2}"
    local table_name="${3}"

    ddl_directory="${PWD}"/schema/as_generated/"${ddl_schema}"/function

    if [[ ! -d ${ddl_directory} ]]; then
        mkdir -p "${ddl_directory}"
    fi

    tmp_file=$(mktemp -p . XXXXXXXXXX.sql.tmp)

    cmd="SELECT util_meta.mk_resolve_id_function (
            a_object_schema => '${table_schema}',
            a_object_name => '${table_name}',
            a_ddl_schema => '${ddl_schema}'
        ) ;"

    echo "${cmd}"

    echo "${cmd}" | psql -q -t --csv example_db -f - >"${tmp_file}"

    obj_name="$(head -n 1 "${tmp_file}" | awk '{print $5}' | cut -d '.' -f 2)"
    out_file="${ddl_directory}/${obj_name}.sql"

    cat "${tmp_file}" | sed -e 's/^"//' -e 's/"$//' >"${out_file}"
    rm "${tmp_file}"
}

function gen_priv_proc_ddl() {
    local ddl_schema="${1}"
    local table_schema="${2}"
    local table_name="${3}"
    local action="${4}"

    ddl_directory="${PWD}"/schema/as_generated/"${ddl_schema}"/procedure

    if [[ ! -d ${ddl_directory} ]]; then
        mkdir -p "${ddl_directory}"
    fi

    tmp_file=$(mktemp -p . XXXXXXXXXX.sql.tmp)

    if [ "${action}" == "delete" ]; then

        cmd="SELECT util_meta.mk_priv_${action}_procedure (
            a_object_schema => '${table_schema}',
            a_object_name => '${table_name}',
            a_ddl_schema => '${ddl_schema}'
        ) ;"

    else

        cmd="SELECT util_meta.mk_priv_${action}_procedure (
            a_object_schema => '${table_schema}',
            a_object_name => '${table_name}',
            a_ddl_schema => '${ddl_schema}',
            a_insert_audit_columns => 'created_dt,created_by_id',
            a_update_audit_columns => 'updated_dt,updated_by_id'
        ) ;"

    fi

    echo "${cmd}"

    echo "${cmd}" | psql -q -t --csv example_db -f - >"${tmp_file}"

    obj_name="$(head -n 1 "${tmp_file}" | awk '{print $5}' | cut -d '.' -f 2)"
    out_file="${ddl_directory}/${obj_name}.sql"

    cat "${tmp_file}" | sed -e 's/^"//' -e 's/"$//' >"${out_file}"
    rm "${tmp_file}"
}

function gen_can_do_func_ddl() {
    local ddl_schema="${1}"

    ddl_directory="${PWD}"/schema/as_generated/"${ddl_schema}"/function

    if [[ ! -d ${ddl_directory} ]]; then
        mkdir -p "${ddl_directory}"
    fi

    tmp_file=$(mktemp -p . XXXXXXXXXX.sql.tmp)
    out_file="${ddl_directory}/can_do.sql"

    cmd="SELECT util_meta.mk_can_do_function_shell (
            a_ddl_schema => '${ddl_schema}'
        ) ;"

    echo "${cmd}"

    echo "${cmd}" | psql -q -t --csv example_db -f - >"${tmp_file}"

    obj_name="$(head -n 1 "${tmp_file}" | awk '{print $5}' | cut -d '.' -f 2)"
    out_file="${ddl_directory}/${obj_name}.sql"

    cat "${tmp_file}" | sed -e 's/^"//' -e 's/"$//' >"${out_file}"
    rm "${tmp_file}"
}

function gen_api_func_ddl() {
    local ddl_schema="${1}"
    local table_schema="${2}"
    local table_name="${3}"
    local action="${4}"

    ddl_directory="${PWD}"/schema/as_generated/"${ddl_schema}"/function

    if [[ ! -d ${ddl_directory} ]]; then
        mkdir -p "${ddl_directory}"
    fi

    tmp_file=$(mktemp -p . XXXXXXXXXX.sql.tmp)

    cmd="SELECT util_meta.mk_${action}_function (
            a_object_schema => '${table_schema}',
            a_object_name => '${table_name}',
            a_ddl_schema => '${ddl_schema}'
        ) ;"

    echo "${cmd}"

    echo "${cmd}" | psql -q -t --csv example_db -f - >"${tmp_file}"

    obj_name="$(head -n 1 "${tmp_file}" | awk '{print $5}' | cut -d '.' -f 2)"
    out_file="${ddl_directory}/${obj_name}.sql"

    cat "${tmp_file}" | sed -e 's/^"//' -e 's/"$//' >"${out_file}"
    rm "${tmp_file}"
}

function gen_api_proc_ddl() {
    local ddl_schema="${1}"
    local table_schema="${2}"
    local table_name="${3}"
    local action="${4}"

    ddl_directory="${PWD}"/schema/as_generated/"${ddl_schema}"/procedure

    if [[ ! -d ${ddl_directory} ]]; then
        mkdir -p "${ddl_directory}"
    fi

    tmp_file=$(mktemp -p . XXXXXXXXXX.sql.tmp)

    cmd="SELECT util_meta.mk_api_procedure (
            a_action => '${action}',
            a_object_schema => '${table_schema}',
            a_object_name => '${table_name}',
            a_ddl_schema => '${ddl_schema}',
            a_insert_audit_columns => 'created_dt,created_by_id',
            a_update_audit_columns => 'updated_dt,updated_by_id'
        ) ;"

    echo "${cmd}"

    echo "${cmd}" | psql -q -t --csv example_db -f - >"${tmp_file}"

    obj_name="$(head -n 1 "${tmp_file}" | awk '{print $5}' | cut -d '.' -f 2)"
    out_file="${ddl_directory}/${obj_name}.sql"

    cat "${tmp_file}" | sed -e 's/^"//' -e 's/"$//' >"${out_file}"
    rm "${tmp_file}"
}
