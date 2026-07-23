# Implementation Plan - Priority 3: UI/UX Enhancement

**Status**: Not Started  
**Timeline**: 2 weeks  
**Dependencies**: None (can run parallel with Priority 1 & 2)

---

## Overview

Enhance user experience with improved UI components focusing on security feedback, input experience, and payment confirmation flows.

---

## 1. PIN Dots Field

**File**: `lib/utils/pin_dots_field.dart`

### Requirements
- Visual PIN input with dots/circles
- Animated feedback on input
- Error state with shake animation
- Success state with checkmark
- Configurable length (4-6 digits)
- Secure input (no keyboard preview)

### Implementation

```dart
class PinDotsField extends StatefulWidget {
  final int length;
  final Function(String) onCompleted;
  final Function(String)? onChanged;
  final bool isError;
  final bool isSuccess;
  final Color dotColor;
  final Color activeDotColor;
  final Color errorColor;
  final Color successColor;
  final double dotSize;
  final double spacing;

  const PinDotsField({
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.isError = false,
    this.isSuccess = false,
    this.dotColor = Colors.grey,
    this.activeDotColor = Colors.blue,
    this.errorColor = Colors.red,
    this.successColor = Colors.green,
    this.dotSize = 16,
    this.spacing = 16,
  });
}
```

### UI States

1. **Empty State**
   ```
   ○ ○ ○ ○ ○ ○
   ```

2. **Filling State**
   ```
   ● ● ● ○ ○ ○
   ```

3. **Error State** (shake animation)
   ```
   ● ● ● ● ● ●  ← shakes left-right
   (red color)
   ```

4. **Success State** (scale animation)
   ```
   ✓ ✓ ✓ ✓ ✓ ✓
   (green color)
   ```

### Animations

```dart
// Shake animation on error
class ShakeAnimation extends StatefulWidget {
  @override
  _ShakeAnimationState createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]).animate(_controller);
  }
}

// Scale animation on success
class ScaleAnimation extends StatefulWidget {
  @override
  _ScaleAnimationState createState() => _ScaleAnimationState();
}

class _ScaleAnimationState extends State<ScaleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }
}
```

### Security Features

- No clipboard access
- No keyboard autocomplete
- Obscured input immediately
- Clear PIN from memory after use
- Biometric fallback option

### Usage Example

```dart
PinDotsField(
  length: 6,
  onCompleted: (pin) async {
    bool isValid = await verifyPin(pin);
    setState(() {
      if (isValid) {
        _isSuccess = true;
        // Navigate to next screen
      } else {
        _isError = true;
        // Show error message
      }
    });
  },
  isError: _isError,
  isSuccess: _isSuccess,
)
```

### Acceptance Criteria
- [ ] Display correct number of dots (4-6 configurable)
- [ ] Animate on each digit input
- [ ] Shake animation on error
- [ ] Success animation on valid PIN
- [ ] Secure input (no preview)
- [ ] Works with custom numpad
- [ ] Accessible (screen reader support)
- [ ] Smooth 60fps animations

### Testing
- Test with different PIN lengths
- Test error state animation
- Test success state animation
- Test rapid input
- Test backspace handling
- Accessibility audit

---

## 2. Animated Lock Icon

**File**: `lib/widgets/animated_lock_icon.dart`

### Requirements
- Visual feedback for security states
- Smooth transitions between states
- Micro-interactions on tap
- Support locked/unlocked/loading states

### Implementation

```dart
enum LockState {
  locked,
  unlocked,
  loading,
}

class AnimatedLockIcon extends StatefulWidget {
  final LockState state;
  final Color lockedColor;
  final Color unlockedColor;
  final double size;
  final VoidCallback? onTap;
  final Duration animationDuration;

  const AnimatedLockIcon({
    required this.state,
    this.lockedColor = Colors.red,
    this.unlockedColor = Colors.green,
    this.size = 48,
    this.onTap,
    this.animationDuration = const Duration(milliseconds: 300),
  });
}
```

### Animation States

1. **Locked → Unlocked**
   - Lock body slides down
   - Shackle rotates open
   - Color transition red → green
   - Duration: 300ms

2. **Unlocked → Locked**
   - Shackle rotates closed
   - Lock body slides up
   - Color transition green → red
   - Duration: 300ms

3. **Loading State**
   - Pulsing animation
   - Rotate 360° continuously
   - Semi-transparent overlay

### Custom Paint Implementation

```dart
class LockIconPainter extends CustomPainter {
  final LockState state;
  final Color color;
  final Animation<double> animation;

  LockIconPainter({
    required this.state,
    required this.color,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw lock body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.25,
        size.height * 0.5,
        size.width * 0.5,
        size.height * 0.4,
      ),
      Radius.circular(4),
    );
    canvas.drawRRect(bodyRect, paint);

    // Draw shackle (animated based on state)
    final shacklePath = Path();
    if (state == LockState.locked) {
      // Closed shackle
      shacklePath.addArc(
        Rect.fromLTWH(
          size.width * 0.3,
          size.height * 0.1,
          size.width * 0.4,
          size.height * 0.4,
        ),
        math.pi,
        math.pi,
      );
    } else {
      // Open shackle (rotated)
      final rotation = animation.value * math.pi / 4;
      canvas.save();
      canvas.translate(size.width * 0.5, size.height * 0.5);
      canvas.rotate(rotation);
      canvas.translate(-size.width * 0.5, -size.height * 0.5);
      
      shacklePath.addArc(
        Rect.fromLTWH(
          size.width * 0.3,
          size.height * 0.1,
          size.width * 0.4,
          size.height * 0.4,
        ),
        math.pi,
        math.pi * 0.75,
      );
      
      canvas.restore();
    }
    canvas.drawPath(shacklePath, paint);
  }

  @override
  bool shouldRepaint(LockIconPainter oldDelegate) => true;
}
```

### Usage Examples

```dart
// Login screen
AnimatedLockIcon(
  state: _isLoggedIn ? LockState.unlocked : LockState.locked,
  size: 64,
)

// Loading during auth
AnimatedLockIcon(
  state: LockState.loading,
  size: 48,
)

// Security settings
AnimatedLockIcon(
  state: _biometricEnabled ? LockState.unlocked : LockState.locked,
  onTap: () => toggleBiometric(),
)
```

### Acceptance Criteria
- [ ] Smooth locked/unlocked transition
- [ ] Loading state rotates continuously
- [ ] Color transitions smoothly
- [ ] Tap feedback animation
- [ ] 60fps performance
- [ ] Configurable size and colors
- [ ] Works on both light/dark themes

### Testing
- Test state transitions
- Test loading animation
- Test tap interactions
- Performance profiling
- Visual regression testing

---

## 3. Confirm Payment Scaffold

**File**: `lib/widgets/confirm_payment_scaffold.dart`

### Requirements
- Standardized payment confirmation UI
- Transaction details display
- PIN verification integration
- Success/failure feedback
- Receipt generation
- Share functionality

### Implementation

```dart
class ConfirmPaymentScaffold extends StatelessWidget {
  final String title;
  final Widget transactionDetails;
  final String totalAmount;
  final String? fee;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool requirePin;
  final bool showReceipt;

  const ConfirmPaymentScaffold({
    required this.title,
    required this.transactionDetails,
    required this.totalAmount,
    this.fee,
    required this.onConfirm,
    this.onCancel,
    this.requirePin = true,
    this.showReceipt = true,
  });
}
```

### UI Layout

```
┌─────────────────────────────┐
│  ← Back     [Title]         │
├─────────────────────────────┤
│                             │
│  [Transaction Details]      │
│   • Recipient: John Doe     │
│   • Account: 1234567890     │
│   • Bank: BCA               │
│                             │
│  ┌───────────────────────┐  │
│  │ Amount                │  │
│  │ Rp 500,000           │  │
│  │                       │  │
│  │ Admin Fee             │  │
│  │ Rp 2,500             │  │
│  │ ─────────────────────│  │
│  │ Total                 │  │
│  │ Rp 502,500           │  │
│  └───────────────────────┘  │
│                             │
│  ⓘ Transaction will be      │
│     processed immediately   │
│                             │
├─────────────────────────────┤
│  [Cancel]    [Confirm Pay]  │
└─────────────────────────────┘
```

### Payment Flow

```dart
enum PaymentStep {
  confirm,      // Show details, await confirmation
  enterPin,     // PIN verification
  processing,   // API call in progress
  success,      // Transaction successful
  failed,       // Transaction failed
}

class PaymentFlowController {
  PaymentStep _currentStep = PaymentStep.confirm;
  
  Future<void> processPayment() async {
    setState(() => _currentStep = PaymentStep.enterPin);
    
    final pin = await showPinDialog();
    if (pin == null) return; // User cancelled
    
    setState(() => _currentStep = PaymentStep.processing);
    
    try {
      final result = await paymentService.process(pin: pin);
      setState(() => _currentStep = PaymentStep.success);
      await showSuccessDialog(result);
    } catch (e) {
      setState(() => _currentStep = PaymentStep.failed);
      await showErrorDialog(e.message);
    }
  }
}
```

### Transaction Detail Widget

```dart
class TransactionDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const TransactionDetailRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isHighlight ? 16 : 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? Colors.black : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 18 : 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? Theme.of(context).primaryColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
```

### PIN Verification Dialog

```dart
Future<String?> showPinDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('Enter PIN'),
      content: PinDotsField(
        length: 6,
        onCompleted: (pin) {
          Navigator.pop(context, pin);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ],
    ),
  );
}
```

### Success/Failure Dialogs

```dart
// Success dialog
Future<void> showSuccessDialog(TransactionResult result) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.check_circle, color: Colors.green, size: 64),
      title: Text('Payment Successful'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Transaction ID: ${result.transactionId}'),
          SizedBox(height: 16),
          Text('Amount: ${result.amount}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => shareReceipt(result),
          child: Text('Share'),
        ),
        TextButton(
          onPressed: () => printReceipt(result),
          child: Text('Print'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Done'),
        ),
      ],
    ),
  );
}

// Failure dialog
Future<void> showErrorDialog(String message) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.error, color: Colors.red, size: 64),
      title: Text('Payment Failed'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            retryPayment();
          },
          child: Text('Retry'),
        ),
      ],
    ),
  );
}
```

### Usage Example

```dart
ConfirmPaymentScaffold(
  title: 'Transfer Confirmation',
  transactionDetails: Column(
    children: [
      TransactionDetailRow(label: 'To', value: 'John Doe'),
      TransactionDetailRow(label: 'Bank', value: 'BCA'),
      TransactionDetailRow(label: 'Account', value: '1234567890'),
      Divider(),
      TransactionDetailRow(label: 'Amount', value: 'Rp 500,000'),
      TransactionDetailRow(label: 'Fee', value: 'Rp 2,500'),
      Divider(thickness: 2),
      TransactionDetailRow(
        label: 'Total',
        value: 'Rp 502,500',
        isHighlight: true,
      ),
    ],
  ),
  totalAmount: 'Rp 502,500',
  onConfirm: () async {
    await processPayment();
  },
)
```

### Acceptance Criteria
- [ ] Display transaction details clearly
- [ ] Show amount breakdown with fees
- [ ] PIN verification integrated
- [ ] Processing state shows loader
- [ ] Success dialog with receipt options
- [ ] Failure dialog with retry option
- [ ] Share receipt functionality
- [ ] Print receipt integration
- [ ] Prevent double-submission
- [ ] Accessible layout

### Testing
- Test with various transaction types
- Test PIN verification flow
- Test success/failure scenarios
- Test receipt generation
- Test double-tap prevention
- Accessibility testing
- UI regression testing

---

## Dependencies

### Packages Required

```yaml
dependencies:
  # Already in project
  flutter: sdk
  
  # Animation support
  flutter_animate: ^4.5.0
  
  # Share functionality
  share_plus: ^7.2.0  # Already in Priority 2
  
  # Receipt generation
  pdf: ^3.10.0  # Already in Priority 2
```

---

## Rollout Strategy

### Week 1: Core Components
- Day 1-2: PIN dots field implementation
- Day 3: Animated lock icon
- Day 4-5: Confirm payment scaffold

### Week 2: Integration & Polish
- Day 1-2: Integration with existing screens
- Day 3: Animation tuning and polish
- Day 4: Accessibility improvements
- Day 5: Testing and bug fixes

---

## Success Metrics

| Metric | Target |
|--------|--------|
| PIN input completion time | < 5 seconds |
| Animation frame rate | 60fps |
| Payment confirmation time | < 10 seconds |
| User satisfaction (UI) | > 4.5/5 |
| Accessibility score | 100% |
| Error rate (payment confirm) | < 0.1% |

---

## Notes

- All animations must maintain 60fps on mid-range devices
- Follow Material Design 3 guidelines for interactions
- Ensure high contrast for accessibility
- Test on various screen sizes (small to tablet)
- Consider dark mode support for all components
