# API Documentation

## Base URL
```
https://api.modipay.local/v1
```

## Authentication
Gunakan Bearer Token dalam header:
```
Authorization: Bearer {access_token}
```

---

## Authentication Endpoints

### 1. Login
**POST** `/auth/login`

**Request:**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "device_fingerprint": "device_id_123"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "user": {
      "id": "usr_123",
      "email": "user@example.com",
      "name": "John Doe",
      "role": "user"
    }
  }
}
```

---

### 2. Refresh Token
**POST** `/auth/refresh`

**Headers:**
```
Authorization: Bearer {refresh_token}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "access_token": "new_token",
    "refresh_token": "new_refresh_token"
  }
}
```

---

### 3. Logout
**POST** `/auth/logout`

**Response:**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

## Device Management Endpoints

### 1. Verify Device
**POST** `/device/verify`

**Request:**
```json
{
  "device_id": "device_123",
  "device_name": "iPhone 12",
  "model": "iPhone",
  "os_version": "14.0",
  "otp_code": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "device_id": "device_123",
    "is_trusted": true,
    "verified_at": "2026-07-20T10:00:00Z"
  }
}
```

---

### 2. List Trusted Devices
**GET** `/device/list`

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "device_id": "device_123",
      "device_name": "iPhone 12",
      "model": "iPhone",
      "platform": "iOS",
      "is_trusted": true,
      "last_used": "2026-07-20T10:00:00Z",
      "created_at": "2026-07-15T10:00:00Z"
    }
  ]
}
```

---

### 3. Remove Device
**DELETE** `/device/{device_id}`

**Response:**
```json
{
  "success": true,
  "message": "Device removed successfully"
}
```

---

## Security Endpoints

### 1. Submit Location
**POST** `/security/location`

**Request:**
```json
{
  "latitude": -6.2088,
  "longitude": 106.8456,
  "accuracy": 10.0,
  "timestamp": "2026-07-20T10:00:00Z"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "risk_score": 0.2,
    "is_suspicious": false,
    "is_vpn_detected": false
  }
}
```

---

### 2. Get Risk Score
**GET** `/security/risk-score`

**Response:**
```json
{
  "success": true,
  "data": {
    "risk_score": 0.2,
    "risk_level": "low",
    "last_updated": "2026-07-20T10:00:00Z"
  }
}
```

---

## Printer Endpoints

### 1. Register Printer
**POST** `/printer/register`

**Request:**
```json
{
  "device_id": "printer_123",
  "printer_type": "bluetooth",
  "printer_model": "ZJIANG ZJ-58",
  "mac_address": "00:1A:7D:DA:71:13"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "printer_id": "ptr_123",
    "status": "registered"
  }
}
```

---

### 2. Track Print Job
**POST** `/printer/job`

**Request:**
```json
{
  "job_id": "job_123",
  "type": "receipt",
  "status": "completed",
  "timestamp": "2026-07-20T10:00:00Z"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "job_id": "job_123",
    "status": "tracked"
  }
}
```

---

## Transaction Endpoints

### 1. Get Transactions
**GET** `/transactions`

**Query Parameters:**
```
page=1
limit=20
start_date=2026-07-01
end_date=2026-07-31
type=topup,transfer
status=success
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "trx_123",
      "type": "topup",
      "amount": 100000,
      "fee": 1500,
      "commission": 1000,
      "status": "success",
      "timestamp": "2026-07-20T10:00:00Z",
      "customer_name": "John Doe",
      "customer_phone": "081234567890"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 156
  }
}
```

---

### 2. Get Settlement Summary
**GET** `/transactions/settlement`

**Query Parameters:**
```
start_date=2026-07-01
end_date=2026-07-31
```

**Response:**
```json
{
  "success": true,
  "data": {
    "total_transactions": 156,
    "total_amount": 45600000,
    "total_fees": 228000,
    "total_commission": 456000,
    "net_settlement": 45372000,
    "breakdown_by_type": {
      "topup": 45,
      "transfer": 67,
      "ppob": 32,
      "qris": 12
    }
  }
}
```

---

### 3. Export Transactions
**POST** `/transactions/export`

**Request:**
```json
{
  "format": "pdf",
  "start_date": "2026-07-01",
  "end_date": "2026-07-31"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "url": "https://api.modipay.local/exports/transactions_123.pdf",
    "expires_at": "2026-07-21T10:00:00Z"
  }
}
```

---

## App Endpoints

### 1. Check App Version
**GET** `/app/version`

**Response:**
```json
{
  "success": true,
  "data": {
    "latest_version": "2.5.0",
    "minimum_version": "2.0.0",
    "release_notes": "Bug fixes and performance improvements",
    "download_url": "https://...",
    "force_update": false
  }
}
```

---

## Error Handling

### Standard Error Response
```json
{
  "success": false,
  "error": "invalid_credentials",
  "message": "Email or password is incorrect",
  "status_code": 401
}
```

### Validation Error Response
```json
{
  "success": false,
  "error": "validation_failed",
  "message": "Validation failed",
  "errors": {
    "email": ["Email is required"],
    "password": ["Password must be at least 8 characters"]
  },
  "status_code": 422
}
```

### Error Codes
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `422` - Validation Error
- `429` - Too Many Requests
- `500` - Internal Server Error

---

## Rate Limiting

- **Limit:** 1000 requests per hour per IP
- **Headers:**
  ```
  X-RateLimit-Limit: 1000
  X-RateLimit-Remaining: 999
  X-RateLimit-Reset: 1234567890
  ```

---

## Pagination

All list endpoints support pagination:
```
page=1        # Page number (default: 1)
limit=20      # Items per page (default: 20, max: 100)
sort_by=date  # Sort field
sort_order=desc # asc or desc (default: desc)
```

---

## Filtering

### Transaction Filtering
```
type=topup,transfer,ppob,qris
status=success,failed,pending
start_date=2026-07-01
end_date=2026-07-31
search=keyword
```

---

## Response Format

All API responses follow this format:
```json
{
  "success": true/false,
  "data": {...},
  "message": "Optional message",
  "status_code": 200,
  "timestamp": "2026-07-20T10:00:00Z"
}
```

---

## API Integration Examples

### Flutter/Dart
```dart
final apiClient = ApiClient();
await apiClient.initialize();

// Login
final response = await apiClient.post<User>(
  '/auth/login',
  body: {'email': 'user@example.com', 'password': 'password'},
  fromJson: (json) => User.fromJson(json),
);

// Get transactions
final txnResponse = await apiClient.get<List<Transaction>>(
  '/transactions',
  queryParams: {'page': '1', 'limit': '20'},
  fromJson: (json) => (json as List).map((t) => Transaction.fromJson(t)).toList(),
);
```

---

## SDK Libraries

- **Dart/Flutter:** Available via pub.dev
- **JavaScript:** Available via npm
- **Python:** Available via pip

---

## Support

For API support:
- Email: api-support@modipay.local
- Documentation: https://docs.modipay.local
- Status Page: https://status.modipay.local
