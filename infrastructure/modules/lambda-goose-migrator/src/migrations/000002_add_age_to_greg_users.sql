-- +goose Up
ALTER TABLE greg_users ADD COLUMN age INT;

-- +goose Down
ALTER TABLE greg_users DROP COLUMN age;
