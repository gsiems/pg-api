CREATE OR REPLACE VIEW util_meta.relkinds
AS
SELECT *
    FROM (
        VALUES
            ( 'c', 'type' ),
            ( 'f', 'foreign table' ),
            ( 'i', 'index' ),
            ( 'm', 'materialized view' ),
            ( 'p', 'partitioned table' ),
            ( 'r', 'table' ),
            ( 's', 'special' ),
            ( 't', 'TOAST table' ),
            ( 'v', 'view' ),
            ( 'I', 'partitioned index' ),
            ( 'S', 'sequence' )
        ) AS t ( relkind, label ) ;

COMMENT ON VIEW util_meta.relkinds IS 'Labels for pg_class.relkind (object type) values' ;

COMMENT ON COLUMN util_meta.relkinds.relkind IS 'The pg_class.relkind value' ;
COMMENT ON COLUMN util_meta.relkinds.label IS 'The label/name associated with the prokind value' ;
