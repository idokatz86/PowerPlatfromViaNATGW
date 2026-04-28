# MCP Ingress Probe

This small Node.js service helps prove whether a Power Platform custom connector reaches an AWS-hosted MCP ingress endpoint through the expected Azure NAT Gateway public IP.

Deploy it temporarily beside the real MCP service or behind the same AWS ingress layer.

## Endpoints

| Endpoint | Purpose |
| --- | --- |
| `GET /health` | Health check |
| `GET /inspect?run=<id>` | Echo request source IP and headers |
| `POST /mcp` | Minimal JSON-RPC-style diagnostic response |

## What To Check

The response should show the NAT Gateway public IP as the source observed by the AWS ingress path.

For the current demo, expected values are:

```text
20.166.89.8  # proven North Europe path
51.124.38.135 # configured West Europe paired path, not yet observed
```

## Example MCP Probe Request

```json
{
  "jsonrpc": "2.0",
  "id": "probe-001",
  "method": "tools/list",
  "params": {}
}
```

The probe responds with the request source metadata under `result.source`.