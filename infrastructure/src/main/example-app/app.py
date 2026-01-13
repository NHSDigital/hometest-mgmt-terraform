"""
Example Lambda Web Application using FastAPI + Mangum

This demonstrates running a web application as a Docker container on AWS Lambda.
Mangum provides the ASGI adapter for API Gateway/Lambda Function URL integration.
"""

import os
import json
from datetime import datetime
from typing import Any

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from mangum import Mangum

# Configuration from environment variables
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
APP_NAME = os.getenv("APP_NAME", "webapp")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

# Initialize FastAPI app
app = FastAPI(
    title=f"{APP_NAME} API",
    description="Example Lambda Web Application",
    version="1.0.0",
    docs_url="/docs" if ENVIRONMENT != "prod" else None,
    redoc_url="/redoc" if ENVIRONMENT != "prod" else None,
)


@app.get("/", response_class=HTMLResponse)
async def root():
    """
    Root endpoint - returns a simple HTML page
    """
    html_content = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>{APP_NAME} - Home</title>
        <style>
            body {{
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
                max-width: 800px;
                margin: 50px auto;
                padding: 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
            }}
            .container {{
                background: white;
                border-radius: 10px;
                padding: 40px;
                box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            }}
            h1 {{
                color: #333;
                margin-bottom: 10px;
            }}
            .status {{
                display: inline-block;
                background: #10b981;
                color: white;
                padding: 5px 15px;
                border-radius: 20px;
                font-size: 14px;
                margin-bottom: 20px;
            }}
            .info {{
                background: #f3f4f6;
                padding: 20px;
                border-radius: 8px;
                margin: 20px 0;
            }}
            .info p {{
                margin: 8px 0;
                color: #666;
            }}
            .endpoints {{
                margin-top: 30px;
            }}
            .endpoints a {{
                display: inline-block;
                background: #667eea;
                color: white;
                padding: 10px 20px;
                border-radius: 5px;
                text-decoration: none;
                margin-right: 10px;
                margin-bottom: 10px;
            }}
            .endpoints a:hover {{
                background: #5a67d8;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 {APP_NAME}</h1>
            <span class="status">Running on Lambda</span>

            <div class="info">
                <p><strong>Environment:</strong> {ENVIRONMENT}</p>
                <p><strong>Timestamp:</strong> {datetime.utcnow().isoformat()}Z</p>
                <p><strong>Runtime:</strong> AWS Lambda (Container)</p>
            </div>

            <div class="endpoints">
                <h3>Available Endpoints:</h3>
                <a href="/health">Health Check</a>
                <a href="/api/info">API Info</a>
                <a href="/docs">API Docs</a>
            </div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)


@app.get("/health")
async def health_check():
    """
    Health check endpoint for monitoring
    """
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "environment": ENVIRONMENT,
        "app_name": APP_NAME,
    }


@app.get("/api/info")
async def api_info(request: Request):
    """
    Returns API and runtime information
    """
    return {
        "app_name": APP_NAME,
        "version": "1.0.0",
        "environment": ENVIRONMENT,
        "runtime": "AWS Lambda (Container)",
        "timestamp": datetime.utcnow().isoformat(),
        "request_info": {
            "method": request.method,
            "path": str(request.url.path),
            "headers": dict(request.headers),
        },
        "lambda_context": {
            "function_name": os.getenv("AWS_LAMBDA_FUNCTION_NAME"),
            "function_version": os.getenv("AWS_LAMBDA_FUNCTION_VERSION"),
            "memory_limit_mb": os.getenv("AWS_LAMBDA_FUNCTION_MEMORY_SIZE"),
            "region": os.getenv("AWS_REGION"),
        },
    }


@app.post("/api/echo")
async def echo(request: Request):
    """
    Echo endpoint - returns the request body
    """
    try:
        body = await request.json()
    except json.JSONDecodeError:
        body = await request.body()
        body = body.decode("utf-8") if body else None

    return {
        "received": body,
        "timestamp": datetime.utcnow().isoformat(),
        "content_type": request.headers.get("content-type"),
    }


@app.get("/api/items/{item_id}")
async def get_item(item_id: int, q: str = None):
    """
    Example parameterized endpoint
    """
    return {
        "item_id": item_id,
        "query": q,
        "message": f"You requested item {item_id}",
    }


# Error handlers
@app.exception_handler(404)
async def not_found_handler(request: Request, exc: Any):
    return JSONResponse(
        status_code=404,
        content={
            "error": "Not Found",
            "path": str(request.url.path),
            "message": "The requested resource was not found",
        },
    )


@app.exception_handler(500)
async def server_error_handler(request: Request, exc: Any):
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal Server Error",
            "message": "An unexpected error occurred",
        },
    )


# Mangum handler for AWS Lambda
handler = Mangum(app, lifespan="off")


# For local development
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
