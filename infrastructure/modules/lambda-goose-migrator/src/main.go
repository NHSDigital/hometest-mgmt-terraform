package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"regexp"

	_ "github.com/lib/pq"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/pressly/goose/v3"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
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

	return fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable", user, password, host, port, dbname), nil
}

// Response struct
type Response struct {
	Message string `json:"message"`
}

// HandleRequest is the handler function for the Lambda function
func HandleRequest(ctx context.Context) (Response, error) {
	log.Println("Starting Goose migration Lambda handler")
	url, err := buildPostgresURL()
	if err != nil {
		log.Printf("Failed to build DB URL: %v", err)
		return Response{"Failed to build DB URL: " + err.Error()}, err
	}

	// Redact password in log output
	log.Printf("Connecting to DB: %s", redactPassword(url))
	db, err := sql.Open("postgres", url)
	if err != nil {
		log.Printf("Failed to connect to DB: %v", err)
		return Response{"Failed to connect to DB"}, err
	}
	defer db.Close()

	log.Println("Running goose.Up migrations...")
	if err := goose.Up(db, "migrations"); err != nil {
		log.Printf("Migration failed: %v", err)
		return Response{"Migration failed"}, err
	}

	log.Println("Migration successful")
	return Response{"Migration successful"}, nil
}

// redactPassword redacts the password in a Postgres connection URL for logging
func redactPassword(url string) string {
	// Example: postgres://user:password@host:port/db?params
	// Replace :password@ with :[REDACTED]@
	return regexp.MustCompile(`:(.*)@`).ReplaceAllString(url, ":[REDACTED]@")
}

func main() {
	lambda.Start(HandleRequest)
}
