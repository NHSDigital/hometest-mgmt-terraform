-- +goose Up
ALTER TABLE users ADD COLUMN age INT;

-- +goose Down
ALTER TABLE users DROP COLUMN age;
