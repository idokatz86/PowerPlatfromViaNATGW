const express = require('express');

const app = express();
app.set('trust proxy', true);
app.use(express.json({ limit: '1mb' }));

function normalizeIp(value) {
  return (value || '').replace(/^::ffff:/, '').replace(/:\d+$/, '');
}

function firstForwardedFor(req) {
  return (req.get('x-forwarded-for') || '').split(',')[0].trim();
}

function sourceSnapshot(req) {
  const awsSourceIp = req.get('x-forwarded-for') || req.get('x-real-ip') || req.ip || req.socket.remoteAddress || '';
  const rawClientIp = req.get('client-ip') || firstForwardedFor(req) || req.ip || req.socket.remoteAddress || '';

  return {
    timestamp: new Date().toISOString(),
    observedClientIp: normalizeIp(rawClientIp),
    rawObservedClientIp: rawClientIp,
    xForwardedFor: req.get('x-forwarded-for') || '',
    xRealIp: req.get('x-real-ip') || '',
    xAmznTraceId: req.get('x-amzn-trace-id') || '',
    awsSourceIp,
    method: req.method,
    path: req.originalUrl,
    query: req.query,
    headers: req.headers,
  };
}

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'mcp-ingress-probe', timestamp: new Date().toISOString() });
});

app.all('/inspect', (req, res) => {
  const snapshot = sourceSnapshot(req);
  console.log(JSON.stringify(snapshot));
  res.json(snapshot);
});

app.post('/mcp', (req, res) => {
  const snapshot = sourceSnapshot(req);
  console.log(JSON.stringify({ type: 'mcp-probe', snapshot, body: req.body }));
  res.json({
    jsonrpc: '2.0',
    id: req.body && req.body.id ? req.body.id : 'probe',
    result: {
      service: 'mcp-ingress-probe',
      message: 'MCP ingress probe reached successfully.',
      source: snapshot,
    },
  });
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`MCP ingress probe listening on ${port}`);
});