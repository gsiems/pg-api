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

COMMENT ON VIEW util_meta.prokinds IS 'Labels for pg_proc.prokind values' ;
