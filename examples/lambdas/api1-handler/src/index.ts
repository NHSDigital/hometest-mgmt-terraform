/**
 * API 1 Handler - Example User Service
 *
 * This Lambda provides user-related endpoints:
 * - GET /users - List all users
 * - GET /users/{id} - Get user by ID
 * - POST /users - Create a new user
 * - GET /health - Health check
 */

import { APIGatewayProxyEvent, APIGatewayProxyResult, Context } from 'aws-lambda';

// Example in-memory data store (replace with DynamoDB in production)
const users = [
  { id: '1', name: 'John Doe', email: 'john@nhs.uk', role: 'patient' },
  { id: '2', name: 'Jane Smith', email: 'jane@nhs.uk', role: 'patient' },
  { id: '3', name: 'Dr. Brown', email: 'dr.brown@nhs.uk', role: 'doctor' },
];

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
  console.log('API1 Handler invoked', {
    path: event.path,
    method: event.httpMethod,
    requestId: context.awsRequestId,
    environment: process.env.ENVIRONMENT,
  });

  const { httpMethod, path, pathParameters } = event;

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
