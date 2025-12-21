CREATE OR REPLACE VIEW util_meta.extensions
AS
SELECT px.oid,
        px.extname AS extension_name,
        ( pg_catalog.pg_get_userbyid ( px.extowner ) )::text AS extension_owner,
        n.nspname::text AS schema_name,
        px.extversion AS extension_version
    FROM pg_catalog.pg_extension px
    JOIN pg_catalog.pg_namespace n
        ON ( px.extnamespace = n.oid ) ;

COMMENT ON VIEW util_meta.extensions IS 'View of the extensions installed in the database' ;
COMMENT ON COLUMN util_meta.extensions.oid IS 'The OID of the extension' ;
COMMENT ON COLUMN util_meta.extensions.extension_name IS 'The name of the extension' ;
COMMENT ON COLUMN util_meta.extensions.extension_owner IS 'The owner of the extension' ;
COMMENT ON COLUMN util_meta.extensions.schema_name IS 'The schema that the extension is installed in' ;
COMMENT ON COLUMN util_meta.extensions.extension_version IS 'The version of the extension' ;
