DROP TABLE IF EXISTS completed_lesson;
CREATE TABLE completed_lesson (
    vocab_id INTEGER PRIMARY KEY NOT NULL,
    -- The Unix epoch timestamp for when the lesson was queued
    queued_at INTEGER,
    -- The Unix epoch timestamp for when the lesson was completed
    completed_at INTEGER,
    FOREIGN KEY (vocab_id) REFERENCES vocabulary (id) ON UPDATE CASCADE ON DELETE CASCADE
);
