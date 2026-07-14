import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// Sends a [ui.Image] to a Brother QL-810W printer over raw TCP (port 9100)
/// using the Brother QL raster protocol.
///
/// Protocol reference:
///   Brother Label Printer ESC/P Command Reference
///   "Raster" page mode (mode switch 0x01)
///
/// For 62 mm continuous roll (RollW62) at 300 dpi:
///   Printhead width = 720 dots → 90 bytes per raster row
///   Label height    = 236 dots (20 mm)
class BrotherQLPrinter {
  // ── Raster geometry ───────────────────────────────────────────────────────
  static const int _bytesPerRow = 90; // 720 / 8

  // ── Entry point ──────────────────────────────────────────────────────────

  /// Renders the label image to Brother raster commands and sends them
  /// via TCP to [ipAddress]:9100.
  ///
  /// Returns `true` on success, `false` on any error.
  static Future<bool> printImage({
    required String ipAddress,
    required ui.Image labelImage,
    int port = 9100,
    Duration connectTimeout = const Duration(seconds: 5),
    Duration writeTimeout = const Duration(seconds: 10),
  }) async {
    try {
      // 1. Convert image pixels → packed monochrome rows
      final rasterRows = await _toMonochromeRaster(labelImage);

      // 2. Wrap in Brother raster command sequence
      final commands = _buildCommands(rasterRows, labelImage.height);

      // 3. Open raw TCP socket and flush
      debugPrint('BrotherQLPrinter: connecting to $ipAddress:$port …');
      final socket = await Socket.connect(
        ipAddress,
        port,
        timeout: connectTimeout,
      );
      socket.add(Uint8List.fromList(commands));
      await socket.flush();
      await socket.close();
      debugPrint('BrotherQLPrinter: ${commands.length} bytes sent, socket closed.');
      return true;
    } on SocketException catch (e) {
      debugPrint('BrotherQLPrinter: socket error – ${e.message}');
      return false;
    } catch (e) {
      debugPrint('BrotherQLPrinter: unexpected error – $e');
      return false;
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Converts a [ui.Image] (RGBA pixels) to packed 1-bit monochrome rows
  /// ready for the Brother QL raster protocol.
  ///
  /// - Each row = [_bytesPerRow] bytes (720 bits), MSB = leftmost printer dot.
  /// - Pixels are scanned **right-to-left** so the rendered image is
  ///   horizontally mirrored to match the Brother QL-810W's print direction.
  /// - Brother QL convention: **0 = print dot, 1 = no dot**.
  ///   Dark pixels (luma < 128) → bit 0 (print); light → bit 1 (no print).
  static Future<Uint8List> _toMonochromeRaster(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception('toByteData returned null');

    final pixels = byteData.buffer.asUint8List();
    final imgWidth = image.width;
    final imgHeight = image.height;

    final raster = Uint8List(_bytesPerRow * imgHeight);

    for (int row = 0; row < imgHeight; row++) {
      for (int byteIdx = 0; byteIdx < _bytesPerRow; byteIdx++) {
        int packed = 0;
        for (int bit = 0; bit < 8; bit++) {
          // Scan RIGHT → LEFT: pixel at the far right maps to MSB of byte 0.
          final col = (imgWidth - 1) - (byteIdx * 8 + bit);
          if (col >= 0) {
            final px = (row * imgWidth + col) * 4;
            final r = pixels[px];
            final g = pixels[px + 1];
            final b = pixels[px + 2];
            // Luminance (BT.601 weights)
            final luma = (0.299 * r + 0.587 * g + 0.114 * b).round();
            // Brother QL: 1 = print dot, 0 = no dot.
            // Dark pixel (text/lines) → set bit 1 (print).
            if (luma < 128) packed |= (0x80 >> bit);
          }
          // Edge pixels and light pixels stay 0 (no print = white background)
        }
        raster[row * _bytesPerRow + byteIdx] = packed;
      }
    }

    return raster;
  }

  /// Builds the full Brother QL raster command sequence.
  ///
  /// Sequence:
  ///   1. Invalidate    (200 × 0x00)
  ///   2. Initialize    (ESC @)
  ///   3. Raster mode   (ESC i a 0x01)
  ///   4. Print info    (ESC i z …) – media type, width, raster line count
  ///   5. Auto-cut      (ESC i M 0x40)
  ///   6. Cut at end    (ESC i A 0x01)
  ///   7. Expanded mode (ESC i K 0x08) – disables chain printing
  ///   8. Margins       (ESC i d 0x00 0x00)
  ///   9. Raster rows   (g 0x00 n [n bytes] …)
  ///  10. Print + cut   (0x1A)
  static List<int> _buildCommands(Uint8List rasterRows, int height) {
    final cmd = <int>[];

    // 1. Invalidate
    cmd.addAll(List.filled(200, 0x00));

    // 2. Initialize
    cmd.addAll([0x1B, 0x40]);

    // 3. Switch to raster mode
    cmd.addAll([0x1B, 0x69, 0x61, 0x01]);

    // 4. Print info
    //    n1  = 0x0E  (valid flags: quality + label size + priority quality)
    //    n2  = 0x0A  (continuous roll)
    //    n3  = 0x3E  (label width: 62 mm = 62 decimal = 0x3E)
    //    n4  = 0x00  (label length: 0 = continuous)
    //    n5/n6 = raster line count (little-endian)
    //    n7-n10 = 0x00 (reserved)
    cmd.addAll([
      0x1B, 0x69, 0x7A,
      0x0E,
      0x0A,
      0x3E,
      0x00,
      height & 0xFF,
      (height >> 8) & 0xFF,
      0x00, 0x00,
      0x00,
      0x00,
    ]);

    // 5. Auto-cut (bit 6 = 1)
    cmd.addAll([0x1B, 0x69, 0x4D, 0x40]);

    // 6. Cut each label
    cmd.addAll([0x1B, 0x69, 0x41, 0x01]);

    // 7. Expanded mode – no chain, no special tape cut
    cmd.addAll([0x1B, 0x69, 0x4B, 0x08]);

    // 8. Feed amount: 0 extra lines
    cmd.addAll([0x1B, 0x69, 0x64, 0x00, 0x00]);

    // 9. Raster rows
    for (int row = 0; row < height; row++) {
      cmd.add(0x67); // Raster data command
      cmd.add(0x00); // Reserved
      cmd.add(_bytesPerRow);
      final start = row * _bytesPerRow;
      for (int b = 0; b < _bytesPerRow; b++) {
        cmd.add(rasterRows[start + b]);
      }
    }

    // 10. Print with cut (0x1A = last page, auto-cut)
    cmd.add(0x1A);

    return cmd;
  }
}
