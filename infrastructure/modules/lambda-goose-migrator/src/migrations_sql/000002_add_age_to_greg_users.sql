-- +goose Up
ALTER TABLE greg-users ADD COLUMN age INT;

-- +goose Down
ALTER TABLE greg-users DROP COLUMN age;
