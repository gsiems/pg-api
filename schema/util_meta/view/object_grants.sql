CREATE OR REPLACE VIEW util_meta.object_grants
AS
WITH rol AS (
    SELECT oid,
            rolname::text AS role_name
        FROM pg_catalog.pg_authid
    UNION
    SELECT 0::oid AS oid,
            'public'::text
),
schemas AS ( -- Schemas
    SELECT oid AS schema_oid,
            n.nspname::text AS schema_name,
            n.nspowner AS owner_oid,
            'schema'::text AS object_type,
            coalesce ( n.nspacl, acldefault ( 'n'::"char", n.nspowner ) ) AS acl
        FROM pg_catalog.pg_namespace n
        WHERE n.nspname !~ '^pg_'
            AND n.nspname <> 'information_schema'
),
classes AS ( -- Tables, views, etc.
    SELECT schemas.schema_oid,
            schemas.schema_name AS object_schema,
            c.oid,
            c.relname::text AS object_name,
            c.relowner AS owner_oid,
            coalesce ( ct.label, c.relkind::text ) AS object_type,
            CASE
                WHEN c.relkind = 'S' THEN coalesce ( c.relacl, acldefault ( 's'::"char", c.relowner ) )
                ELSE coalesce ( c.relacl, acldefault ( 'r'::"char", c.relowner ) )
                END AS acl
        FROM pg_catalog.pg_class c
        LEFT JOIN util_meta.relkinds ct
            ON ( ct.relkind = c.relkind::text )
        JOIN schemas
            ON ( schemas.schema_oid = c.relnamespace )
        WHERE c.relkind IN ( 'r', 'v', 'm', 'S', 'f', 'p' )
),
cols AS ( -- Columns
    SELECT c.object_schema,
            null::integer AS oid,
            c.object_name || '.' || a.attname::text AS object_name,
            'column' AS object_type,
            c.owner_oid,
            coalesce ( a.attacl, acldefault ( 'c'::"char", c.owner_oid ) ) AS acl
        FROM pg_catalog.pg_attribute a
        JOIN classes c
            ON ( a.attrelid = c.oid )
        WHERE a.attnum > 0
            AND NOT a.attisdropped
),
procs AS ( -- Procedures and functions
    SELECT schemas.schema_oid,
            schemas.schema_name AS object_schema,
            p.oid,
            p.proname::text AS object_name,
            p.proowner AS owner_oid,
            coalesce ( pt.label, 'function' ) AS object_type,
            pg_catalog.pg_get_function_arguments ( p.oid ) AS calling_arguments,
            coalesce ( p.proacl, acldefault ( 'f'::"char", p.proowner ) ) AS acl
        FROM pg_catalog.pg_proc p
        JOIN schemas
            ON ( schemas.schema_oid = p.pronamespace )
        LEFT JOIN util_meta.prokinds pt
            ON ( pt.prokind = p.prokind::text )
),
udts AS ( -- User defined types
    SELECT schemas.schema_oid,
            schemas.schema_name AS object_schema,
            t.oid,
            t.typname::text AS object_name,
            t.typowner AS owner_oid,
            coalesce ( typtypes.label, t.typtype::text ) AS object_type,
            coalesce ( t.typacl, acldefault ( 'T'::"char", t.typowner ) ) AS acl
        FROM pg_catalog.pg_type t
        JOIN schemas
            ON ( schemas.schema_oid = t.typnamespace )
        LEFT JOIN util_meta.typtypes
            ON ( typtypes.typtype = t.typtype::text )
        WHERE ( t.typrelid = 0
                OR ( SELECT c.relkind = 'c'
                        FROM pg_catalog.pg_class c
                        WHERE c.oid = t.typrelid ) )
            AND NOT EXISTS (
                SELECT 1
                    FROM pg_catalog.pg_type el
                    WHERE el.oid = t.typelem
                        AND el.typarray = t.oid )
        --AND t.typtype NOT IN ( 'p' )
        --AND NOT ( t.typtype = 'c'
        --    AND n.nspname = 'pg_catalog' )
),
fdws AS ( -- Foreign data wrappers
    SELECT null::oid AS schema_oid,
            null::text AS object_schema,
            p.oid,
            p.fdwname::text AS object_name,
            p.fdwowner AS owner_oid,
            'foreign data wrapper' AS object_type,
            coalesce ( p.fdwacl, acldefault ( 'F'::"char", p.fdwowner ) ) AS acl
        FROM pg_catalog.pg_foreign_data_wrapper p
),
fsrvs AS ( -- Foreign servers
    SELECT null::oid AS schema_oid,
            null::text AS object_schema,
            p.oid,
            p.srvname::text AS object_name,
            p.srvowner AS owner_oid,
            'foreign server' AS object_type,
            coalesce ( p.srvacl, acldefault ( 'S'::"char", p.srvowner ) ) AS acl
        FROM pg_catalog.pg_foreign_server p
),
all_objects AS (
    SELECT schema_name AS object_schema,
            object_type,
            schema_name AS object_name,
            null::text AS calling_arguments,
            owner_oid,
            acl
        FROM schemas
    UNION
    SELECT object_schema,
            object_type,
            object_name,
            null::text AS calling_arguments,
            owner_oid,
            acl
        FROM classes
    UNION
    SELECT object_schema,
            object_type,
            object_name,
            null::text AS calling_arguments,
            owner_oid,
            acl
        FROM cols
    UNION
    SELECT object_schema,
            object_type,
            object_name,
            calling_arguments,
            owner_oid,
            acl
        FROM procs
    UNION
    SELECT object_schema,
            object_type,
            object_name,
            null::text AS calling_arguments,
            owner_oid,
            acl
        FROM udts
    UNION
    SELECT object_schema,
            object_type,
            object_name,
            null::text AS calling_arguments,
            owner_oid,
            acl
        FROM fdws
    UNION
    SELECT object_schema,
            object_type,
            object_name,
            null::text AS calling_arguments,
            owner_oid,
            acl
        FROM fsrvs
),
acl_base AS (
    SELECT object_schema,
            object_type,
            object_name,
            calling_arguments,
            owner_oid,
            ( aclexplode ( acl ) ).grantor AS grantor_oid,
            ( aclexplode ( acl ) ).grantee AS grantee_oid,
            ( aclexplode ( acl ) ).privilege_type AS privilege_type,
            ( aclexplode ( acl ) ).is_grantable AS is_grantable
        FROM all_objects
)
SELECT acl_base.object_schema,
        acl_base.object_type,
        acl_base.object_name,
        acl_base.calling_arguments,
        owner.role_name AS object_owner,
        grantor.role_name AS grantor,
        grantee.role_name AS grantee,
        acl_base.privilege_type,
        acl_base.is_grantable
    FROM acl_base
    JOIN rol owner
        ON ( owner.oid = acl_base.owner_oid )
    JOIN rol grantor
        ON ( grantor.oid = acl_base.grantor_oid )
    JOIN rol grantee
        ON ( grantee.oid = acl_base.grantee_oid )
    WHERE acl_base.grantor_oid <> acl_base.grantee_oid ;

COMMENT ON VIEW util_meta.object_grants IS 'Privilege grants for application database objects' ;

COMMENT ON COLUMN util_meta.object_grants.object_schema IS 'The name of the schema that contains the object.' ;
COMMENT ON COLUMN util_meta.object_grants.object_name IS 'The name of the database object.' ;
COMMENT ON COLUMN util_meta.object_grants.object_type IS 'The type of the database object.' ;
COMMENT ON COLUMN util_meta.object_grants.calling_arguments IS '(function and procedure only) The list of calling arguments to the function or procedure.' ;
COMMENT ON COLUMN util_meta.object_grants.object_owner IS 'The owner of the database object.' ;
COMMENT ON COLUMN util_meta.object_grants.grantor IS 'The user/role that granted the privilege.' ;
COMMENT ON COLUMN util_meta.object_grants.grantee IS 'The user/role that the privilege was granted to.' ;
COMMENT ON COLUMN util_meta.object_grants.privilege_type IS 'The type of privilege.' ;
COMMENT ON COLUMN util_meta.object_grants.is_grantable IS 'Indicates if the privilege may be granted to others.' ;
