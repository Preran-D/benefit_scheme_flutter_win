import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

import '../../services/update_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.print),
            title: Text('Printer Settings'),
            subtitle: Text('Configure default receipt printer'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.sync),
            title: Text('Force Sync'),
            subtitle: Text('Sync local SQLite with Supabase cloud'),
          ),
          const Divider(),
          if (Platform.isWindows)
            ListTile(
              leading: const Icon(Icons.update),
              title: const Text('Check for Updates'),
              subtitle: const Text('Check and download the latest version'),
              onTap: () => _checkForUpdates(context),
            ),
          if (Platform.isWindows) const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Checking for updates...'),
          ],
        ),
      ),
    );

    final updateInfo = await UpdateService.checkForUpdate();
    
    if (context.mounted) {
      Navigator.of(context).pop(); // Dismiss checking dialog
    }

    if (updateInfo != null && context.mounted) {
      final shouldUpdate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Available'),
          content: Text('Version ${updateInfo['version']} is available. Do you want to download and install it now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Update Now'),
            ),
          ],
        ),
      );

      if (shouldUpdate == true && context.mounted) {
        _startUpdate(context, updateInfo['url']!);
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App is up to date.')),
      );
    }
  }

  void _startUpdate(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            double progress = 0.0;
            
            // Start download once
            if (progress == 0.0) {
              UpdateService.downloadAndInstallUpdate(url, (p) {
                setState(() => progress = p);
              }).catchError((e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e')),
                  );
                }
              });
            }

            return AlertDialog(
              title: const Text('Downloading Update...'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  Text('${(progress * 100).toStringAsFixed(1)}% completed'),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
