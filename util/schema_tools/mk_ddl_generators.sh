#!/usr/bin/env bash

function gen_ddl_generator() {
    local func_name="${1}"

    tmp_file=$(mktemp -p . XXXXXXXXXX.sql.tmp)

    cmd="SELECT util_meta.mk_ddl_generator_script ( '${func_name}' ) ;"

    echo "${cmd}"

    echo "${cmd}" | psql -q -t --csv example_db -f - >"${tmp_file}"

    obj_name="$(head -n 1 "${tmp_file}" | awk '{print $NF}' | cut -d '.' -f 2)"
    out_file="${func_name}.sh"

    cat "${tmp_file}" | sed -e 's/^"//' -e 's/"$//' -e 's/""/"/g' >"${out_file}"
    rm "${tmp_file}"
}

cd "$(dirname "$0")" || exit 1

exit

gen_ddl_generator mk_api_procedure
gen_ddl_generator mk_can_do_function_shell
gen_ddl_generator mk_find_function
gen_ddl_generator mk_get_function
gen_ddl_generator mk_json_function_wrapper
gen_ddl_generator mk_json_user_type
gen_ddl_generator mk_json_view
gen_ddl_generator mk_list_children_function
gen_ddl_generator mk_list_function
gen_ddl_generator mk_object_migration
gen_ddl_generator mk_priv_delete_procedure
gen_ddl_generator mk_priv_insert_procedure
gen_ddl_generator mk_priv_update_procedure
gen_ddl_generator mk_priv_upsert_procedure
gen_ddl_generator mk_resolve_id_function
gen_ddl_generator mk_user_type
gen_ddl_generator mk_view
