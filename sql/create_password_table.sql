DROP TABLE IF EXISTS password;
CREATE TABLE password (
    -- This is singleton table
    id INTEGER NOT NULL DEFAULT 1 UNIQUE CHECK (id = 1),
    password_hash TEXT NOT NULL
);

