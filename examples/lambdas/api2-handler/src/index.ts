/**
 * API 2 Handler - Example Test Orders Service
 *
 * This Lambda provides test order-related endpoints:
 * - GET /orders - List all test orders
 * - GET /orders/{id} - Get order by ID
 * - POST /orders - Create a new test order
 * - GET /health - Health check
 */

import { APIGatewayProxyEvent, APIGatewayProxyResult, Context } from 'aws-lambda';

// Example in-memory data store (replace with DynamoDB in production)
const orders = [
  {
    id: 'ORD-001',
    userId: '1',
    testType: 'COVID-19 PCR',
    status: 'completed',
    createdAt: '2026-02-01T10:00:00Z',
    result: 'negative'
  },
  {
    id: 'ORD-002',
    userId: '2',
    testType: 'Lateral Flow',
    status: 'pending',
    createdAt: '2026-02-05T09:30:00Z',
    result: null
  },
  {
    id: 'ORD-003',
    userId: '1',
    testType: 'Blood Test',
    status: 'in_transit',
    createdAt: '2026-02-04T14:00:00Z',
    result: null
  },
];

interface TestOrder {
  id: string;
  userId: string;
  testType: string;
  status: string;
  createdAt: string;
  result: string | null;
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
  console.log('API2 Handler invoked', {
    path: event.path,
    method: event.httpMethod,
    requestId: context.awsRequestId,
    environment: process.env.ENVIRONMENT,
  });

  const { httpMethod, path, pathParameters, queryStringParameters } = event;

  try {
    // Health check endpoint
    if (path === '/health' || path === '/') {
      return response(200, {
        status: 'healthy',
        service: 'api2-orders-service',
        environment: process.env.ENVIRONMENT || 'unknown',
        timestamp: new Date().toISOString(),
        version: '1.0.0',
      });
    }

    // Orders endpoints
    if (path.startsWith('/orders')) {
      const orderId = pathParameters?.proxy?.replace('orders/', '') || pathParameters?.id;

      switch (httpMethod) {
        case 'GET':
          if (orderId) {
            // Get order by ID
            const order = orders.find(o => o.id === orderId);
            if (order) {
              return response(200, { data: order });
            }
            return response(404, { error: 'Order not found', id: orderId });
          }

          // List orders with optional filtering
          let filteredOrders = [...orders];

          if (queryStringParameters?.userId) {
            filteredOrders = filteredOrders.filter(o => o.userId === queryStringParameters.userId);
          }
          if (queryStringParameters?.status) {
            filteredOrders = filteredOrders.filter(o => o.status === queryStringParameters.status);
          }

          return response(200, {
            data: filteredOrders,
            count: filteredOrders.length,
            filters: queryStringParameters || {},
            _links: {
              self: '/orders',
              create: { href: '/orders', method: 'POST' }
            }
          });

        case 'POST':
          // Create new order
          const body = event.body ? JSON.parse(event.body) : {};
          const newOrder: TestOrder = {
            id: `ORD-${String(orders.length + 1).padStart(3, '0')}`,
            userId: body.userId || '1',
            testType: body.testType || 'COVID-19 PCR',
            status: 'pending',
            createdAt: new Date().toISOString(),
            result: null,
          };
          orders.push(newOrder);
          return response(201, {
            data: newOrder,
            message: 'Order created successfully'
          });

        default:
          return response(405, { error: 'Method not allowed' });
      }
    }

    // Test types endpoint
    if (path === '/test-types') {
      return response(200, {
        data: [
          { id: 'pcr', name: 'COVID-19 PCR', description: 'PCR test for COVID-19' },
          { id: 'lft', name: 'Lateral Flow', description: 'Rapid antigen test' },
          { id: 'blood', name: 'Blood Test', description: 'General blood panel' },
        ]
      });
    }

    // Catch-all for unknown routes
    return response(200, {
      message: 'Welcome to API 2 - Test Orders Service',
      environment: process.env.ENVIRONMENT,
      endpoints: [
        { path: '/health', method: 'GET', description: 'Health check' },
        { path: '/orders', method: 'GET', description: 'List all orders' },
        { path: '/orders/{id}', method: 'GET', description: 'Get order by ID' },
        { path: '/orders', method: 'POST', description: 'Create a new order' },
        { path: '/test-types', method: 'GET', description: 'List available test types' },
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
