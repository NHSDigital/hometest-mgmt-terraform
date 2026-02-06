import { useState, useEffect, useCallback } from 'react';

// API endpoints - these are path-based under the same domain
// CloudFront routes /api1/* to API Gateway 1 and /api2/* to API Gateway 2
const API1_URL = import.meta.env.VITE_API1_URL || '/api1';
const API2_URL = import.meta.env.VITE_API2_URL || '/api2';

interface User {
  id: string;
  name: string;
  email: string;
  role: string;
}

interface Order {
  id: string;
  userId: string;
  testType: string;
  status: string;
  createdAt: string;
  result: string | null;
}

interface HealthStatus {
  status: string;
  service: string;
  environment: string;
  timestamp: string;
  version: string;
}

interface SecretInfo {
  message: string;
  secretKeys?: string[];
  secretLength?: number;
  timestamp: string;
}

interface SqsMessage {
  messageId: string;
  status: string;
  timestamp: string;
}

interface ApiState<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
}

function App() {
  // API 1 state (Users)
  const [api1Health, setApi1Health] = useState<ApiState<HealthStatus>>({ data: null, loading: true, error: null });
  const [users, setUsers] = useState<ApiState<User[]>>({ data: null, loading: false, error: null });

  // API 2 state (Orders)
  const [api2Health, setApi2Health] = useState<ApiState<HealthStatus>>({ data: null, loading: true, error: null });
  const [orders, setOrders] = useState<ApiState<Order[]>>({ data: null, loading: false, error: null });

  // Secrets Manager state
  const [secretInfo, setSecretInfo] = useState<ApiState<SecretInfo>>({ data: null, loading: false, error: null });

  // SQS state
  const [sqsMessages, setSqsMessages] = useState<SqsMessage[]>([]);
  const [sqsSending, setSqsSending] = useState(false);

  // Fetch helper
  const fetchApi = useCallback(async <T,>(url: string): Promise<T> => {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    return response.json();
  }, []);

  // Check API health
  useEffect(() => {
    const checkHealth = async () => {
      // API 1 health
      try {
        const health = await fetchApi<HealthStatus>(`${API1_URL}/health`);
        setApi1Health({ data: health, loading: false, error: null });
      } catch (err) {
        setApi1Health({
          data: null,
          loading: false,
          error: err instanceof Error ? err.message : 'Failed to connect'
        });
      }

      // API 2 health
      try {
        const health = await fetchApi<HealthStatus>(`${API2_URL}/health`);
        setApi2Health({ data: health, loading: false, error: null });
      } catch (err) {
        setApi2Health({
          data: null,
          loading: false,
          error: err instanceof Error ? err.message : 'Failed to connect'
        });
      }
    };

    checkHealth();
    const interval = setInterval(checkHealth, 30000); // Refresh every 30s
    return () => clearInterval(interval);
  }, [fetchApi]);

  // Fetch users from API 1
  const fetchUsers = useCallback(async () => {
    setUsers({ data: null, loading: true, error: null });
    try {
      const response = await fetchApi<{ data: User[] }>(`${API1_URL}/users`);
      setUsers({ data: response.data, loading: false, error: null });
    } catch (err) {
      setUsers({
        data: null,
        loading: false,
        error: err instanceof Error ? err.message : 'Failed to fetch users'
      });
    }
  }, [fetchApi]);

  // Fetch orders from API 2
  const fetchOrders = useCallback(async () => {
    setOrders({ data: null, loading: true, error: null });
    try {
      const response = await fetchApi<{ data: Order[] }>(`${API2_URL}/orders`);
      setOrders({ data: response.data, loading: false, error: null });
    } catch (err) {
      setOrders({
        data: null,
        loading: false,
        error: err instanceof Error ? err.message : 'Failed to fetch orders'
      });
    }
  }, [fetchApi]);

  // Create a new test order
  const createOrder = useCallback(async () => {
    try {
      await fetch(`${API2_URL}/orders`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: '1',
          testType: 'COVID-19 PCR',
        }),
      });
      fetchOrders(); // Refresh the list
    } catch (err) {
      console.error('Failed to create order:', err);
    }
  }, [fetchOrders]);

  // Fetch secret info from API 1
  const fetchSecretInfo = useCallback(async () => {
    setSecretInfo({ data: null, loading: true, error: null });
    try {
      const response = await fetchApi<SecretInfo>(`${API1_URL}/secret`);
      setSecretInfo({ data: response, loading: false, error: null });
    } catch (err) {
      setSecretInfo({
        data: null,
        loading: false,
        error: err instanceof Error ? err.message : 'Failed to fetch secret info'
      });
    }
  }, [fetchApi]);

  // Send test message to SQS (via API 2)
  const sendSqsMessage = useCallback(async (messageType: string) => {
    setSqsSending(true);
    try {
      const response = await fetch(`${API2_URL}/queue`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: messageType,
          payload: {
            testId: `test-${Date.now()}`,
            source: 'spa-demo',
          },
        }),
      });

      if (response.ok) {
        const result = await response.json();
        setSqsMessages(prev => [
          {
            messageId: result.messageId || `msg-${Date.now()}`,
            status: 'sent',
            timestamp: new Date().toISOString(),
          },
          ...prev.slice(0, 9), // Keep last 10 messages
        ]);
      }
    } catch (err) {
      console.error('Failed to send SQS message:', err);
      setSqsMessages(prev => [
        {
          messageId: `error-${Date.now()}`,
          status: 'failed',
          timestamp: new Date().toISOString(),
        },
        ...prev.slice(0, 9),
      ]);
    } finally {
      setSqsSending(false);
    }
  }, []);

  return (
    <>
      {/* Header */}
      <header className="header">
        <h1>🏥 NHS HomeTest Service</h1>
        <p>Example SPA demonstrating multi-API architecture</p>
      </header>

      <div className="app-container">
        {/* Configuration Info */}
        <div className="config-info">
          <strong>Environment Configuration:</strong><br />
          API 1 (Users): <code>{API1_URL}</code><br />
          API 2 (Orders): <code>{API2_URL}</code>
        </div>

        {/* Health Status Grid */}
        <div className="grid grid-2">
          {/* API 1 Health */}
          <div className="card">
            <div className="card-header">API 1 - User Service</div>
            <div className="card-body">
              <div className="health-indicator">
                <span className={`health-dot ${api1Health.loading ? 'loading' : api1Health.data ? 'healthy' : 'unhealthy'}`}></span>
                <span>
                  {api1Health.loading ? 'Checking...' :
                   api1Health.data ? `Healthy (${api1Health.data.environment})` :
                   'Unhealthy'}
                </span>
              </div>
              {api1Health.error && (
                <div className="error-message" style={{ marginTop: '12px' }}>
                  {api1Health.error}
                </div>
              )}
              {api1Health.data && (
                <p style={{ margin: '12px 0 0', fontSize: '14px', color: 'var(--nhs-mid-grey)' }}>
                  Version: {api1Health.data.version}<br />
                  Last check: {new Date(api1Health.data.timestamp).toLocaleTimeString()}
                </p>
              )}
            </div>
          </div>

          {/* API 2 Health */}
          <div className="card">
            <div className="card-header">API 2 - Orders Service</div>
            <div className="card-body">
              <div className="health-indicator">
                <span className={`health-dot ${api2Health.loading ? 'loading' : api2Health.data ? 'healthy' : 'unhealthy'}`}></span>
                <span>
                  {api2Health.loading ? 'Checking...' :
                   api2Health.data ? `Healthy (${api2Health.data.environment})` :
                   'Unhealthy'}
                </span>
              </div>
              {api2Health.error && (
                <div className="error-message" style={{ marginTop: '12px' }}>
                  {api2Health.error}
                </div>
              )}
              {api2Health.data && (
                <p style={{ margin: '12px 0 0', fontSize: '14px', color: 'var(--nhs-mid-grey)' }}>
                  Version: {api2Health.data.version}<br />
                  Last check: {new Date(api2Health.data.timestamp).toLocaleTimeString()}
                </p>
              )}
            </div>
          </div>
        </div>

        {/* Users Section */}
        <div className="card">
          <div className="card-header">
            👥 Users (from API 1)
          </div>
          <div className="card-body">
            <button
              className="btn btn-primary"
              onClick={fetchUsers}
              disabled={users.loading}
              style={{ marginBottom: '16px' }}
            >
              {users.loading ? <><span className="loading-spinner"></span> Loading...</> : 'Fetch Users'}
            </button>

            {users.error && (
              <div className="error-message">{users.error}</div>
            )}

            {users.data && users.data.length > 0 && (
              <table className="table">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Role</th>
                  </tr>
                </thead>
                <tbody>
                  {users.data.map(user => (
                    <tr key={user.id}>
                      <td>{user.id}</td>
                      <td>{user.name}</td>
                      <td>{user.email}</td>
                      <td>{user.role}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>

        {/* Orders Section */}
        <div className="card">
          <div className="card-header">
            📋 Test Orders (from API 2)
          </div>
          <div className="card-body">
            <div style={{ display: 'flex', gap: '12px', marginBottom: '16px' }}>
              <button
                className="btn btn-primary"
                onClick={fetchOrders}
                disabled={orders.loading}
              >
                {orders.loading ? <><span className="loading-spinner"></span> Loading...</> : 'Fetch Orders'}
              </button>
              <button
                className="btn btn-secondary"
                onClick={createOrder}
              >
                + Create Test Order
              </button>
            </div>

            {orders.error && (
              <div className="error-message">{orders.error}</div>
            )}

            {orders.data && orders.data.length > 0 && (
              <table className="table">
                <thead>
                  <tr>
                    <th>Order ID</th>
                    <th>Test Type</th>
                    <th>Status</th>
                    <th>Created</th>
                    <th>Result</th>
                  </tr>
                </thead>
                <tbody>
                  {orders.data.map(order => (
                    <tr key={order.id}>
                      <td>{order.id}</td>
                      <td>{order.testType}</td>
                      <td>
                        <span className={`status status-${order.status}`}>
                          {order.status.replace('_', ' ')}
                        </span>
                      </td>
                      <td>{new Date(order.createdAt).toLocaleDateString()}</td>
                      <td>{order.result || '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>

        {/* New Features Section */}
        <div className="grid grid-2">
          {/* Secrets Manager Demo */}
          <div className="card">
            <div className="card-header">
              🔐 Secrets Manager Demo (API 1)
            </div>
            <div className="card-body">
              <p style={{ marginBottom: '16px', fontSize: '14px', color: 'var(--nhs-mid-grey)' }}>
                Demonstrates secure secret retrieval from AWS Secrets Manager.
                The API returns metadata only - actual secret values are never exposed.
              </p>
              <button
                className="btn btn-primary"
                onClick={fetchSecretInfo}
                disabled={secretInfo.loading}
                style={{ marginBottom: '16px' }}
              >
                {secretInfo.loading ? <><span className="loading-spinner"></span> Loading...</> : '🔑 Fetch Secret Info'}
              </button>

              {secretInfo.error && (
                <div className="error-message">{secretInfo.error}</div>
              )}

              {secretInfo.data && (
                <div style={{
                  background: 'var(--nhs-pale-grey)',
                  padding: '16px',
                  borderRadius: '4px',
                  fontSize: '14px'
                }}>
                  <strong>✅ {secretInfo.data.message}</strong>
                  {secretInfo.data.secretKeys && (
                    <div style={{ marginTop: '12px' }}>
                      <strong>Secret Keys:</strong>
                      <ul style={{ margin: '8px 0 0 20px', padding: 0 }}>
                        {secretInfo.data.secretKeys.map(key => (
                          <li key={key}><code>{key}</code></li>
                        ))}
                      </ul>
                    </div>
                  )}
                  <div style={{ marginTop: '12px', color: 'var(--nhs-mid-grey)' }}>
                    Retrieved: {new Date(secretInfo.data.timestamp).toLocaleString()}
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* SQS Demo */}
          <div className="card">
            <div className="card-header">
              📨 SQS Event Queue Demo (API 2)
            </div>
            <div className="card-body">
              <p style={{ marginBottom: '16px', fontSize: '14px', color: 'var(--nhs-mid-grey)' }}>
                Send messages to SQS queue. Messages are processed by the sqs-processor Lambda.
              </p>
              <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '16px' }}>
                <button
                  className="btn btn-primary"
                  onClick={() => sendSqsMessage('ORDER_CREATED')}
                  disabled={sqsSending}
                >
                  {sqsSending ? <span className="loading-spinner"></span> : '📦'} Order Event
                </button>
                <button
                  className="btn btn-secondary"
                  onClick={() => sendSqsMessage('USER_REGISTERED')}
                  disabled={sqsSending}
                >
                  👤 User Event
                </button>
                <button
                  className="btn btn-secondary"
                  onClick={() => sendSqsMessage('NOTIFICATION')}
                  disabled={sqsSending}
                >
                  🔔 Notification
                </button>
                <button
                  className="btn btn-secondary"
                  onClick={() => sendSqsMessage('TEST_MESSAGE')}
                  disabled={sqsSending}
                >
                  🧪 Test
                </button>
              </div>

              {sqsMessages.length > 0 && (
                <div style={{
                  background: 'var(--nhs-pale-grey)',
                  padding: '12px',
                  borderRadius: '4px',
                  maxHeight: '200px',
                  overflowY: 'auto'
                }}>
                  <strong style={{ fontSize: '14px' }}>Recent Messages:</strong>
                  <ul style={{ margin: '8px 0 0', padding: 0, listStyle: 'none', fontSize: '13px' }}>
                    {sqsMessages.map((msg, idx) => (
                      <li key={idx} style={{
                        padding: '6px 0',
                        borderBottom: idx < sqsMessages.length - 1 ? '1px solid #ddd' : 'none',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center'
                      }}>
                        <code style={{ fontSize: '12px' }}>{msg.messageId.slice(0, 20)}...</code>
                        <span style={{
                          color: msg.status === 'sent' ? 'var(--nhs-green)' : 'var(--nhs-error-colour)',
                          fontWeight: 500
                        }}>
                          {msg.status === 'sent' ? '✓ Sent' : '✗ Failed'}
                        </span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </>
  );
}

export default App;
