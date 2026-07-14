import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Renders a 62 mm × 20 mm Brother QL label as a [ui.Image].
///
/// Layout mirrors the Android [PrinterHelper.createLabelBitmap] method.
///   Width  = 720 dots (62 mm at 300 dpi, full printhead width)
///   Height = 236 dots (20 mm at 300 dpi)
class LabelRenderer {
  static const int widthDots = 720;
  static const int heightDots = 236;

  // ── Layout constants (matching Android baseline positions) ──────────────
  static const double _leftPad = 40.0;
  static const double _maxNameWidth = 440.0;
  static const double _lineY = 86.0;
  static const double _lineEndX = 476.0;

  // QR block
  static const double _qrSize = 220.0;
  static const double _qrX = widthDots - _qrSize - 10; // 490
  static const double _qrY = 8.0;

  static Future<ui.Image> render({
    required String name,
    required String schemeId,   // QR code data  e.g. "scheme:42"
    required String date,        // Pre-formatted date string
    required String amount,      // Numeric string e.g. "500"
    required String schemeNumber, // Display ID   e.g. "42"
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, widthDots.toDouble(), heightDots.toDouble()),
    );

    // ── Background ──────────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, widthDots.toDouble(), heightDots.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    // ── Name (title-cased, dynamic font size) ───────────────────────────────
    final formattedName = _titleCase(name);
    final namePainter = _fitText(formattedName, maxFontSize: 46, minFontSize: 26,
        maxWidth: _maxNameWidth, bold: true);

    // Android baseline for name = 65 px.  Convert baseline → top offset:
    // ascent ≈ 75 % of fontSize.
    final nameTop = 65.0 - (namePainter.size.height * 0.82);
    namePainter.paint(canvas, Offset(_leftPad, nameTop.clamp(4.0, 40.0)));

    // ── Divider line ────────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(_leftPad, _lineY),
      Offset(_lineEndX, _lineY),
      Paint()
        ..color = const Color(0xFF000000)
        ..strokeWidth = 2.5,
    );

    // ── Date (Android baseline = 140) ───────────────────────────────────────
    final datePainter = _buildText(date, fontSize: 36, bold: false);
    datePainter.paint(canvas, Offset(_leftPad, 140 - datePainter.size.height * 0.82));

    // ── Amount (Android baseline = 200) ─────────────────────────────────────
    final amountPainter = _buildText('₹$amount', fontSize: 42, bold: true);
    amountPainter.paint(canvas, Offset(_leftPad, 200 - amountPainter.size.height * 0.82));

    // ── QR code ─────────────────────────────────────────────────────────────
    _drawQrCode(canvas, schemeId, Rect.fromLTWH(_qrX, _qrY, _qrSize, _qrSize));

    // ── Scheme number (right-of / left-of QR, same row as amount) ───────────
    final idText = '#${schemeNumber.padLeft(2, '0')}';
    final idPainter = _buildText(idText, fontSize: 42, bold: true);
    final idX = _qrX - idPainter.size.width - 15;
    idPainter.paint(canvas, Offset(idX, 200 - idPainter.size.height * 0.82));

    final picture = recorder.endRecording();
    return picture.toImage(widthDots, heightDots);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _titleCase(String text) {
    return text
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Returns a laid-out [TextPainter] that fits [text] in [maxWidth],
  /// trying font sizes from [maxFontSize] down to [minFontSize].
  /// If nothing fits, truncates with ellipsis at [minFontSize].
  static TextPainter _fitText(String text,
      {required double maxFontSize,
      required double minFontSize,
      required double maxWidth,
      required bool bold}) {
    for (double size = maxFontSize; size >= minFontSize; size--) {
      final tp = _buildText(text, fontSize: size, bold: bold);
      if (tp.size.width <= maxWidth) return tp;
    }
    // Truncate with ellipsis
    final avgW = minFontSize * 0.58;
    final maxChars = (maxWidth / avgW).floor().clamp(3, text.length);
    int end = maxChars - 3;
    // Walk back to avoid splitting a surrogate pair
    while (end > 0 && text.codeUnitAt(end) >= 0xDC00 && text.codeUnitAt(end) <= 0xDFFF) {
      end--;
    }
    return _buildText('${text.substring(0, end)}...', fontSize: minFontSize, bold: bold);
  }

  static TextPainter _buildText(String text,
      {required double fontSize, required bool bold}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: const Color(0xFF000000),
          height: 1.0,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  static void _drawQrCode(Canvas canvas, String data, Rect rect) {
    try {
      final qrCode = QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.L,
      );
      final qrImage = QrImage(qrCode);
      final moduleCount = qrImage.moduleCount;
      final moduleSize = rect.width / moduleCount;

      final darkPaint = Paint()
        ..color = const Color(0xFF000000)
        ..style = PaintingStyle.fill;
      final lightPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;

      canvas.drawRect(rect, lightPaint);

      for (int x = 0; x < moduleCount; x++) {
        for (int y = 0; y < moduleCount; y++) {
          if (qrImage.isDark(y, x)) {
            canvas.drawRect(
              Rect.fromLTWH(
                rect.left + x * moduleSize,
                rect.top + y * moduleSize,
                moduleSize,
                moduleSize,
              ),
              darkPaint,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('LabelRenderer: QR error – $e');
    }
  }
}
