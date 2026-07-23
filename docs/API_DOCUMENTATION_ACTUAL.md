# API Documentation - Modiappsdesktop Integration

> Updated to match actual modiback API endpoints

## Base URL
```
https://api.modipay.local/v1
```

## Authentication

### Login Methods

#### 1. Send OTP
**POST** `/send-otp`
- Rate limit: 5 requests per minute
- No authentication required

**Request:**
```json
{
  "phone": "081234567890"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "pending_token": "token_123",
    "otp_sent_at": "2026-07-20T11:00:00Z",
    "expires_in": 300
  }
}
```

---

#### 2. Verify OTP
**POST** `/verify-otp`
- Rate limit: 10 requests per minute

**Request:**
```json
{
  "pending_token": "token_123",
  "otp_code": "123456"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "access_token": "token_...",
    "refresh_token": "token_...",
    "user": {
      "id": "usr_123",
      "phone": "081234567890",
      "name": "John Doe"
    }
  }
}
```

---

#### 3. Login with Email/Password
**POST** `/login`
- Rate limit: 10 requests per minute

**Request:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

---

#### 4. Login with PIN
**POST** `/login-pin`
- Rate limit: 10 requests per minute

**Request:**
```json
{
  "phone": "081234567890",
  "pin": "123456"
}
```

---

#### 5. Device Verification
**GET** `/device-verification/{pendingToken}/status`
- Rate limit: 60 requests per minute
- Public endpoint - app polls after login

**Response:**
```json
{
  "status": "success",
  "data": {
    "verified": true,
    "device_id": "device_123",
    "access_token": "token_..."
  }
}
```

---

#### 6. Logout
**POST** `/logout`
- Requires authentication
- Requires device binding

---

#### 7. Unlink Device
**POST** `/unlink-device`
- Requires authentication
- Requires device binding

---

## Profile Endpoints

### Get Profile
**GET** `/profile`
- Requires authentication

**Response:**
```json
{
  "status": "success",
  "data": {
    "id": "usr_123",
    "phone": "081234567890",
    "email": "user@example.com",
    "name": "John Doe",
    "avatar": "url...",
    "kyc_status": "verified",
    "level": "premium"
  }
}
```

---

### Update Profile
**POST/PUT** `/profile`
- Requires authentication

**Request:**
```json
{
  "name": "John Doe",
  "email": "user@example.com"
}
```

---

### Upload Avatar
**POST** `/profile/avatar`
- Requires authentication
- Content-Type: multipart/form-data

---

### Change Password
**POST** `/profile/change-password`
- Requires authentication

**Request:**
```json
{
  "current_password": "old_pass",
  "new_password": "new_pass"
}
```

---

### Receipt Settings
**GET/PUT** `/profile/receipt-settings`
- Requires authentication

---

### KYC Upload
**POST** `/profile/kyc`
- Requires authentication

**Request:**
```json
{
  "kyc_type": "ktp",
  "documents": ["file1", "file2"]
}
```

---

### KYC Status
**GET** `/profile/kyc-status`
- Requires authentication

---

## Transaction Endpoints

### Get Transactions
**GET** `/transactions`
- Requires authentication

**Query Parameters:**
```
page=1
per_page=20
type=topup,transfer,ppob
status=success,pending
start_date=2026-07-01
end_date=2026-07-31
```

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": "trx_123",
      "type": "topup",
      "amount": 100000,
      "fee": 1500,
      "status": "success",
      "created_at": "2026-07-20T10:00:00Z"
    }
  ],
  "meta": {
    "total": 156,
    "per_page": 20,
    "current_page": 1,
    "last_page": 8
  }
}
```

---

### Get Transaction Details
**GET** `/transactions/{id}`
- Requires authentication

---

### Update Transaction Note
**PUT** `/transactions/{id}/note`
- Requires authentication

**Request:**
```json
{
  "note": "Transaction note"
}
```

---

## Transfer Endpoints

### Get Transfers
**GET** `/transfers`
- Requires authentication

---

### Search User
**GET/POST** `/transfers/search-user`
- Requires authentication

**Request:**
```json
{
  "query": "081234567890"
}
```

---

### Create Transfer
**POST** `/transfers`
- Requires authentication
- Rate limit: 10 requests per minute

**Request:**
```json
{
  "recipient_phone": "081234567890",
  "amount": 100000,
  "note": "Transfer note",
  "pin": "123456"
}
```

---

## Bank Transfer Endpoints

### Get Banks
**GET** `/bank-transfers/banks`
- Requires authentication

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "code": "bca",
      "name": "Bank Central Asia",
      "icon": "url..."
    }
  ]
}
```

---

### Bank Transfer Inquiry
**POST** `/bank-transfers/inquiry`
- Requires authentication

**Request:**
```json
{
  "bank_code": "bca",
  "account_number": "1234567890"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "account_name": "John Doe",
    "bank_code": "bca",
    "account_number": "1234567890"
  }
}
```

---

### Bank Transfer Payment
**POST** `/bank-transfers/payment`
- Requires authentication
- Rate limit: 10 requests per minute

**Request:**
```json
{
  "bank_code": "bca",
  "account_number": "1234567890",
  "account_name": "John Doe",
  "amount": 100000,
  "note": "Transfer note",
  "pin": "123456"
}
```

---

### Create Bank Transfer
**POST** `/bank-transfers`
- Requires authentication
- Rate limit: 10 requests per minute

---

## Top Up Endpoints

### Get Top Ups
**GET** `/topups`
- Requires authentication

---

### Create Top Up
**POST** `/topups`
- Requires authentication
- Rate limit: 10 requests per minute

**Request:**
```json
{
  "provider": "telkomsel",
  "phone": "081234567890",
  "amount": 50000,
  "pin": "123456"
}
```

---

### Check Top Up Status
**GET** `/topups/{id}/status`
- Requires authentication

---

### Get Top Up Details
**GET** `/topups/{id}`
- Requires authentication

---

## PPOB Endpoints

### Get PPOB Menu (Categories)
**GET** `/ppob/menu`
- Public endpoint

**Response:**
```json
{
  "status": "success",
  "version": 2,
  "data": {
    "pembelian": [...],
    "pembayaran": [...],
    "keuangan": [...],
    "topup_game": [...],
    "lainnya": [...]
  }
}
```

---

### Get PPOB Categories
**GET** `/ppob/categories`
- Public endpoint

---

### Get PPOB Brands
**GET** `/ppob/brands`
- Public endpoint

---

### Get PPOB Products
**GET** `/ppob/products`
- Requires authentication

---

### PPOB Inquiry
**POST** `/ppob/inquiry`
- Requires authentication

**Request:**
```json
{
  "product_code": "pln_postpaid",
  "customer_number": "123456789"
}
```

---

### PPOB Purchase
**POST** `/ppob/purchase`
- Requires authentication
- Rate limit: 10 requests per minute

**Request:**
```json
{
  "product_code": "pln_postpaid",
  "customer_number": "123456789",
  "amount": 100000,
  "pin": "123456"
}
```

---

### Check Game Username
**POST** `/ppob/check-game-username`
- Requires authentication

---

### PPOB Loket Bayar - BPJS Inquiry
**POST** `/loketbayar/bpjs/inquiry`
- Requires authentication

**Request:**
```json
{
  "customer_number": "0000123456789012"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "customer_name": "John Doe",
    "admin_fee": 2500,
    "total_amount": 102500
  }
}
```

---

### PPOB Loket Bayar - PDAM Inquiry
**POST** `/loketbayar/pdam/inquiry`
- Requires authentication

---

### PPOB Loket Bayar - Purchase
**POST** `/loketbayar/purchase`
- Requires authentication
- Rate limit: 10 requests per minute

---

## Contact Endpoints

### Get Contacts
**GET** `/contacts`
- Requires authentication

---

### Search User
**GET** `/contacts/search-user`
- Requires authentication

---

### Add Contact
**POST** `/contacts`
- Requires authentication

**Request:**
```json
{
  "phone": "081234567890",
  "name": "Contact Name"
}
```

---

### Delete Contact
**DELETE** `/contacts/{id}`
- Requires authentication

---

### Toggle Favorite
**PATCH** `/contacts/{id}/favorite`
- Requires authentication

---

## Saved Customers Endpoints

### Get Saved Customers
**GET** `/ppob/saved-customers`
- Requires authentication

---

### Add Saved Customer
**POST** `/ppob/saved-customers`
- Requires authentication

**Request:**
```json
{
  "customer_number": "123456789",
  "customer_name": "Customer Name",
  "product_code": "pln_postpaid"
}
```

---

### Delete Saved Customer
**DELETE** `/ppob/saved-customers/{id}`
- Requires authentication

---

## Notification Endpoints

### Get Notifications
**GET** `/notifications`
- Requires authentication

---

### Update FCM Token
**POST** `/notifications/fcm-token`
- Requires authentication

**Request:**
```json
{
  "fcm_token": "token_..."
}
```

---

### Mark as Read
**POST/PATCH** `/notifications/{id}/read`
- Requires authentication

---

## PIN Management

### Set PIN
**POST** `/set-pin`
- Requires authentication

**Request:**
```json
{
  "pin": "123456"
}
```

---

### Change PIN
**POST** `/change-pin`
- Requires authentication
- Rate limit: 10 requests per minute

**Request:**
```json
{
  "current_pin": "123456",
  "new_pin": "654321"
}
```

---

### Toggle PIN Required
**POST** `/toggle-pin-required`
- Requires authentication

**Request:**
```json
{
  "pin_required": true
}
```

---

## Error Handling

### Standard Error Response
```json
{
  "status": "error",
  "message": "Error message",
  "errors": {
    "field": ["Error detail"]
  }
}
```

### HTTP Status Codes
- `200` - OK
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden (device not bound)
- `404` - Not Found
- `422` - Validation Error
- `429` - Too Many Requests (rate limited)
- `500` - Internal Server Error

---

## Rate Limiting

- `/send-otp`: 5 requests per minute
- `/verify-otp`: 10 requests per minute
- `/login`: 10 requests per minute
- `/change-pin`: 10 requests per minute
- `/transfers`: 10 requests per minute
- `/bank-transfers/payment`: 10 requests per minute
- `/topups`: 10 requests per minute
- `/ppob/purchase`: 10 requests per minute
- `/loketbayar/purchase`: 10 requests per minute

---

## Authentication

All protected endpoints require:
1. **Bearer Token** in Authorization header
2. **Device Binding** - device must be verified

```
Authorization: Bearer {access_token}
```

---

## Middleware Requirements

- `auth:sanctum` - Authentication required
- `device.bound` - Device verification required
- `throttle:X,Y` - Rate limiting (X requests per Y minute)
- `limit.guard` - Transaction limit guard
- `admin` - Admin-only access

---

## Response Pagination

List endpoints return paginated responses:

```json
{
  "status": "success",
  "data": [...],
  "meta": {
    "current_page": 1,
    "per_page": 20,
    "total": 156,
    "last_page": 8
  }
}
```

---

## Public Endpoints (No Auth)

- `GET /app-config`
- `POST /send-otp`
- `POST /verify-otp`
- `POST /login`
- `POST /login-pin`
- `POST /register`
- `GET /device-verification/{pendingToken}/status`
- `GET /register-verification/{pendingToken}/status`
- `POST /register-verification/{pendingToken}/verify-otp`
- `POST /auth/forgot-pin/check-phone`
- `POST /auth/forgot-pin/send-otp`
- `POST /auth/forgot-pin/verify-otp`
- `POST /auth/forgot-pin/reset`
- `GET /services`
- `GET /banners`
- `GET /ppob/menu`
- `GET /ppob/categories`
- `GET /ppob/brands`

---

## Integration Notes for Frontend

### Device Binding Flow
1. User logs in with OTP/PIN
2. Device verification is required (middleware: `device.bound`)
3. All subsequent requests must be from the verified device

### Token Management
- Access tokens are short-lived
- Implement refresh token flow for token renewal
- Store tokens securely in encrypted SharedPreferences

### Rate Limiting
- Implement exponential backoff for rate-limited endpoints
- Cache responses when possible
- Show user-friendly error messages for rate limit errors

### Error Handling
- Handle 401 Unauthorized (token expired/invalid)
- Handle 403 Forbidden (device not bound)
- Handle 422 Validation errors with field-specific messages
- Handle 429 Too Many Requests with retry-after header

---

## API Support

For issues or questions:
- Documentation: https://docs.modipay.local
- Support Email: api-support@modipay.local
- Status Page: https://status.modipay.local
