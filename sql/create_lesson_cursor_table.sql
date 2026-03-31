DROP TABLE IF EXISTS lesson_cursor;
CREATE TABLE lesson_cursor (
    -- This is singleton table
    id INTEGER NOT NULL DEFAULT 1 UNIQUE CHECK (id = 1),
    -- Cursor for keeping track of which vocab items have been queued for lessons.
    -- Assumes that vocab IDs are consecutive and strictly increasing, which the auto index should satisfy.
    last_queued_vocab_id INTEGER NOT NULL UNIQUE,
    FOREIGN KEY (last_queued_vocab_id ) REFERENCES vocabulary (id) ON UPDATE CASCADE ON DELETE CASCADE
);

