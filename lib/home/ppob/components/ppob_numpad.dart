import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PPOBNumpad extends StatelessWidget {
  final Color accentColor;
  final Color textPrimaryColor;
  final Color textSecondaryColor;
  final Function(String) onDigitPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onClearPressed;
  final VoidCallback onClosePressed;

  const PPOBNumpad({
    super.key,
    required this.accentColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.onDigitPressed,
    required this.onDeletePressed,
    required this.onClearPressed,
    required this.onClosePressed,
  });

  Future<void> _triggerHaptic() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  Widget _buildButton({
    required VoidCallback onTap,
    String? label,
    IconData? icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          _triggerHaptic();
          onTap();
        },
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFF6F9FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEAF1FF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, color: accentColor, size: 22)
                : Text(
                    label ?? '',
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontFamily: 'Gilroy Bold',
                      fontSize: 24,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Numpad',
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontFamily: 'Gilroy Bold',
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onClosePressed,
                  icon: Icon(Icons.keyboard_hide_rounded, color: accentColor),
                  splashRadius: 20,
                ),
              ],
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                _buildButton(onTap: () => onDigitPressed('1'), label: '1'),
                _buildButton(onTap: () => onDigitPressed('2'), label: '2'),
                _buildButton(onTap: () => onDigitPressed('3'), label: '3'),
                _buildButton(onTap: () => onDigitPressed('4'), label: '4'),
                _buildButton(onTap: () => onDigitPressed('5'), label: '5'),
                _buildButton(onTap: () => onDigitPressed('6'), label: '6'),
                _buildButton(onTap: () => onDigitPressed('7'), label: '7'),
                _buildButton(onTap: () => onDigitPressed('8'), label: '8'),
                _buildButton(onTap: () => onDigitPressed('9'), label: '9'),
                _buildButton(onTap: onClearPressed, icon: Icons.close_rounded),
                _buildButton(onTap: () => onDigitPressed('0'), label: '0'),
                _buildButton(onTap: onDeletePressed, icon: Icons.backspace_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
