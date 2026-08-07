// Desktop "Autentikasi Transaksi" popup: collects kasir_code + kasir_pin
// before a payment is submitted, identifying which cashier processed the
// sale. Matches the desktop "Vivid Enterprise" visual language (desktop*
// tokens) rather than the mobile numpad flow in ConfirmPayment, since this
// is only shown on wide/desktop layouts.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/color.dart';

/// Returning normally closes the dialog (caller is expected to navigate
/// away, e.g. to a transaction receipt). Throwing shows the error inline
/// and keeps the dialog open so the user can retry.
///
/// kasirCode + kasirPin identify a real Kasir record belonging to this
/// store (see App\Models\Kasir on the backend) — this replaces the store
/// owner's own account PIN for these transactions once at least one Kasir
/// has been registered (see kasir management screen).
typedef PinAuthSubmit = Future<void> Function(String kasirCode, String kasirPin);

class TransactionPinAuthDialog extends StatefulWidget {
  final String title;
  final String description;
  final String cancelText;
  final String confirmText;
  final PinAuthSubmit onConfirm;

  const TransactionPinAuthDialog({
    super.key,
    this.title = 'Autentikasi Transaksi',
    this.description =
        'Masukkan kode kasir dan PIN kasir untuk melanjutkan pembayaran.',
    this.cancelText = 'Batal',
    this.confirmText = 'Lanjutkan',
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required PinAuthSubmit onConfirm,
    String title = 'Autentikasi Transaksi',
    String description =
        'Masukkan kode kasir dan PIN kasir untuk melanjutkan pembayaran.',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => TransactionPinAuthDialog(
        title: title,
        description: description,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<TransactionPinAuthDialog> createState() =>
      _TransactionPinAuthDialogState();
}

class _TransactionPinAuthDialogState extends State<TransactionPinAuthDialog> {
  final _cashierController = TextEditingController();
  final _pinController = TextEditingController();
  final _cashierFocus = FocusNode();
  final _pinFocus = FocusNode();
  bool _obscurePin = true;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _cashierController.dispose();
    _pinController.dispose();
    _cashierFocus.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final kasirCode = _cashierController.text.trim();
    final kasirPin = _pinController.text.trim();

    if (kasirCode.isEmpty) {
      setState(() => _errorText = 'Kode kasir wajib diisi');
      return;
    }
    if (kasirPin.length != 4) {
      setState(() => _errorText = 'PIN kasir harus 4 digit');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.onConfirm(kasirCode, kasirPin);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = e.toString();
      });
      return;
    }
    // Success: the caller is responsible for closing this dialog (it needs
    // to pop it before navigating to the receipt page), so nothing to do.
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 400,
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
        decoration: BoxDecoration(
          color: desktopSurfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close_rounded,
                        size: 20, color: desktopTextSecondary),
                  ),
                ),
              ],
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: desktopPrimaryBtn.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.lock_rounded,
                  color: desktopPrimaryBtn, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: desktopTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                color: desktopTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Kode Kasir',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: desktopTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            desktopBorderedField(
              icon: Icons.badge_outlined,
              controller: _cashierController,
              focusNode: _cashierFocus,
              hint: 'Masukkan kode kasir',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _cashierFocus.nextFocus(),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PIN Kasir',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: desktopTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            desktopBorderedField(
              icon: Icons.lock_outline_rounded,
              controller: _pinController,
              focusNode: _pinFocus,
              hint: 'Masukkan PIN kasir',
              obscureText: _obscurePin,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleConfirm(),
              suffix: IconButton(
                icon: Icon(
                  _obscurePin
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: desktopTextSecondary,
                ),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    color: desktopErrorRed,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: desktopPrimaryBtn.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: desktopPrimaryBtn.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 18, color: desktopPrimaryBtn),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kode dan PIN kasir dipakai untuk mencatat siapa yang memproses transaksi ini.',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        color: desktopTextSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed:
                          _isSubmitting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: desktopBorder),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        widget.cancelText,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: desktopTextPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: desktopPrimaryBtn,
                        disabledBackgroundColor:
                            desktopPrimaryBtn.withValues(alpha: 0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.confirmText,
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 16, color: Colors.white),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
