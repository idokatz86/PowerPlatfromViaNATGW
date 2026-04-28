import express from 'express';

const app = express();
const port = process.env.PORT || 3000;

async function fetchText(url) {
  const started = Date.now();
  const response = await fetch(url, {
    headers: {
      'user-agent': 'PowerPlatfromViaNATGW-ContainerApps-Proxy/1.0'
    }
  });
  const body = await response.text();

  return {
    url,
    status: response.status,
    ok: response.ok,
    durationMs: Date.now() - started,
    body: body.trim(),
    headers: Object.fromEntries(response.headers.entries())
  };
}

function normalizeIp(value) {
  const match = String(value || '').match(/(?:::ffff:)?(\d{1,3}(?:\.\d{1,3}){3})/);
  return match ? match[1] : '';
}

function classify(observedIp) {
  const expected = (process.env.EXPECTED_NAT_IPS || '')
    .split(',')
    .map((ip) => ip.trim())
    .filter(Boolean);

  return {
    expectedNatIps: expected,
    observedIp,
    natProof: expected.includes(observedIp)
  };
}

async function proxyIpResponse(target) {
  const result = await fetchText(target);
  const parsedIp = target.includes('api.ipify.org')
    ? normalizeIp(JSON.parse(result.body).ip)
    : normalizeIp(result.body);

  return {
    timestamp: new Date().toISOString(),
    containerAppRevision: process.env.CONTAINER_APP_REVISION || '',
    target,
    ...classify(parsedIp),
    upstream: result
  };
}

app.get('/', (_req, res) => {
  res.type('text/plain').send('PowerPlatfromViaNATGW Container Apps proxy is running.');
});

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/proxy/ipify', async (_req, res, next) => {
  try {
    res.json(await proxyIpResponse('https://api.ipify.org/?format=json'));
  } catch (error) {
    next(error);
  }
});

app.get('/proxy/aws-checkip', async (_req, res, next) => {
  try {
    res.json(await proxyIpResponse('https://checkip.amazonaws.com/'));
  } catch (error) {
    next(error);
  }
});

app.get('/proxy/all', async (_req, res, next) => {
  try {
    const [ipify, awsCheckIp] = await Promise.all([
      proxyIpResponse('https://api.ipify.org/?format=json'),
      proxyIpResponse('https://checkip.amazonaws.com/')
    ]);

    res.json({ timestamp: new Date().toISOString(), ipify, awsCheckIp });
  } catch (error) {
    next(error);
  }
});

app.use((error, _req, res, _next) => {
  res.status(500).json({
    error: error.message,
    timestamp: new Date().toISOString()
  });
});

app.listen(port, () => {
  console.log(`Container Apps proxy listening on ${port}`);
});