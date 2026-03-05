-- +goose Up
CREATE TABLE consent
(
  consent_uid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- NOTE: We intentionally use ON DELETE RESTRICT here to prevent deletion of
  -- test_order rows once consent has been recorded, for audit/legal traceability.
  order_uid uuid NOT NULL REFERENCES test_order (order_uid) ON DELETE RESTRICT,
  created_at timestamp with time zone NOT NULL DEFAULT current_timestamp
);

CREATE UNIQUE INDEX idx_consent_order_uid ON consent (order_uid);


-- +goose Down
-- Intentionally omitted: the consent table holds legally required audit data
-- and must never be dropped, even in a rollback scenario.
