-- +goose Up
CREATE TABLE
IF NOT EXISTS reminder_status_type
(
  status_code varchar(50) PRIMARY KEY,
  description text NOT NULL
);

INSERT INTO reminder_status_type
(status_code, description)
VALUES
('SCHEDULED', 'Reminder scheduled to be sent, should be the initial status for a reminder'),
('QUEUED', 'Reminder queued for sending'),
('FAILED', 'Reminder failed to send'),
('CANCELLED', 'Reminder cancelled')
ON CONFLICT DO NOTHING;

CREATE TABLE
IF NOT EXISTS order_status_reminder
(
  reminder_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_uid uuid NOT NULL REFERENCES test_order
  (order_uid) ON
  DELETE CASCADE,
  trigger_status varchar(50)
  NOT NULL REFERENCES status_type
  (status_code),
  reminder_number smallint NOT NULL CHECK
  (reminder_number >= 1),
  status varchar(50) NOT NULL REFERENCES reminder_status_type
  (status_code),
  triggered_at timestamp
  with time zone NOT NULL,
  sent_at timestamp
  with time zone,
  created_at timestamp
  with time zone NOT NULL DEFAULT current_timestamp,
  CONSTRAINT uq_order_status_reminder
  UNIQUE
  (order_uid, trigger_status, reminder_number)
);

CREATE INDEX
IF NOT EXISTS idx_order_status_reminder_status_triggered_at
ON order_status_reminder
(status, triggered_at);

CREATE INDEX
IF NOT EXISTS idx_order_status_reminder_order_uid
ON order_status_reminder
(order_uid);


-- +goose Down
DROP INDEX IF EXISTS idx_order_status_reminder_order_uid;
DROP INDEX IF EXISTS idx_order_status_reminder_status_triggered_at;
DROP TABLE IF EXISTS order_status_reminder;
DROP TABLE IF EXISTS reminder_status_type;
