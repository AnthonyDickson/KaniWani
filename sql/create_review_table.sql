DROP TABLE IF EXISTS review;
CREATE TABLE review (
    id INTEGER PRIMARY KEY,
    next_review_timestamp INTEGER,
    srs_stage INTEGER,
    correct_guesses INTEGER,
    wrong_guesses INTEGER,
    vocab_id INTEGER UNIQUE,
    FOREIGN KEY (vocab_id) REFERENCES vocabulary (id) ON UPDATE CASCADE ON DELETE CASCADE
);
-- Assumes access pattern: SELECT * FROM review WHERE next_review_timestamp >= now;
CREATE INDEX idx_review_next_review_timestamp ON review (next_review_timestamp);
