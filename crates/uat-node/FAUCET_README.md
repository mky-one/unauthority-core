# Testnet Faucet

Rate-limited faucet for distributing test UAT tokens on testnet.

## Features

- **IP Rate Limiting:** 1 request per hour per IP address
- **Address Rate Limiting:** 1 request per 24 hours per UAT address
- **Global Rate Limiting:** Maximum 100 requests per hour
- **Automatic Cleanup:** Old rate limit entries cleaned up every 7 days
- **Statistics Tracking:** Total requests, successful drips, rejected requests
- **Admin Controls:** Enable/disable faucet, adjust drip amount
- **CAPTCHA Support:** Optional reCAPTCHA/hCaptcha integration

## Configuration

Default configuration in `FaucetConfig`:

```rust
pub struct FaucetConfig {
    drip_amount: 10_000_000_000,      // 100 UAT per request
    ip_cooldown: 3600,                  // 1 hour
    address_cooldown: 86400,            // 24 hours
    max_requests_per_hour: 100,         // Global limit
    min_balance: 100_000_000_000,       // 1000 UAT minimum
    treasury_address: String,           // Treasury for refills
    faucet_address: String,             // Faucet wallet address
    enabled: true,                      // Enabled by default
}
```

## REST API Endpoints

### Request Tokens

**Endpoint:** `POST /faucet`

**Request Body:**
```json
{
  "address": "UAT1abc123...",
  "captcha_token": "optional_captcha_token"
}
```

**Success Response:**
```json
{
  "success": true,
  "message": "Successfully sent 100 UAT to UAT1abc123...",
  "tx_hash": "0xfaucet_tx_1738713600",
  "amount": 10000000000,
  "cooldown_remaining": 86400
}
```

**Error Responses:**

IP Rate Limit:
```json
{
  "success": false,
  "message": "IP rate limit exceeded. Try again in 3542 seconds",
  "tx_hash": null,
  "amount": null,
  "cooldown_remaining": null
}
```

Address Rate Limit:
```json
{
  "success": false,
  "message": "Address rate limit exceeded. Try again in 23 hours",
  "tx_hash": null,
  "amount": null,
  "cooldown_remaining": null
}
```

Global Limit:
```json
{
  "success": false,
  "message": "Faucet is temporarily at capacity. Try again later.",
  "tx_hash": null,
  "amount": null,
  "cooldown_remaining": null
}
```

### Get Faucet Statistics

**Endpoint:** `GET /faucet/stats`

**Response:**
```json
{
  "total_requests": 1247,
  "successful_drips": 1198,
  "rejected_requests": 49,
  "total_distributed_voi": 119800000000000,
  "total_distributed_uat": 1198000,
  "drip_amount_uat": 100,
  "ip_cooldown_seconds": 3600,
  "address_cooldown_hours": 24,
  "enabled": true
}
```

## Usage Examples

### cURL

```bash
# Request tokens
curl -X POST http://localhost:8080/faucet \
  -H "Content-Type: application/json" \
  -d '{
    "address": "UAT1abc123...",
    "captcha_token": null
  }'

# Get stats
curl http://localhost:8080/faucet/stats
```

### JavaScript

```javascript
// Request tokens
async function requestFaucet(address) {
  const response = await fetch('http://localhost:8080/faucet', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      address: address,
      captcha_token: null
    })
  });
  
  const data = await response.json();
  
  if (data.success) {
    console.log(`Received ${data.amount / 100000000} UAT`);
    console.log(`TX Hash: ${data.tx_hash}`);
  } else {
    console.error(`Error: ${data.message}`);
  }
}

// Get statistics
async function getFaucetStats() {
  const response = await fetch('http://localhost:8080/faucet/stats');
  const stats = await response.json();
  console.log(`Total distributed: ${stats.total_distributed_uat} UAT`);
  console.log(`Success rate: ${(stats.successful_drips / stats.total_requests * 100).toFixed(2)}%`);
}
```

### Python

```python
import requests

# Request tokens
def request_faucet(address):
    response = requests.post(
        'http://localhost:8080/faucet',
        json={
            'address': address,
            'captcha_token': None
        }
    )
    
    data = response.json()
    
    if data['success']:
        print(f"Received {data['amount'] / 100000000} UAT")
        print(f"TX Hash: {data['tx_hash']}")
    else:
        print(f"Error: {data['message']}")

# Get statistics
def get_faucet_stats():
    response = requests.get('http://localhost:8080/faucet/stats')
    stats = response.json()
    print(f"Total distributed: {stats['total_distributed_uat']} UAT")
    print(f"Success rate: {stats['successful_drips'] / stats['total_requests'] * 100:.2f}%")
```

## Admin Operations

### Enable/Disable Faucet

```rust
faucet.set_enabled(false); // Disable
faucet.set_enabled(true);  // Enable
```

### Adjust Drip Amount

```rust
// Change to 50 UAT per request
faucet.set_drip_amount(50 * 100_000_000);
```

## Security Considerations

1. **CAPTCHA Integration:** Add reCAPTCHA v3 or hCaptcha to prevent bots
2. **IP Verification:** Use `X-Forwarded-For` header for reverse proxy setups
3. **Treasury Monitoring:** Set up alerts for low faucet balance
4. **Rate Limit Tuning:** Adjust limits based on abuse patterns
5. **Mainnet Disabled:** Never enable on mainnet (DEV_MODE only)

## Monitoring

### Prometheus Metrics

```
uat_faucet_total_requests        # Total faucet requests
uat_faucet_successful_drips      # Successful token distributions
uat_faucet_rejected_requests     # Rejected requests (rate limited)
uat_faucet_total_distributed_voi # Total VOI distributed
uat_faucet_enabled               # Faucet enabled status (0 or 1)
```

### Logs

```bash
# View faucet activity
docker logs -f uat-validator-1 | grep "faucet"

# Monitor rate limit hits
docker logs -f uat-validator-1 | grep "rate limit exceeded"
```

## Troubleshooting

### "Faucet is temporarily out of funds"

Check faucet balance:
```bash
uat-cli balance <FAUCET_ADDRESS>
```

Refill from treasury:
```bash
uat-cli send --from <TREASURY> --to <FAUCET_ADDRESS> --amount 10000
```

### "CAPTCHA verification failed"

Verify CAPTCHA secret key is correct and API endpoint is reachable.

### "IP rate limit exceeded" (too aggressive)

Adjust cooldown in configuration:
```rust
config.ip_cooldown = 1800; // 30 minutes instead of 1 hour
```

## Integration with Frontend

The faucet is automatically integrated with the public wallet frontend:

1. User enters UAT address
2. Solves CAPTCHA (if enabled)
3. Clicks "Request Test Tokens"
4. Receives 100 UAT after rate limit checks

See `frontend-wallet/src/components/Faucet.tsx` for implementation.

## Production Deployment

**IMPORTANT:** Faucet should only be enabled on testnet:

```toml
# validator.toml
[testnet]
faucet_enabled = true
faucet_drip_amount = 10000000000  # 100 UAT
```

On mainnet:
```toml
[mainnet]
faucet_enabled = false  # NEVER enable on mainnet
```

## Testing

Run faucet tests:
```bash
cargo test --package uat-node --lib faucet
```

Test rate limiting:
```bash
# Should succeed
curl -X POST http://localhost:8080/faucet -d '{"address":"UAT1test1..."}'

# Should fail (same IP)
curl -X POST http://localhost:8080/faucet -d '{"address":"UAT1test2..."}'
```

## Resources

- [API Examples](../../api_docs/API_EXAMPLES.md)
- [Testnet Deployment](../../docs/TESTNET_DEPLOYMENT.md)
- [Node Configuration](../../validator.toml)
