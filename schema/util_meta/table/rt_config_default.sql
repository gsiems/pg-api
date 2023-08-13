CREATE TABLE util_meta.rt_config_default (
    default_param_id smallint NOT NULL,
    config_value text NOT NULL,
    CONSTRAINT rt_config_default_pk PRIMARY KEY ( default_param_id ),
    CONSTRAINT rt_config_default_fk01 FOREIGN KEY ( default_param_id ) REFERENCES util_meta.st_default_param ( id ) ) ;

COMMENT ON TABLE util_meta.rt_config_default IS 'The use defined default configuration parameters (to use when not specified in the call to the code-generating function).' ;

COMMENT ON COLUMN util_meta.rt_config_default.config_param_id IS 'The configuration parameter.' ;
COMMENT ON COLUMN util_meta.rt_config_default.config_value IS 'The default value of the configuration parameter.' ;
