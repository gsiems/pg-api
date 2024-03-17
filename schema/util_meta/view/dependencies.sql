CREATE OR REPLACE VIEW util_meta.dependencies
AS
WITH dependents AS (
    SELECT ev_class,
            split_part ( regexp_split_to_table ( ev_action, ':relid ' ), ' ', 1 ) AS dependent_oid
        FROM pg_rewrite
),
dep_map AS (
    SELECT ev_class AS parent_oid,
            dependent_oid::oid AS child_oid
        FROM dependents
        WHERE dependent_oid NOT LIKE '%QUERY'
            AND ev_class <> dependent_oid::oid
),
rels AS materialized (
    SELECT schemas.schema_oid,
            schemas.schema_name,
            c.oid AS object_oid,
            c.relname::text AS object_name,
            pg_catalog.pg_get_userbyid ( c.relowner )::text AS owner_name,
            coalesce ( obj_type.label, 'other (' || c.relkind || ')' ) AS object_type
        FROM pg_catalog.pg_class c
        JOIN util_meta.schemas
            ON ( schemas.schema_oid = c.relnamespace )
        LEFT JOIN util_meta.relkinds AS obj_type
            ON ( obj_type.relkind = c.relkind::text )
),
procs AS materialized (
    SELECT n.oid AS schema_oid,
            n.nspname::text AS schema_name,
            p.oid AS object_oid,
            p.proname::text AS object_name,
            ( pg_catalog.pg_get_userbyid ( p.proowner ) )::text AS owner_name,
            pt.label AS object_type,
            p.prorettype AS return_type_oid
        FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n
            ON ( n.oid = p.pronamespace )
        LEFT JOIN util_meta.prokinds pt
            ON ( pt.prokind = p.prokind::text )
)
SELECT c.schema_oid,
        c.schema_name,
        c.object_oid,
        c.object_name,
        c.owner_name,
        c.object_type,
        c2.schema_oid AS dep_schema_oid,
        c2.schema_name AS dep_schema_name,
        c2.object_oid AS dep_object_oid,
        c2.object_name AS dep_object_name,
        c2.owner_name AS dep_owner_name,
        c2.object_type AS dep_object_type
    FROM dep_map d
    JOIN rels c
        ON ( c.object_oid = d.child_oid )
    JOIN rels c2
        ON ( c2.object_oid = d.parent_oid )
UNION
-- functions/procedures
SELECT c.schema_oid,
        c.schema_name,
        c.object_oid,
        c.object_name,
        c.owner_name,
        c.object_type,
        p.schema_oid AS dep_schema_oid,
        p.schema_name AS dep_schema_name,
        p.object_oid AS dep_object_oid,
        p.object_name AS dep_object_name,
        p.owner_name AS dep_owner_name,
        coalesce ( p.object_type, c.object_type ) AS dep_object_type
    FROM procs p
    JOIN pg_catalog.pg_type t
        ON ( t.oid = p.return_type_oid )
    JOIN rels c
        ON ( c.object_oid = t.typrelid )
UNION
-- triggers
SELECT c.schema_oid,
        c.schema_name,
        c.object_oid,
        c.object_name,
        c.owner_name,
        c.object_type,
        c.schema_oid AS dep_schema_oid,
        c.schema_name AS dep_schema_name,
        c.object_oid AS dep_object_oid,
        t.tgname::text AS dep_object_name,
        c.owner_name AS dep_owner_name,
        'trigger' AS dep_object_type
    FROM pg_catalog.pg_trigger t
    JOIN rels c
        ON ( c.object_oid = t.tgrelid )
    WHERE NOT t.tgisinternal
UNION
-- trigger functions
SELECT p.schema_oid,
        p.schema_name,
        p.object_oid,
        p.object_name,
        p.owner_name,
        coalesce ( p.object_type, 'function' ) AS object_type,
        c.schema_oid AS dep_schema_oid,
        c.schema_name AS dep_schema_name,
        t.oid AS dep_object_oid,
        t.tgname::text AS dep_object_name,
        c.owner_name AS dep_owner_name,
        'trigger' AS dep_object_type
    FROM pg_catalog.pg_trigger t
    JOIN rels c
        ON ( c.object_oid = t.tgrelid )
    JOIN procs p
        ON ( p.object_oid = t.tgfoid )
    WHERE NOT t.tgisinternal ;

COMMENT ON VIEW util_meta.dependencies IS 'View of the application database object dependencies' ;
COMMENT ON COLUMN util_meta.dependencies.schema_oid IS 'The OID of the schema.' ;
COMMENT ON COLUMN util_meta.dependencies.schema_name IS 'The name of the schema.' ;
COMMENT ON COLUMN util_meta.dependencies.object_oid IS 'The OID of the object.' ;
COMMENT ON COLUMN util_meta.dependencies.object_name IS 'The name of the object.' ;
COMMENT ON COLUMN util_meta.dependencies.owner_name IS 'The name of the owner of the object.' ;
COMMENT ON COLUMN util_meta.dependencies.object_type IS 'The type of the object.' ;
COMMENT ON COLUMN util_meta.dependencies.dep_schema_oid IS 'The OID of the dependent schema.' ;
COMMENT ON COLUMN util_meta.dependencies.dep_schema_name IS 'The name of the dependent schema.' ;
COMMENT ON COLUMN util_meta.dependencies.dep_object_oid IS 'The OID of the dependent object.' ;
COMMENT ON COLUMN util_meta.dependencies.dep_object_name IS 'The name of the dependent object.' ;
COMMENT ON COLUMN util_meta.dependencies.dep_owner_name IS 'The name of the owner of the dependent object.' ;
COMMENT ON COLUMN util_meta.dependencies.dep_object_type IS 'The type of the dependent object.' ;
