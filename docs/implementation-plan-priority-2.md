# Implementation Plan - Priority 2: Business Operations

**Status**: Not Started  
**Timeline**: 3-4 weeks  
**Dependencies**: Priority 1 (Security features)

---

## Overview

Implement critical business operations features for merchant and agent management, focusing on printer integration and transaction tracking.

---

## 1. Printer Management & Service

### Files
- `lib/services/printer_service.dart`
- `lib/providers/printer_provider.dart`
- `lib/profile/printer_management_screen.dart`

### Requirements
- Support multiple printer types (Bluetooth, USB, Network)
- Receipt template management
- Print queue management
- Printer health monitoring
- Offline printing capability

### Implementation Steps

#### 1.1 Printer Service

**File**: `lib/services/printer_service.dart`

```dart
class PrinterService {
  // Printer discovery
  Future<List<Printer>> discoverPrinters(PrinterType type);
  
  // Connection management
  Future<bool> connectToPrinter(String printerId);
  Future<void> disconnectPrinter(String printerId);
  
  // Print operations
  Future<PrintResult> printReceipt(ReceiptData data);
  Future<PrintResult> printReport(ReportData data);
  
  // Queue management
  Future<void> addToQueue(PrintJob job);
  Future<List<PrintJob>> getPendingJobs();
  Future<void> retryFailedJobs();
  
  // Printer status
  Future<PrinterStatus> checkPrinterStatus(String printerId);
  Stream<PrinterStatus> monitorPrinterHealth();
}
```

**Supported Printer Types**:
- Bluetooth thermal printers (58mm, 80mm)
- USB thermal printers
- Network printers (ESC/POS)

**Print Templates**:
```dart
enum ReceiptTemplate {
  transaction,      // Standard transaction receipt
  topup,           // Top-up receipt
  transfer,        // Transfer receipt
  ppob,            // PPOB payment receipt
  settlement,      // End-of-day settlement
  report,          // Transaction report
}
```

#### 1.2 Printer Provider

**File**: `lib/providers/printer_provider.dart`

```dart
class PrinterProvider extends ChangeNotifier {
  List<Printer> _availablePrinters = [];
  Printer? _selectedPrinter;
  List<PrintJob> _printQueue = [];
  PrinterStatus _status = PrinterStatus.disconnected;
  
  // Getters
  List<Printer> get availablePrinters => _availablePrinters;
  Printer? get selectedPrinter => _selectedPrinter;
  bool get isConnected => _status == PrinterStatus.connected;
  
  // Methods
  Future<void> scanForPrinters();
  Future<void> selectPrinter(Printer printer);
  Future<void> printReceipt(ReceiptData data);
  Future<void> savePrinterPreferences();
  void clearPrintQueue();
}
```

#### 1.3 Printer Management Screen

**File**: `lib/profile/printer_management_screen.dart`

**UI Components**:

1. **Printer Discovery Section**
   - Scan button with loading indicator
   - List of discovered printers
   - Signal strength indicator (Bluetooth)
   - Connection status badge

2. **Connected Printer Section**
   - Printer name and model
   - Connection type (Bluetooth/USB/Network)
   - Paper status indicator
   - Battery level (if applicable)
   - Test print button

3. **Print Queue Section**
   - Pending jobs count
   - Failed jobs with retry option
   - Clear queue button
   - Job details (date, type, status)

4. **Settings Section**
   - Default printer selection
   - Auto-reconnect toggle
   - Paper size selection (58mm/80mm)
   - Print density adjustment
   - Header/footer customization

**Screen Flow**:
```
[Scan for Printers]
       ↓
[Select Printer] → [Connect]
       ↓
[Test Print] → Success/Failure
       ↓
[Save as Default]
```

### API Integration

```dart
// Printer registration
POST /api/printer/register
{
  "deviceId": "string",
  "printerType": "bluetooth|usb|network",
  "printerModel": "string",
  "macAddress": "string"
}

// Print job tracking
POST /api/printer/job
{
  "jobId": "string",
  "type": "receipt|report",
  "status": "pending|completed|failed",
  "timestamp": "ISO8601"
}

// Get printer settings
GET /api/printer/settings/{userId}
```

### Acceptance Criteria
- [ ] Successfully discover printers (Bluetooth, USB, Network)
- [ ] Connect to printer with <3 second delay
- [ ] Print receipt with correct formatting
- [ ] Handle print failures gracefully
- [ ] Queue prints when printer offline
- [ ] Auto-reconnect when printer available
- [ ] Save printer preferences persistently
- [ ] Test print works correctly
- [ ] Print queue shows pending/failed jobs
- [ ] Support multiple receipt templates

### Testing
- Test with 3+ printer models (Bluetooth, USB)
- Test print queue with 10+ jobs
- Test offline printing and auto-retry
- Test printer disconnection during print
- Test battery low scenarios
- Test paper jam detection
- Load test: 100 consecutive prints

---

## 2. Agent Transactions Screen

**File**: `lib/profile/agent_transactions_screen.dart`

### Requirements
- View all agent transactions
- Filter by date, type, status
- Transaction details with receipt reprint
- Export transactions (CSV, PDF)
- Settlement summary
- Commission tracking

### Implementation Steps

#### 2.1 Transaction List View

**UI Components**:

1. **Header Section**
   - Date range picker
   - Filter chips (All, Success, Failed, Pending)
   - Search bar (customer name, transaction ID)
   - Export button

2. **Summary Cards**
   ```dart
   Row(
     children: [
       SummaryCard(
         title: "Total Transactions",
         value: "1,234",
         icon: Icons.receipt,
       ),
       SummaryCard(
         title: "Total Amount",
         value: "Rp 45.6M",
         icon: Icons.payments,
       ),
       SummaryCard(
         title: "Commission",
         value: "Rp 456K",
         icon: Icons.account_balance_wallet,
       ),
     ],
   )
   ```

3. **Transaction List**
   - Grouped by date
   - Transaction card with:
     - Transaction type icon
     - Customer name/number
     - Amount
     - Status badge
     - Timestamp
     - Tap to view details

4. **Transaction Detail Modal**
   - Full transaction details
   - Customer information
   - Payment method
   - Fee breakdown
   - Commission amount
   - Status timeline
   - Reprint receipt button
   - Share receipt button

#### 2.2 Filter & Search

```dart
class TransactionFilter {
  DateTimeRange? dateRange;
  List<TransactionType> types;
  List<TransactionStatus> statuses;
  String? searchQuery;
  
  bool matches(AgentTransaction transaction) {
    // Filter logic
  }
}
```

**Filter Options**:
- Date: Today, This Week, This Month, Custom
- Type: All, Top-up, Transfer, PPOB, QRIS
- Status: All, Success, Failed, Pending, Refunded

#### 2.3 Export Functionality

```dart
class TransactionExporter {
  Future<File> exportToCSV(List<AgentTransaction> transactions);
  Future<File> exportToPDF(List<AgentTransaction> transactions);
  Future<void> shareFile(File file);
}
```

**CSV Format**:
```csv
Date,Transaction ID,Type,Customer,Amount,Fee,Commission,Status
2026-07-19,TRX123456,Top-up,081234567890,100000,1500,1000,Success
```

**PDF Format**:
- Header: Agent name, period
- Table: All transactions
- Footer: Total summary

#### 2.4 Settlement Summary

```dart
class SettlementSummary {
  DateTime settlementDate;
  int totalTransactions;
  double totalAmount;
  double totalFees;
  double totalCommission;
  double netSettlement;
  Map<TransactionType, int> breakdownByType;
}
```

**Settlement Report**:
- Daily, Weekly, Monthly views
- Transaction breakdown by type
- Commission calculation details
- Outstanding balance
- Settlement history

### API Integration

```dart
// Get agent transactions
GET /api/agent/transactions
Query params:
  - startDate: ISO8601
  - endDate: ISO8601
  - type: string
  - status: string
  - page: int
  - limit: int

Response:
{
  "transactions": [...],
  "summary": {
    "totalTransactions": 100,
    "totalAmount": 10000000,
    "totalCommission": 50000
  },
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100
  }
}

// Get settlement summary
GET /api/agent/settlement
Query params:
  - startDate: ISO8601
  - endDate: ISO8601

// Export transactions
POST /api/agent/transactions/export
Body:
{
  "format": "csv|pdf",
  "startDate": "ISO8601",
  "endDate": "ISO8601"
}
```

### Acceptance Criteria
- [ ] Load transactions with pagination
- [ ] Filter by date range works correctly
- [ ] Filter by type and status works
- [ ] Search finds transactions by ID/customer
- [ ] Transaction details show all info
- [ ] Reprint receipt works
- [ ] Export to CSV works
- [ ] Export to PDF works
- [ ] Settlement summary accurate
- [ ] Commission calculation correct
- [ ] Performance: Load 100 transactions in <2s

### Testing
- Test with 1000+ transactions
- Test date range edge cases
- Test search functionality
- Test export with large datasets
- Test commission calculation accuracy
- Test settlement report generation

---

## Dependencies

### Packages Required

```yaml
dependencies:
  # Printer support
  blue_thermal_printer: ^1.2.5      # Bluetooth thermal printer
  esc_pos_printer: ^4.1.0           # ESC/POS network printer
  esc_pos_utils: ^1.1.0             # ESC/POS formatting
  flutter_usb_printer: ^0.3.0       # USB printer support
  
  # File handling
  csv: ^6.0.0                       # CSV export
  pdf: ^3.10.0                      # PDF generation
  printing: ^5.11.0                 # PDF printing
  path_provider: ^2.1.0             # File storage
  share_plus: ^7.2.0                # File sharing
  
  # Date handling
  intl: ^0.19.0                     # Date formatting
  
  # State management
  provider: ^6.1.0                  # Already in project
```

### Permissions Required

**Android**:
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

**iOS**:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>We need Bluetooth access to connect to your printer</string>
```

---

## Migration Notes

1. **Existing Agents**
   - Prompt to set up printer on first transaction after update
   - Show tutorial for printer management
   - Import previous transaction history

2. **Transaction Data**
   - Sync last 90 days of transactions on first load
   - Cache transactions locally for offline access
   - Background sync every 6 hours

3. **Printer Settings**
   - Default to last used printer
   - Migrate any existing printer configs from old format

---

## Rollout Strategy

### Week 1-2: Printer Service Development
- Day 1-3: Printer service core functionality
- Day 4-5: Printer provider implementation
- Day 6-7: Bluetooth printer integration
- Day 8-9: USB/Network printer support
- Day 10: Testing with physical printers

### Week 3: Printer Management UI
- Day 1-2: Printer management screen
- Day 3: Print queue UI
- Day 4: Settings and preferences
- Day 5: Testing and bug fixes

### Week 4: Agent Transactions
- Day 1-2: Transaction list screen
- Day 3: Filter and search functionality
- Day 4: Export functionality
- Day 5: Settlement summary
- Day 6-7: Testing and refinement

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Printer connection success rate | > 95% |
| Print job success rate | > 98% |
| Average print time | < 5 seconds |
| Transaction list load time | < 2 seconds |
| Export generation time | < 5 seconds |
| Agent satisfaction score | > 4.5/5 |
| Print queue retry success | > 90% |

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Printer compatibility issues | High | Test with top 10 printer models |
| Print queue overflow | Medium | Limit queue to 50 jobs, auto-clear old |
| Bluetooth connection drops | High | Auto-reconnect with exponential backoff |
| Large export crashes app | Medium | Paginate exports, show progress |
| Commission calculation errors | Critical | Automated testing + manual audit |
| Offline transaction sync | Medium | Queue and retry with conflict resolution |

---

## Notes

- Prioritize support for most common printer models in Indonesia (Zjiang, BlueBamboo, Epson)
- Consider thermal printer paper size standards (58mm most common for mobile)
- Ensure receipt templates comply with Indonesian tax receipt requirements
- Commission calculation must match backend precisely for audit compliance
- Test extensively with poor Bluetooth connectivity scenarios
