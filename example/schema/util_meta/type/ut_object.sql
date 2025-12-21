/*
SELECT util_meta.mk_user_type (
            a_object_schema => 'util_meta',
            a_object_name => 'objects' ) ;
*/

CREATE TYPE util_meta.ut_object AS (
        schema_oid oid,
        schema_name text,
        object_oid oid,
        object_name text,
        object_owner text,
        base_object_type text,
        object_type text,
        full_object_name text,
        row_count bigint,
        directory_name text,
        file_name text,
        procedure_language text,
        result_data_type text,
        calling_arguments text,
        calling_signature text,
        comments text ) ;

COMMENT ON TYPE util_meta.ut_object IS 'User type for: util_meta.objects' ;
