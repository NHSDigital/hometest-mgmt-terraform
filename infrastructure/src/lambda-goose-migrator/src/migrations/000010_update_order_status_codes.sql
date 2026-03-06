-- +goose Up
-- Re-add the order_status→status_type FK with ON UPDATE CASCADE so PK renames propagate
-- +goose StatementBegin
DO $$
DECLARE _con text;
BEGIN
  SELECT conname INTO _con FROM pg_constraint
  WHERE conrelid = 'order_status'::regclass AND contype = 'f'
    AND confrelid = 'status_type'::regclass;
  IF _con IS NOT NULL THEN
    EXECUTE format('ALTER TABLE order_status DROP CONSTRAINT %I', _con);
  END IF;
END;
$$;
-- +goose StatementEnd

UPDATE status_type
SET
  status_code = 'SUBMITTED',
  description = 'Order has been submitted to the supplier'
WHERE status_code = 'PLACED';

UPDATE status_type
SET
  status_code = 'CONFIRMED',
  description = 'Order has been confirmed by the supplier'
WHERE status_code = 'ORDER_RECEIVED';

-- +goose Down
UPDATE status_type
SET
  status_code = 'PLACED',
  description = 'Order has been placed with the supplier'
WHERE status_code = 'SUBMITTED';

UPDATE status_type
SET
  status_code = 'ORDER_RECEIVED',
  description = 'Order has been confirmed by the supplier'
WHERE status_code = 'CONFIRMED';

-- Restore original constraint without ON UPDATE CASCADE
ALTER TABLE order_status
DROP CONSTRAINT order_status_status_code_fkey;

ALTER TABLE order_status
ADD CONSTRAINT order_status_status_code_fkey
FOREIGN KEY (status_code) REFERENCES status_type (status_code);
