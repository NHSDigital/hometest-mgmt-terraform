-- +goose Up
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
