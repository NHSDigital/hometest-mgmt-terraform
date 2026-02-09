package main

import (
	"context"
	"database/sql"
	"fmt"
	"os"

	_ "github.com/lib/pq"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/pressly/goose/v3"
)

type Event struct {
	DBUrl string `json:"db_url"`
}

type Response struct {
	Message string `json:"message"`
}

func HandleRequest(ctx context.Context, event Event) (Response, error) {
	db, err := sql.Open("postgres", event.DBUrl)
	if err != nil {
		return Response{"Failed to connect to DB"}, err
	}
	defer db.Close()

	if err := goose.Up(db, "migrations"); err != nil {
		return Response{"Migration failed"}, err
	}

	return Response{"Migration successful"}, nil
}

func main() {
	lambda.Start(HandleRequest)
}
