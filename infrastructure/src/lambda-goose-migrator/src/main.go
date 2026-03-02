package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/url"
	"os"
	"regexp"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	_ "github.com/lib/pq"
	"github.com/pressly/goose/v3"
)

// getDBPassword fetches the DB password from AWS Secrets Manager using the ARN
func getDBPassword(secretArn string) (string, error) {
	sess, err := session.NewSession()
	if err != nil {
		return "", fmt.Errorf("failed to create AWS session: %w", err)
	}
	client := secretsmanager.New(sess)
	input := &secretsmanager.GetSecretValueInput{
		SecretId: aws.String(secretArn),
	}
	result, err := client.GetSecretValue(input)
	if err != nil {
		return "", fmt.Errorf("failed to get secret value: %w", err)
	}
	var secretString string
	if result.SecretString != nil {
		secretString = *result.SecretString
	} else {
		return "", fmt.Errorf("secret value is binary, not supported")
	}
	// Assume the secret is a JSON with at least a "password" field
	var secretMap map[string]string
	if err := json.Unmarshal([]byte(secretString), &secretMap); err != nil {
		return "", fmt.Errorf("failed to unmarshal secret JSON: %w", err)
	}
	password, ok := secretMap["password"]
	if !ok {
		return "", fmt.Errorf("password field not found in secret")
	}
	return password, nil
}

// buildPostgresURL constructs the PostgreSQL connection URL from environment variables and Secrets Manager
func buildPostgresURL() (string, error) {
	user := os.Getenv("DB_USERNAME")
	host := os.Getenv("DB_ADDRESS")
	port := os.Getenv("DB_PORT")
	dbname := os.Getenv("DB_NAME")
	secretArn := os.Getenv("DB_SECRET_ARN")

	if user == "" || host == "" || port == "" || dbname == "" || secretArn == "" {
		return "", fmt.Errorf("missing one or more required environment variables")
	}

	password, err := getDBPassword(secretArn)
	if err != nil {
		return "", fmt.Errorf("failed to retrieve DB password: %w", err)
	}

	// URL-encode username and password
	encodedUser := url.QueryEscape(user)
	encodedPassword := url.QueryEscape(password)

	return fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=require", encodedUser, encodedPassword, host, port, dbname), nil
}

// setupSchemaAndUser creates the schema if it doesn't exist and ensures app_user role
// has appropriate access scoped to that schema only.
// The password is read from the Terraform-managed Secrets Manager secret.
func setupSchemaAndUser(db *sql.DB, schema, appUserSecretName string) error {
	appUsername := fmt.Sprintf("app_user_%s", schema)

	log.Printf("Setting up schema '%s' and user '%s'...", schema, appUsername)

	// Read the password from the Terraform-managed Secrets Manager secret
	password, err := getDBPassword(appUserSecretName)
	if err != nil {
		return fmt.Errorf("failed to read app user password from secret %s: %w", appUserSecretName, err)
	}

	// Create schema if not exists
	if _, err := db.Exec(fmt.Sprintf("CREATE SCHEMA IF NOT EXISTS %s", schema)); err != nil {
		return fmt.Errorf("failed to create schema %s: %w", schema, err)
	}
	log.Printf("Schema '%s' ensured", schema)

	// Check if role exists
	var roleExists bool
	err = db.QueryRow("SELECT EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = $1)", appUsername).Scan(&roleExists)
	if err != nil {
		return fmt.Errorf("failed to check if role %s exists: %w", appUsername, err)
	}

	if !roleExists {
		// Create the role with the password from Secrets Manager
		if _, err := db.Exec(fmt.Sprintf("CREATE ROLE %s LOGIN PASSWORD '%s'", appUsername, password)); err != nil {
			return fmt.Errorf("failed to create role %s: %w", appUsername, err)
		}
		log.Printf("Created role '%s'", appUsername)
	} else {
		// Sync password with the Terraform-managed secret (supports rotation)
		if _, err := db.Exec(fmt.Sprintf("ALTER ROLE %s PASSWORD '%s'", appUsername, password)); err != nil {
			return fmt.Errorf("failed to update password for role %s: %w", appUsername, err)
		}
		log.Printf("Synced password for existing role '%s' from Secrets Manager", appUsername)
	}

	// Set default search_path for the role so it always uses the correct schema
	if _, err := db.Exec(fmt.Sprintf("ALTER ROLE %s SET search_path TO %s", appUsername, schema)); err != nil {
		return fmt.Errorf("failed to set search_path for %s: %w", appUsername, err)
	}

	// Grant schema usage and DML privileges
	grants := []string{
		fmt.Sprintf("GRANT USAGE ON SCHEMA %s TO %s", schema, appUsername),
		fmt.Sprintf("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA %s TO %s", schema, appUsername),
		fmt.Sprintf("GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA %s TO %s", schema, appUsername),
		fmt.Sprintf("ALTER DEFAULT PRIVILEGES IN SCHEMA %s GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %s", schema, appUsername),
		fmt.Sprintf("ALTER DEFAULT PRIVILEGES IN SCHEMA %s GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO %s", schema, appUsername),
	}

	for _, grant := range grants {
		if _, err := db.Exec(grant); err != nil {
			return fmt.Errorf("failed to execute grant '%s': %w", grant, err)
		}
	}

	log.Printf("Granted schema-scoped privileges to '%s' on schema '%s'", appUsername, schema)
	return nil
}

// Response struct
type Response struct {
	Message string `json:"message"`
}

// HandleRequest is the handler function for the Lambda function
func HandleRequest(ctx context.Context) (Response, error) {
	log.Println("Starting Goose migration Lambda handler")

	schema := os.Getenv("DB_SCHEMA")
	appUserSecretName := os.Getenv("APP_USER_SECRET_NAME")

	if schema == "" {
		schema = "public"
		log.Println("DB_SCHEMA not set, defaulting to 'public'")
	}

	dbURL, err := buildPostgresURL()
	if err != nil {
		log.Printf("Failed to build DB URL: %s", redactPassword(err.Error()))
		return Response{"Failed to build DB URL: " + redactPassword(err.Error())}, err
	}

	// Redact password in log output
	log.Printf("Connecting to DB: %s", redactPassword(dbURL))
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Printf("Failed to connect to DB: %s", redactPassword(err.Error()))
		return Response{"Failed to connect to DB"}, err
	}
	defer db.Close()

	// Step 1: Create schema and app_user (runs as master user)
	if schema != "public" {
		if appUserSecretName == "" {
			return Response{"APP_USER_SECRET_NAME is required when DB_SCHEMA is set"}, fmt.Errorf("APP_USER_SECRET_NAME is required when DB_SCHEMA is set")
		}
		if err := setupSchemaAndUser(db, schema, appUserSecretName); err != nil {
			log.Printf("Failed to setup schema and user: %s", err.Error())
			return Response{"Failed to setup schema and user"}, err
		}
	}

	// Step 2: Set search_path to target schema for goose migrations
	if schema != "public" {
		log.Printf("Setting search_path to '%s' for migrations...", schema)
		if _, err := db.Exec(fmt.Sprintf("SET search_path TO %s", schema)); err != nil {
			log.Printf("Failed to set search_path: %s", err.Error())
			return Response{"Failed to set search_path"}, err
		}
	}

	// Step 3: Run goose migrations
	log.Println("Running goose.Up migrations...")
	if err := goose.Up(db, "migrations"); err != nil {
		log.Printf("Migration failed: %s", redactPassword(err.Error()))
		return Response{"Migration failed"}, err
	}

	log.Printf("Migration successful (schema: %s)", schema)
	return Response{fmt.Sprintf("Migration successful (schema: %s)", schema)}, nil
}

// redactPassword redacts the password in a Postgres connection URL for logging
func redactPassword(url string) string {
	return regexp.MustCompile(`:[^:@/]+@`).ReplaceAllString(url, ":[REDACTED]@")
}

func main() {
	lambda.Start(HandleRequest)
}
