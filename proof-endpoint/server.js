const express = require('express');

const app = express();
app.set('trust proxy', true);

function requestSnapshot(req) {
  const forwardedFor = req.get('x-forwarded-for') || '';
  const rawClientIp = forwardedFor.split(',')[0].trim() || req.ip || req.socket.remoteAddress || '';
  const clientIp = rawClientIp.replace(/^::ffff:/, '').replace(/:\d+$/, '');

  return {
    timestamp: new Date().toISOString(),
    observedClientIp: clientIp,
    rawObservedClientIp: rawClientIp,
    xForwardedFor: forwardedFor,
    xAzureClientIp: req.get('x-azure-clientip') || '',
    userAgent: req.get('user-agent') || '',
    method: req.method,
    path: req.originalUrl,
    query: req.query,
    headers: req.headers,
  };
}

app.use(express.json({ limit: '1mb' }));

app.all('/inspect', (req, res) => {
  const snapshot = requestSnapshot(req);
  console.log(JSON.stringify(snapshot));
  res.json(snapshot);
});

app.get('/', (_req, res) => {
  res.type('text/plain').send('PowerPlatformViaNATGW proof endpoint. Call /inspect?run=<id>.');
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`Proof endpoint listening on ${port}`);
});
