import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const String _repoUrl = 'https://api.github.com/repos/Preran-D/benefit_scheme_flutter_win/releases/latest';

  /// Checks for updates and returns the download URL and version if an update is available, null otherwise.
  static Future<Map<String, String>?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(Uri.parse(_repoUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersionTag = data['tag_name'] as String;
        final latestVersion = latestVersionTag.replaceAll('v', '');
        
        // Simple version comparison
        if (_isNewerVersion(currentVersion, latestVersion)) {
          final assets = data['assets'] as List;
          final zipAsset = assets.firstWhere(
            (asset) => (asset['name'] as String).endsWith('.zip'),
            orElse: () => null,
          );

          if (zipAsset != null) {
            return {
              'version': latestVersion,
              'url': zipAsset['browser_download_url'],
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for update: $e');
    }
    return null;
  }

  /// Downloads the update, extracts it, and executes the replacement script.
  static Future<void> downloadAndInstallUpdate(String downloadUrl, Function(double) onProgress) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final downloadFile = File('${tempDir.path}\\benefit_scheme_update.zip');

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await http.Client().send(request);
      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;

      final fileSink = downloadFile.openWrite();
      await response.stream.map((chunk) {
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(downloadedBytes / totalBytes);
        }
        return chunk;
      }).pipe(fileSink);

      await fileSink.close();

      // Extract the zip
      final extractDir = Directory('${tempDir.path}\\benefit_scheme_update_extracted');
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
      await extractDir.create();

      final bytes = await downloadFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File('${extractDir.path}\\$filename');
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(data);
        } else {
          await Directory('${extractDir.path}\\$filename').create(recursive: true);
        }
      }

      // Prepare update.bat script
      // It will ping localhost to wait a few seconds, copy the extracted files to the current directory, and launch the new exe.
      final currentExePath = Platform.resolvedExecutable;
      final currentAppDir = File(currentExePath).parent.path;
      
      final batFile = File('${tempDir.path}\\update_app.bat');
      final batContent = '''
@echo off
setlocal
set "retries=0"
echo Waiting for app to close... > "%temp%\\benefit_update_log.txt"

:retry
ping 127.0.0.1 -n 2 > nul
xcopy /s /e /y "${extractDir.path}\\*" "$currentAppDir\\" >> "%temp%\\benefit_update_log.txt" 2>&1
if %errorlevel% equ 0 goto success
set /a retries+=1
if %retries% geq 15 goto fail
echo File locked, retrying... >> "%temp%\\benefit_update_log.txt"
goto retry

:fail
echo Update failed after multiple retries. >> "%temp%\\benefit_update_log.txt"
exit

:success
echo Starting app... >> "%temp%\\benefit_update_log.txt"
start "" "$currentExePath"
del "%~f0"
''';
      await batFile.writeAsString(batContent);

      // Execute the script as Administrator using PowerShell to bypass Program Files restrictions
      Process.run('powershell', [
        '-Command',
        'Start-Process', 'cmd', '-ArgumentList', '"/c \\"${batFile.path}\\""', '-Verb', 'RunAs', '-WindowStyle', 'Hidden'
      ]);

      // Exit the app so files can be overwritten
      exit(0);

    } catch (e) {
      debugPrint('Error installing update: $e');
      throw Exception('Failed to install update: $e');
    }
  }

  static bool _isNewerVersion(String current, String latest) {
    final currentClean = current.split('+').first;
    final latestClean = latest.split('+').first;
    
    final currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latestParts = latestClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    for (int i = 0; i < 3; i++) {
      final currPart = i < currentParts.length ? currentParts[i] : 0;
      final latPart = i < latestParts.length ? latestParts[i] : 0;
      if (latPart > currPart) return true;
      if (latPart < currPart) return false;
    }
    return false;
  }
}
