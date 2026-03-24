DROP TABLE IF EXISTS vocabulary;
CREATE TABLE IF NOT EXISTS vocabulary (
    id INTEGER PRIMARY KEY,
    hsk_level INTEGER,
    hans STRING,
    hant STRING,
    pinyin_input STRING,
    pinyin_display STRING,
    definition STRING
);

CREATE INDEX IF NOT EXISTS idx_vocabulary_hsk_level ON vocabulary (hsk_level);
