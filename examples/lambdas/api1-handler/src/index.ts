/**
 * API 1 Handler - Example User Service
 *
 * This Lambda provides user-related endpoints:
 * - GET /users - List all users
 * - GET /users/{id} - Get user by ID
 * - POST /users - Create a new user
 * - GET /health - Health check
 * - GET /secret - Retrieve secret from AWS Secrets Manager (demo)
 */

import { APIGatewayProxyEvent, APIGatewayProxyResult, Context } from 'aws-lambda';
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

// Initialize Secrets Manager client
const secretsClient = new SecretsManagerClient({});

// Cache for secrets (to avoid repeated API calls within same Lambda instance)
let cachedSecret: { value: string; timestamp: number } | null = null;
const SECRET_CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

// Example in-memory data store (replace with DynamoDB in production)
const users = [
  { id: '1', name: 'John Doe', email: 'john@nhs.uk', role: 'patient' },
  { id: '2', name: 'Jane Smith', email: 'jane@nhs.uk', role: 'patient' },
  { id: '3', name: 'Dr. Brown', email: 'dr.brown@nhs.uk', role: 'doctor' },
];

/**
 * Retrieve secret from AWS Secrets Manager with caching
 */
async function getSecret(secretName: string): Promise<string | null> {
  // Check cache first
  if (cachedSecret && Date.now() - cachedSecret.timestamp < SECRET_CACHE_TTL_MS) {
    console.log('Returning cached secret');
    return cachedSecret.value;
  }

  try {
    console.log(`Fetching secret: ${secretName}`);
    const command = new GetSecretValueCommand({ SecretId: secretName });
    const response = await secretsClient.send(command);

    const secretValue = response.SecretString || '';

    // Cache the secret
    cachedSecret = {
      value: secretValue,
      timestamp: Date.now(),
    };

    return secretValue;
  } catch (error) {
    console.error('Error retrieving secret:', error);
    return null;
  }
}

interface User {
  id: string;
  name: string;
  email: string;
  role: string;
}

// CORS headers for all responses
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
  'Content-Type': 'application/json',
};

function response(statusCode: number, body: unknown): APIGatewayProxyResult {
  return {
    statusCode,
    headers: corsHeaders,
    body: JSON.stringify(body),
  };
}

export async function handler(
  event: APIGatewayProxyEvent,
  context: Context
): Promise<APIGatewayProxyResult> {
  const { httpMethod, pathParameters } = event;

  // Normalize path - CloudFront sends /api1/secret, we need /secret
  // The proxy path contains the full path after stage (e.g., "api1/secret")
  // We need to strip the API prefix (api1 or api2) to get the actual route
  const proxyPath = pathParameters?.proxy || '';
  const pathParts = proxyPath.split('/');
  // Remove the api prefix (first segment) if it matches our api pattern
  const routePath = pathParts.length > 1 && pathParts[0].startsWith('api')
    ? '/' + pathParts.slice(1).join('/')
    : proxyPath ? `/${proxyPath}` : event.path;
  const path = routePath || '/';

  console.log('API1 Handler invoked', {
    eventPath: event.path,
    proxyPath: proxyPath,
    normalizedPath: path,
    method: event.httpMethod,
    requestId: context.awsRequestId,
    environment: process.env.ENVIRONMENT,
  });

  try {
    // Health check endpoint
    if (path === '/health' || path === '/') {
      return response(200, {
        status: 'healthy',
        service: 'api1-user-service',
        environment: process.env.ENVIRONMENT || 'unknown',
        timestamp: new Date().toISOString(),
        version: '1.0.0',
      });
    }

    // Secret retrieval endpoint (demo for Secrets Manager integration)
    if (path === '/secret') {
      const secretName = process.env.SECRET_NAME;
      if (!secretName) {
        return response(400, {
          error: 'SECRET_NAME environment variable not configured',
        });
      }

      const secretValue = await getSecret(secretName);
      if (!secretValue) {
        return response(500, {
          error: 'Failed to retrieve secret',
        });
      }

      // Parse the secret (assuming JSON format)
      try {
        const secretData = JSON.parse(secretValue);
        return response(200, {
          message: 'Secret retrieved successfully',
          // Only return non-sensitive metadata - never expose actual secret values!
          secretKeys: Object.keys(secretData),
          timestamp: new Date().toISOString(),
        });
      } catch {
        return response(200, {
          message: 'Secret retrieved successfully (non-JSON format)',
          secretLength: secretValue.length,
          timestamp: new Date().toISOString(),
        });
      }
    }

    // Users endpoints
    if (path.startsWith('/users')) {
      const userId = pathParameters?.proxy?.replace('users/', '') || pathParameters?.id;

      switch (httpMethod) {
        case 'GET':
          if (userId) {
            // Get user by ID
            const user = users.find(u => u.id === userId);
            if (user) {
              return response(200, { data: user });
            }
            return response(404, { error: 'User not found', id: userId });
          }
          // List all users
          return response(200, {
            data: users,
            count: users.length,
            _links: {
              self: '/users',
              create: { href: '/users', method: 'POST' }
            }
          });

        case 'POST':
          // Create new user
          const body = event.body ? JSON.parse(event.body) : {};
          const newUser: User = {
            id: String(users.length + 1),
            name: body.name || 'New User',
            email: body.email || 'user@nhs.uk',
            role: body.role || 'patient',
          };
          users.push(newUser);
          return response(201, {
            data: newUser,
            message: 'User created successfully'
          });

        default:
          return response(405, { error: 'Method not allowed' });
      }
    }

    // Catch-all for unknown routes
    return response(200, {
      message: 'Welcome to API 1 - User Service',
      environment: process.env.ENVIRONMENT,
      endpoints: [
        { path: '/health', method: 'GET', description: 'Health check' },
        { path: '/secret', method: 'GET', description: 'Retrieve secret metadata (demo)' },
        { path: '/users', method: 'GET', description: 'List all users' },
        { path: '/users/{id}', method: 'GET', description: 'Get user by ID' },
        { path: '/users', method: 'POST', description: 'Create a new user' },
      ],
    });

  } catch (error) {
    console.error('Error processing request:', error);
    return response(500, {
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error',
      requestId: context.awsRequestId,
    });
  }
}
