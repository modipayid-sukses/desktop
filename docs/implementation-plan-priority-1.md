# Implementation Plan - Priority 1: Security & Core Services

**Status**: Not Started  
**Timeline**: 2-3 weeks  
**Dependencies**: None

---

## Overview

Implement critical security features and core services to ensure application security and maintainability.

---

## 1. Device Verification

**File**: `lib/login/device_verification_screen.dart`

### Requirements
- Device fingerprinting (device ID, model, OS version)
- Trusted device management (add/remove devices)
- OTP verification for new devices
- Device history logging

### Implementation Steps

1. **Create Device Model**
   ```dart
   class DeviceInfo {
     String deviceId;
     String deviceName;
     String model;
     String osVersion;
     DateTime lastUsed;
     bool isTrusted;
   }
   ```

2. **Device Verification Screen**
   - Show device information
   - Request OTP if device not trusted
   - Allow user to trust device
   - Show list of trusted devices

3. **API Integration**
   - `POST /api/device/verify` - Verify device
   - `GET /api/device/list` - Get trusted devices
   - `DELETE /api/device/{id}` - Remove device

4. **Local Storage**
   - Store device fingerprint securely
   - Cache trusted device status

### Acceptance Criteria
- [ ] New device triggers verification flow
- [ ] OTP sent to registered phone/email
- [ ] Successful verification adds device to trusted list
- [ ] User can view and manage trusted devices
- [ ] Device info stored securely (encrypted)

### Testing
- Test on multiple devices (Android/iOS)
- Test device removal flow
- Test OTP expiration
- Security audit for device fingerprinting

---

## 2. Location Security Service

**File**: `lib/services/location_security_service.dart`

### Requirements
- Real-time location tracking for sensitive transactions
- Geofencing for high-value transactions
- Location anomaly detection
- VPN/proxy detection

### Implementation Steps

1. **Create Location Security Service**
   ```dart
   class LocationSecurityService {
     Future<LocationData> getCurrentLocation();
     Future<bool> isLocationSuspicious();
     Future<bool> isVPNDetected();
     Future<bool> validateTransactionLocation(double amount);
   }
   ```

2. **Location Tracking**
   - Request location permission
   - Get GPS coordinates
   - Calculate distance from last known location
   - Detect rapid location changes

3. **Fraud Detection Rules**
   - Flag if location changes > 100km in < 1 hour
   - Block if VPN/proxy detected for transactions > Rp 1M
   - Require additional verification for foreign locations
   - Log location history for audit

4. **API Integration**
   - `POST /api/security/location` - Submit location data
   - `GET /api/security/risk-score` - Get risk assessment

### Acceptance Criteria
- [ ] Location captured before sensitive transactions
- [ ] Suspicious locations trigger additional verification
- [ ] VPN detection working accurately
- [ ] Location history logged for compliance
- [ ] Performance: location check < 2 seconds

### Testing
- Test with mock locations
- Test VPN detection
- Test geofencing boundaries
- Test location permission denial

---

## 3. App Update Service

**File**: `lib/services/app_update_service.dart`

### Requirements
- Check for updates on app launch
- Force update for critical versions
- Optional update notification
- Download and install updates (Android)
- Redirect to store (iOS)

### Implementation Steps

1. **Create Update Service**
   ```dart
   class AppUpdateService {
     Future<UpdateInfo> checkForUpdates();
     Future<bool> isUpdateRequired();
     Future<void> downloadUpdate();
     void showUpdateDialog(UpdateInfo info);
   }
   ```

2. **Version Management**
   - Get current app version
   - Compare with server version
   - Parse version numbers (semver)
   - Determine update type (critical/optional)

3. **Update Dialog UI**
   - Show update available dialog
   - Display release notes
   - Show download progress (Android)
   - Handle user actions (update now/later/skip)

4. **API Integration**
   - `GET /api/app/version` - Get latest version info
   ```json
   {
     "latestVersion": "2.5.0",
     "minimumVersion": "2.0.0",
     "releaseNotes": "Bug fixes and improvements",
     "downloadUrl": "https://...",
     "forceUpdate": false
   }
   ```

5. **Platform Handling**
   - Android: Use `in_app_update` package
   - iOS: Use `url_launcher` to App Store

### Acceptance Criteria
- [ ] Check for updates on app launch
- [ ] Force update blocks app usage if required
- [ ] Optional update can be skipped/postponed
- [ ] Download progress shown (Android)
- [ ] Release notes displayed clearly
- [ ] Update reminder shown after 24 hours if skipped

### Testing
- Test with different version scenarios
- Test force update flow
- Test optional update flow
- Test download failure handling
- Test on both Android and iOS

---

## Dependencies

### Packages Required
```yaml
dependencies:
  device_info_plus: ^10.0.0
  geolocator: ^12.0.0
  permission_handler: ^11.0.0
  package_info_plus: ^8.0.0
  in_app_update: ^4.2.0 # Android only
  url_launcher: ^6.2.0
  encrypt: ^5.0.3 # For secure storage
```

### Permissions Required

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to verify secure transactions</string>
```

---

## Migration Notes

1. **Device Verification**
   - Existing users will be prompted to verify device on next login
   - Grace period: 7 days before enforcement

2. **Location Security**
   - Optional for first 30 days
   - Required for transactions > Rp 5M after 30 days

3. **App Updates**
   - Check backend compatibility before forcing updates
   - Minimum version should support all active API versions

---

## Rollout Strategy

### Week 1: Development
- Day 1-2: Device verification screen
- Day 3-4: Location security service
- Day 5: App update service

### Week 2: Integration & Testing
- Day 1-2: API integration
- Day 3-4: Testing & bug fixes
- Day 5: Security audit

### Week 3: Deployment
- Day 1: Beta release to internal testers
- Day 2-3: Monitor metrics & feedback
- Day 4: Production release (10% rollout)
- Day 5: Full rollout if metrics good

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Device verification completion rate | > 95% |
| False positive location flags | < 1% |
| App update adoption (7 days) | > 80% |
| Fraud incidents reduced | > 30% |
| User complaints | < 0.5% |

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Location permission denied | High | Fallback to IP geolocation |
| False fraud detection | Medium | Manual review process |
| Update download failures | Low | Retry with exponential backoff |
| Device verification lockout | High | Customer support override |

---

## Notes

- All security features must be tested against OWASP Mobile Top 10
- Ensure GDPR compliance for location data storage
- Document all security decisions for audit trail
