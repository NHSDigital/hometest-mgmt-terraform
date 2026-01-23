# HomeTest Lambda Functions

This directory contains the Lambda function source code for the HomeTest application.

## Structure

```text
lambdas/
├── api/                    # Main API Lambda function
│   ├── index.js           # Handler entry point
│   ├── package.json       # Dependencies
│   └── src/               # Application source code
└── README.md              # This file
```

## Local Development

### Prerequisites

- Node.js >= 20.x
- npm or yarn

### Setup

```bash
cd lambdas/api
npm install
```

### Testing Locally

```bash
# Run unit tests
npm test

# Test handler locally
node -e "require('./index').handler({httpMethod:'GET',path:'/health'},{}).then(console.log)"
```

## Building for Deployment

### Using Make

```bash
# From repository root
make build-lambda       # Build all Lambda functions
make package-lambda     # Package into zip files
make upload-lambda      # Upload to S3
```

### Manual Build

```bash
cd lambdas/api
npm ci --production     # Install production dependencies only
cd ../..
zip -r artifacts/api.zip lambdas/api -x "*.git*" -x "*node_modules/.cache*"
```

## Environment Variables

The Lambda function uses the following environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Environment mode | `production` |
| `LOG_LEVEL` | Logging level | `info` |
| `ENVIRONMENT` | Deployment environment | `dev` |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health`, `/v1/health` | Health check endpoint |
| GET | `/`, `/v1/` | API information |
| GET | `/v1/tests` | List tests |
| POST | `/v1/tests` | Create test |

## Adding New Functions

1. Create a new directory under `lambdas/`:

   ```bash
   mkdir lambdas/worker
   ```

2. Add `package.json` and handler:

   ```bash
   cd lambdas/worker
   npm init -y
   touch index.js
   ```

3. Add Terragrunt configuration (copy from `api` and modify):

   ```bash
   cp -r infrastructure/environments/poc/dev/application \
         infrastructure/environments/poc/dev/worker
   ```

4. Update the new `terragrunt.hcl` with worker-specific settings.
