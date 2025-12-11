CREATE TABLE util_meta.rt_plural_word (
        word text,
        plural_form text,
        CONSTRAINT rt_plural_word_pk PRIMARY KEY ( word ),
        CONSTRAINT rt_plural_word_nk UNIQUE ( plural_form ) ) ;

COMMENT ON TABLE util_meta.rt_plural_word IS 'Plural forms of words' ;

COMMENT ON COLUMN util_meta.rt_plural_word.word IS 'The singular word.' ;
COMMENT ON COLUMN util_meta.rt_plural_word.plural_form IS 'The plural form of the word.' ;

INSERT INTO util_meta.rt_plural_word ( word, plural_form )
    VALUES
        ( 'acl', 'acls' ),
        ( 'address', 'addresses' ),
        ( 'bracket', 'brackets' ),
        ( 'branch', 'branches' ),
        ( 'category', 'categories' ),
        ( 'class', 'classes' ),
        ( 'classification', 'classifications' ),
        ( 'coord', 'coords' ),
        ( 'coordinate', 'coordinates' ),
        ( 'description', 'descriptions' ),
        ( 'division', 'divisions' ),
        ( 'entity', 'entities' ),
        ( 'grade', 'grades' ),
        ( 'group', 'groups' ),
        ( 'heading', 'headings' ),
        ( 'kind', 'kinds' ),
        ( 'label', 'labels' ),
        ( 'location', 'locations' ),
        ( 'order', 'orders' ),
        ( 'organization', 'organizations' ),
        ( 'org', 'orgs' ),
        ( 'priv', 'privs' ),
        ( 'privilege', 'privileges' ),
        ( 'permission', 'permissions' ),
        ( 'person', 'people' ),
        ( 'rank', 'ranks' ),
        ( 'role', 'roles' ),
        ( 'rubric', 'rubrics' ),
        ( 'section', 'sections' ),
        ( 'set', 'sets' ),
        ( 'sort', 'sorts' ),
        ( 'species', 'species' ),
        ( 'status', 'statuses' ),
        ( 'title', 'titles' ),
        ( 'type', 'types' ),
        ( 'user', 'users' ),
        ( 'variety', 'varieties' ) ;
