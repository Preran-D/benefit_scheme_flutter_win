import 'package:flutter/material.dart';

/// A consistent, premium dialog shell used across the entire app.
/// Provides a white background, rounded corners, optional title and back arrow.
class AppDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final double width;
  final VoidCallback? onBack;
  final bool showClose;

  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.width = 480,
    this.onBack,
    this.showClose = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: Container(
        width: width,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
              ),
              child: Row(
                children: [
                  if (onBack != null)
                    _HeaderIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: onBack!,
                      color: Colors.black87,
                    )
                  else
                    const SizedBox(width: 36),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (showClose)
                    _HeaderIconButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                      color: Colors.black54,
                    )
                  else
                    const SizedBox(width: 36),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

/// A styled full-width primary action button for use inside [AppDialog].
class AppDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final Widget? leading;

  const AppDialogButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.color,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[200],
          disabledForegroundColor: Colors.grey[500],
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 8)],
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }
}

/// A styled text field for use inside [AppDialog].
class AppDialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? prefixText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final int? maxLines;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const AppDialogField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixText,
    this.prefixIcon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
