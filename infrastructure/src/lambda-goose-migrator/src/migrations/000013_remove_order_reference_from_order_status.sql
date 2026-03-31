-- +goose Up
ALTER TABLE order_status
DROP COLUMN order_reference;


-- +goose Down
ALTER TABLE order_status
ADD COLUMN order_reference bigint;
