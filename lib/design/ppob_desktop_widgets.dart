// Shared widgets for the desktop two-column PPOB purchase layout (prepaid
// nominal picker + postpaid tagihan screens). Mobile keeps its existing
// single-column layout untouched — these are additive, desktop-only pieces
// built on the `desktop*` tokens from `utils/color.dart` (same visual
// language as the desktop login screen).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modipay/utils/color.dart';

/// Numbered section header, e.g. "1. Isi Nomor Tujuan".
class PpobStepHeader extends StatelessWidget {
  final int step;
  final String title;
  final String? subtitle;

  const PpobStepHeader({super.key, required this.step, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$step. $title',
          style: GoogleFonts.hankenGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: desktopTextPrimary),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary),
          ),
        ],
      ],
    );
  }
}

enum PpobBannerTone { success, info }

/// Tinted info row used for both the green "Nomor terverifikasi" banner and
/// the light-blue "Transaksi Aman" banner.
class PpobDesktopBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final PpobBannerTone tone;
  final Widget? trailing;

  const PpobDesktopBanner({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone = PpobBannerTone.success,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = tone == PpobBannerTone.success ? desktopSuccessFg : desktopPrimaryBtn;
    final bg = tone == PpobBannerTone.success ? desktopSuccessBg : desktopPrimaryBtn.withValues(alpha: 0.07);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.hankenGrotesk(fontSize: 12, color: desktopTextSecondary),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Selectable nominal/product card for the desktop grid (e.g. pulsa
/// nominal, paket data option). Matches the reference: bold title, optional
/// "Populer"/"Terlaris" badge, "Harga" caption + price, selected border.
class PpobNominalCard extends StatelessWidget {
  final String title;
  final String priceLabel;
  final String? badge;
  final bool selected;
  final VoidCallback? onTap;

  const PpobNominalCard({
    super.key,
    required this.title,
    required this.priceLabel,
    this.badge,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: desktopSurfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? desktopAccentBlue : desktopBorder, width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.hankenGrotesk(fontSize: 15, fontWeight: FontWeight.w800, color: desktopTextPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle_rounded, color: desktopAccentBlue, size: 18)
                  else if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: desktopPrimaryBtn.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge!,
                        style: GoogleFonts.hankenGrotesk(fontSize: 9.5, fontWeight: FontWeight.w700, color: desktopAccentBlue),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Harga', style: GoogleFonts.hankenGrotesk(fontSize: 11, color: desktopTextSecondary)),
              Text(
                priceLabel,
                style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: desktopTextSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon + label (left) / value (right, bold) row for the transaction
/// summary panel.
class PpobDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const PpobDetailRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: desktopTextSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopTextPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The sticky right-hand "Detail Transaksi" card: summary rows, a safety
/// banner, total price, and the confirm button.
class PpobDesktopSummaryPanel extends StatelessWidget {
  final List<PpobDetailRow> rows;
  final String totalLabel;
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final bool loading;

  const PpobDesktopSummaryPanel({
    super.key,
    required this.rows,
    required this.totalLabel,
    this.confirmLabel = 'Konfirmasi Pembayaran',
    this.onConfirm,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: desktopSurfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: desktopBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Detail Transaksi',
            style: GoogleFonts.hankenGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: desktopTextPrimary),
          ),
          const SizedBox(height: 4),
          Divider(color: desktopBorder.withValues(alpha: 0.5), height: 20),
          ...rows,
          const SizedBox(height: 12),
          const PpobDesktopBanner(
            icon: Icons.verified_user_rounded,
            title: 'Transaksi Aman',
            subtitle: 'Transaksi kamu dijamin aman dan terenkripsi end-to-end.',
            tone: PpobBannerTone.info,
          ),
          const SizedBox(height: 20),
          Text('Total Pembayaran', style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary)),
          const SizedBox(height: 4),
          Text(
            totalLabel,
            style: GoogleFonts.hankenGrotesk(fontSize: 26, fontWeight: FontWeight.w800, color: desktopAccentBlue),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: desktopPrimaryBtn,
                disabledBackgroundColor: desktopPrimaryBtn.withValues(alpha: 0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : Text(confirmLabel, style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-column shell: scrollable left content card + fixed-width sticky
/// right summary card. Used by every desktop PPOB screen.
class PpobDesktopTwoColumnLayout extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double rightWidth;

  const PpobDesktopTwoColumnLayout({super.key, required this.left, required this.right, this.rightWidth = 380});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: desktopSurfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: desktopBorder.withValues(alpha: 0.5)),
            ),
            child: SingleChildScrollView(child: left),
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(width: rightWidth, child: right),
      ],
    );
  }
}
