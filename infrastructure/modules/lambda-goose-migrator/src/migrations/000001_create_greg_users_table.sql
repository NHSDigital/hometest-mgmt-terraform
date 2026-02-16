-- +goose Up
CREATE TABLE greg_users (
  id SERIAL PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE
);

-- +goose Down
DROP TABLE greg_users;
