/**
 * API 2 Handler - Example Test Orders Service
 *
 * This Lambda provides test order-related endpoints:
 * - GET /orders - List all test orders
 * - GET /orders/{id} - Get order by ID
 * - POST /orders - Create a new test order
 * - POST /queue - Send message to SQS queue
 * - GET /health - Health check
 */

import { APIGatewayProxyEvent, APIGatewayProxyResult, Context } from 'aws-lambda';
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';

// Initialize SQS client
const sqsClient = new SQSClient({});

// Get SQS queue URL from environment
const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL;

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
  const { httpMethod, pathParameters, queryStringParameters } = event;

  // Normalize path - CloudFront sends /api2/orders, we need /orders
  // The proxy path contains the full path after stage (e.g., "api2/orders")
  // We need to strip the API prefix (api1 or api2) to get the actual route
  const proxyPath = pathParameters?.proxy || '';
  const pathParts = proxyPath.split('/');
  // Remove the api prefix (first segment) if it matches our api pattern
  const routePath = pathParts.length > 1 && pathParts[0].startsWith('api')
    ? '/' + pathParts.slice(1).join('/')
    : proxyPath ? `/${proxyPath}` : event.path;
  const path = routePath || '/';

  console.log('API2 Handler invoked', {
    eventPath: event.path,
    proxyPath: proxyPath,
    normalizedPath: path,
    method: event.httpMethod,
    requestId: context.awsRequestId,
    environment: process.env.ENVIRONMENT,
  });

  try {
    // Health check endpoint
    if (path === '/health' || path === '/' || event.path === '/health' || event.path === '/') {
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

    // SQS Queue endpoint - send messages to SQS for processing
    if (path === '/queue' || path.startsWith('/queue')) {
      if (httpMethod === 'POST') {
        if (!SQS_QUEUE_URL) {
          return response(400, {
            error: 'SQS_QUEUE_URL environment variable not configured',
          });
        }

        const body = event.body ? JSON.parse(event.body) : {};
        const messageType = body.type || 'TEST_MESSAGE';
        const payload = body.payload || {};

        try {
          const messageBody = JSON.stringify({
            type: messageType,
            payload: {
              ...payload,
              timestamp: new Date().toISOString(),
              source: 'api2-handler',
            },
          });

          const command = new SendMessageCommand({
            QueueUrl: SQS_QUEUE_URL,
            MessageBody: messageBody,
            MessageAttributes: {
              MessageType: {
                DataType: 'String',
                StringValue: messageType,
              },
            },
          });

          const result = await sqsClient.send(command);

          return response(200, {
            message: 'Message sent to queue successfully',
            messageId: result.MessageId,
            messageType,
            timestamp: new Date().toISOString(),
          });
        } catch (error) {
          console.error('Error sending SQS message:', error);
          return response(500, {
            error: 'Failed to send message to queue',
            message: error instanceof Error ? error.message : 'Unknown error',
          });
        }
      }

      return response(200, {
        message: 'SQS Queue endpoint',
        methods: ['POST'],
        description: 'Send messages to the event queue for processing',
        example: {
          type: 'ORDER_CREATED',
          payload: { orderId: 'ORD-001' },
        },
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
