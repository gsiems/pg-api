CREATE OR REPLACE VIEW util_meta.prokinds
AS
SELECT *
    FROM (
        VALUES
            ( 'a', 'aggregate' ),
            ( 'f', 'function' ),
            ( 'p', 'procedure' ),
            ( 'w', 'window' )
        ) AS t ( prokind, label ) ;

COMMENT ON VIEW util_meta.prokinds IS 'Labels for pg_proc.prokind (procedure type) values' ;

COMMENT ON COLUMN util_meta.prokinds.prokind IS 'The pg_proc.prokind value' ;
COMMENT ON COLUMN util_meta.prokinds.label IS 'The label/name associated with the prokind value' ;
