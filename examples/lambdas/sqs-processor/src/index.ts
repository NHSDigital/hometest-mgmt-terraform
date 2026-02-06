/**
 * SQS Processor Lambda - Event-driven message handler
 *
 * This Lambda is triggered by SQS messages and processes them asynchronously.
 * It demonstrates:
 * - SQS event source mapping
 * - Batch processing with partial failure reporting
 * - Dead letter queue handling
 */

import { SQSEvent, SQSBatchResponse, SQSBatchItemFailure, Context } from 'aws-lambda';

interface MessagePayload {
  type: string;
  data: Record<string, unknown>;
  timestamp?: string;
  correlationId?: string;
}

/**
 * Process a single SQS message
 */
async function processMessage(messageBody: string, messageId: string): Promise<void> {
  console.log(`Processing message ${messageId}`);

  // Parse the message body
  let payload: MessagePayload;
  try {
    payload = JSON.parse(messageBody);
  } catch (error) {
    console.error(`Failed to parse message ${messageId}:`, error);
    throw new Error(`Invalid JSON in message: ${messageId}`);
  }

  // Log message details
  console.log('Message payload:', {
    type: payload.type,
    correlationId: payload.correlationId,
    timestamp: payload.timestamp,
  });

  // Process based on message type
  switch (payload.type) {
    case 'ORDER_CREATED':
      await handleOrderCreated(payload.data);
      break;

    case 'USER_REGISTERED':
      await handleUserRegistered(payload.data);
      break;

    case 'NOTIFICATION':
      await handleNotification(payload.data);
      break;

    case 'TEST_MESSAGE':
      // Simple test message - just log it
      console.log('Test message received:', payload.data);
      break;

    default:
      console.warn(`Unknown message type: ${payload.type}`);
      // Still process successfully to avoid requeuing unknown types
  }
}

/**
 * Handle ORDER_CREATED events
 */
async function handleOrderCreated(data: Record<string, unknown>): Promise<void> {
  console.log('Processing order created event:', data);

  // Simulate async processing (e.g., update analytics, send notifications)
  await simulateProcessing(100);

  console.log('Order processed successfully');
}

/**
 * Handle USER_REGISTERED events
 */
async function handleUserRegistered(data: Record<string, unknown>): Promise<void> {
  console.log('Processing user registration event:', data);

  // Simulate async processing (e.g., send welcome email, create profile)
  await simulateProcessing(150);

  console.log('User registration processed successfully');
}

/**
 * Handle NOTIFICATION events
 */
async function handleNotification(data: Record<string, unknown>): Promise<void> {
  console.log('Processing notification event:', data);

  // Simulate sending notification
  await simulateProcessing(50);

  console.log('Notification sent successfully');
}

/**
 * Simulate async processing
 */
function simulateProcessing(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Main Lambda handler for SQS events
 *
 * Supports partial batch failure reporting - returns list of failed message IDs
 * so only those messages are retried (requires ReportBatchItemFailures in event source)
 */
export async function handler(
  event: SQSEvent,
  context: Context
): Promise<SQSBatchResponse> {
  console.log('SQS Processor invoked', {
    messageCount: event.Records.length,
    requestId: context.awsRequestId,
    environment: process.env.ENVIRONMENT,
  });

  const batchItemFailures: SQSBatchItemFailure[] = [];

  // Process each message in the batch
  for (const record of event.Records) {
    try {
      await processMessage(record.body, record.messageId);
      console.log(`Successfully processed message: ${record.messageId}`);
    } catch (error) {
      console.error(`Failed to process message ${record.messageId}:`, error);

      // Add to failures list for partial batch failure reporting
      batchItemFailures.push({
        itemIdentifier: record.messageId,
      });
    }
  }

  // Log batch results
  const successCount = event.Records.length - batchItemFailures.length;
  console.log(`Batch processing complete: ${successCount}/${event.Records.length} succeeded`);

  // Return partial failures (requires ReportBatchItemFailures in Lambda event source mapping)
  return {
    batchItemFailures,
  };
}
