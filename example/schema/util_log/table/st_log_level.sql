CREATE TABLE util_log.st_log_level (
    id int,
    name text,
    CONSTRAINT st_log_level_pk PRIMARY KEY ( id ),
    CONSTRAINT st_log_level_nk UNIQUE ( name ) );

COMMENT ON TABLE util_log.st_log_level IS 'Valid/recognized logging levels.' ;
COMMENT ON COLUMN util_log.st_log_level.id IS 'The ID of the logging level.' ;
COMMENT ON COLUMN util_log.st_log_level.name IS 'The name of the logging level.' ;

INSERT INTO util_log.st_log_level (
        id,
        name )
    VALUES ( 10, 'Exception' ),
        ( 20, 'Entry' ),
        ( 30, 'Begin' ),
        ( 40, 'Info' ),
        ( 50, 'Debug' ) ;
