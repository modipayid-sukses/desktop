import 'package:flutter/material.dart';

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
  final TextInputType keyboardType;
  final bool obscureText;

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
    this.keyboardType = TextInputType.number,
    this.obscureText = true,
  });

  @override
  State<PinDotsField> createState() => _PinDotsFieldState();
}

class _PinDotsFieldState extends State<PinDotsField>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late AnimationController _shakeController;
  late AnimationController _scaleController;
  late Animation<Offset> _shakeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0.05, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0.05, 0), end: const Offset(-0.05, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(-0.05, 0), end: const Offset(0.05, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0.05, 0), end: Offset.zero),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(PinDotsField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isError && !oldWidget.isError) {
      _shakeController.forward().then((_) {
        _shakeController.reset();
      });
    }

    if (widget.isSuccess && !oldWidget.isSuccess) {
      _scaleController.forward().then((_) {
        _scaleController.reset();
      });
    }
  }

  void _onTextChanged(String value) {
    widget.onChanged?.call(value);

    if (value.length == widget.length) {
      widget.onCompleted(value);
    }

    setState(() {});
  }

  void _handleKeyEvent(RawKeyEvent event) {
    // Handle backspace
    if (event.isKeyPressed(LogicalKeyboardKey.backspace)) {
      if (_controller.text.isNotEmpty) {
        _controller.text =
            _controller.text.substring(0, _controller.text.length - 1);
        _onTextChanged(_controller.text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _shakeAnimation,
      child: Transform.scale(
        scale: _scaleAnimation.value,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hidden text field for input
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: widget.keyboardType,
              maxLength: widget.length,
              obscureText: false,
              decoration: InputDecoration(
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _onTextChanged,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 0,
                height: 0,
              ),
            ),
            SizedBox(height: 16),
            // Dots display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.length,
                (index) {
                  final isActive = _controller.text.length > index;
                  final isCompleted = _controller.text.length == widget.length;

                  Color dotColor;
                  IconData? icon;

                  if (widget.isSuccess && isCompleted) {
                    dotColor = widget.successColor;
                    icon = Icons.check;
                  } else if (widget.isError) {
                    dotColor = widget.errorColor;
                  } else if (isActive) {
                    dotColor = widget.activeDotColor;
                  } else {
                    dotColor = widget.dotColor;
                  }

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.spacing / 2,
                    ),
                    child: GestureDetector(
                      onTap: () => _focusNode.requestFocus(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: widget.dotSize,
                        height: widget.dotSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor.withOpacity(
                            isActive ? 1.0 : 0.3,
                          ),
                          border: Border.all(
                            color: dotColor,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: icon != null
                            ? Icon(
                                icon,
                                color: Colors.white,
                                size: widget.dotSize * 0.6,
                              )
                            : SizedBox(),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            // Custom numpad (optional)
            _buildNumpad(),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final number = (i + 1).toString();
            return _buildNumpadButton(number);
          }),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final number = (i + 4).toString();
            return _buildNumpadButton(number);
          }),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final number = (i + 7).toString();
            return _buildNumpadButton(number);
          }),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumpadButton('', isBackspace: true),
            _buildNumpadButton('0'),
            SizedBox(width: 48), // Spacer
          ],
        ),
      ],
    );
  }

  Widget _buildNumpadButton(String number, {bool isBackspace = false}) {
    return GestureDetector(
      onTap: () {
        if (isBackspace) {
          if (_controller.text.isNotEmpty) {
            _controller.text =
                _controller.text.substring(0, _controller.text.length - 1);
            _onTextChanged(_controller.text);
          }
        } else if (_controller.text.length < widget.length) {
          _controller.text += number;
          _onTextChanged(_controller.text);
        }
      },
      child: Container(
        width: 48,
        height: 48,
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[200],
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: isBackspace
              ? Icon(Icons.backspace, size: 20, color: Colors.grey[700])
              : Text(
                  number,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }
}
