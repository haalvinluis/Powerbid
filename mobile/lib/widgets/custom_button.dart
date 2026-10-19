import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ButtonType { primary, secondary, danger }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonType type;
  final IconData? icon;
  final bool isLoading;
  final double? width;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = ButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (type) {
      case ButtonType.primary:
        bg = AppTheme.primary;
        fg = Colors.white;
        break;
      case ButtonType.secondary:
        bg = AppTheme.surfaceLight;
        fg = AppTheme.accent;
        border = const BorderSide(color: AppTheme.accent, width: 1.5);
        break;
      case ButtonType.danger:
        bg = AppTheme.surfaceLight;
        fg = AppTheme.error;
        border = const BorderSide(color: AppTheme.error, width: 1.5);
        break;
    }

    final childWidget = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  fontSize: 15,
                ),
              ),
            ],
          );

    return SizedBox(
      width: width ?? double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: type == ButtonType.primary ? 4 : 0,
          shadowColor: AppTheme.primary.withOpacity(0.4),
          side: border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: childWidget,
      ),
    );
  }
}
