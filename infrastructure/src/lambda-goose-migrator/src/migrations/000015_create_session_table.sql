-- +goose Up
CREATE TABLE IF NOT EXISTS session
(
  session_id uuid PRIMARY KEY,
  refresh_token_id uuid NOT NULL,
  nhs_access_token text NOT NULL,
  iss text NOT NULL,
  aud text NOT NULL,
  sub text NOT NULL,
  family_name varchar(255) NOT NULL,
  given_name varchar(255),
  identity_proofing_level varchar(10) NOT NULL,
  email varchar(320),
  email_verified varchar(5),
  phone_number_verified varchar(5),
  birthdate varchar(10) NOT NULL,
  nhs_number varchar(10) NOT NULL,
  gp_ods_code varchar(20),
  session_start_at timestamp with time zone NOT NULL,
  last_refresh_at timestamp with time zone NOT NULL,
  max_expires_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT current_timestamp,
  updated_at timestamp with time zone NOT NULL DEFAULT current_timestamp,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT uq_session_refresh_token_id UNIQUE (refresh_token_id),
  CONSTRAINT chk_session_metadata_object CHECK (jsonb_typeof(metadata) = 'object'),
  CONSTRAINT chk_session_email_verified CHECK (
    email_verified IS NULL OR email_verified IN ('true', 'false')
  ),
  CONSTRAINT chk_session_phone_number_verified CHECK (
    phone_number_verified IS NULL OR phone_number_verified IN ('true', 'false')
  ),
  CONSTRAINT chk_session_nhs_number_format CHECK (nhs_number ~ '^[0-9]{10}$')
);

CREATE INDEX IF NOT EXISTS idx_session_max_expires_at
ON session (max_expires_at);


-- +goose Down
DROP INDEX IF EXISTS idx_session_max_expires_at;
DROP TABLE IF EXISTS session;
