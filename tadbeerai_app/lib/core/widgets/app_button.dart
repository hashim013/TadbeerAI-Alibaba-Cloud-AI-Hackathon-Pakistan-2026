import 'package:flutter/material.dart';

/// Primary call-to-action button with a built-in loading state.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? trailingIcon;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed:
          widget.loading || widget.onPressed == null ? null : widget.onPressed,
      child: widget.loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.label),
                if (widget.trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  widget.trailingIcon!,
                ],
              ],
            ),
    );
  }
}
