/**
 * HomeTest API Lambda Handler
 *
 * This is a sample Lambda function for the HomeTest API.
 * Replace this with your actual application code.
 */

'use strict';

/**
 * Main Lambda handler
 * @param {Object} event - API Gateway event
 * @param {Object} context - Lambda context
 * @returns {Object} - API Gateway response
 */
exports.handler = async (event, context) => {
  console.log('Event:', JSON.stringify(event, null, 2));
  console.log('Context:', JSON.stringify(context, null, 2));

  const { httpMethod, path, pathParameters, queryStringParameters, body } = event;

  try {
    // Health check endpoint
    if (path === '/health' || path === '/v1/health') {
      return buildResponse(200, {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        version: process.env.npm_package_version || '1.0.0',
        environment: process.env.ENVIRONMENT || 'unknown'
      });
    }

    // Root endpoint
    if (path === '/' || path === '/v1' || path === '/v1/') {
      return buildResponse(200, {
        message: 'Welcome to HomeTest API',
        version: 'v1',
        environment: process.env.ENVIRONMENT || 'unknown',
        endpoints: {
          health: '/v1/health',
          // Add your API endpoints here
        }
      });
    }

    // Example: Handle a specific resource
    if (path.startsWith('/v1/tests')) {
      return handleTestsEndpoint(httpMethod, pathParameters, queryStringParameters, body);
    }

    // 404 for unknown paths
    return buildResponse(404, {
      error: 'Not Found',
      message: `Path ${path} not found`,
      requestId: context.awsRequestId
    });

  } catch (error) {
    console.error('Error:', error);
    return buildResponse(500, {
      error: 'Internal Server Error',
      message: process.env.NODE_ENV === 'development' ? error.message : 'An unexpected error occurred',
      requestId: context.awsRequestId
    });
  }
};

/**
 * Handle /v1/tests endpoint
 */
function handleTestsEndpoint(httpMethod, pathParameters, queryStringParameters, body) {
  switch (httpMethod) {
    case 'GET':
      return buildResponse(200, {
        tests: [
          { id: '1', name: 'Sample Test 1', status: 'active' },
          { id: '2', name: 'Sample Test 2', status: 'pending' }
        ],
        count: 2
      });

    case 'POST':
      const parsed = body ? JSON.parse(body) : {};
      return buildResponse(201, {
        message: 'Test created',
        test: {
          id: Date.now().toString(),
          ...parsed,
          createdAt: new Date().toISOString()
        }
      });

    default:
      return buildResponse(405, {
        error: 'Method Not Allowed',
        message: `Method ${httpMethod} not allowed on this endpoint`
      });
  }
}

/**
 * Build API Gateway response
 * @param {number} statusCode - HTTP status code
 * @param {Object} body - Response body
 * @returns {Object} - API Gateway response object
 */
function buildResponse(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'X-Request-Id': body.requestId || 'unknown',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key',
      'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    },
    body: JSON.stringify(body, null, 2)
  };
}
