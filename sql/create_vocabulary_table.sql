DROP TABLE IF EXISTS vocabulary;
CREATE TABLE IF NOT EXISTS vocabulary (
    id INTEGER PRIMARY KEY NOT NULL,
    hsk_level INTEGER NOT NULL,
    hans STRING NOT NULL,
    hant STRING NOT NULL,
    pinyin_input STRING NOT NULL,
    pinyin_display STRING NOT NULL,
    definition STRING NOT NULL,
    -- Semicolon and space `; ` separated list of definitions
    secondary_definitions STRING
);

CREATE INDEX IF NOT EXISTS idx_vocabulary_hsk_level ON vocabulary (hsk_level);
