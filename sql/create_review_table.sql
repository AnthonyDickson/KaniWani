DROP TABLE IF EXISTS review;
CREATE TABLE review (
    id INTEGER PRIMARY KEY NOT NULL,
    next_review_timestamp INTEGER NOT NULL,
    srs_stage INTEGER NOT NULL,
    correct_guesses INTEGER NOT NULL,
    wrong_guesses INTEGER NOT NULL,
    vocab_id INTEGER NOT NULL UNIQUE,
    FOREIGN KEY (vocab_id) REFERENCES vocabulary (id) ON UPDATE CASCADE ON DELETE CASCADE
);
-- Assumes access pattern: SELECT * FROM review WHERE next_review_timestamp >= now;
CREATE INDEX idx_review_next_review_timestamp ON review (next_review_timestamp);
