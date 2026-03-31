DROP TABLE IF EXISTS lesson_queue;
CREATE TABLE lesson_queue (
    vocab_id INTEGER PRIMARY KEY NOT NULL,
    -- The Unix epoch timestamp for when the lesson was queued
    queued_at INTEGER,
    FOREIGN KEY (vocab_id) REFERENCES vocabulary (id) ON UPDATE CASCADE ON DELETE CASCADE
);
