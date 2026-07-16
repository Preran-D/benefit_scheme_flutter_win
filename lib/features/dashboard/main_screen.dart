import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:intl/intl.dart';

import '../../services/printer/printer_service.dart';
import '../../providers/providers.dart';
import '../../services/update_service.dart';

class NewPaymentIntent extends Intent {
  const NewPaymentIntent();
}

class _NewPaymentAction extends Action<NewPaymentIntent> {
  final BuildContext context;
  _NewPaymentAction(this.context);

  @override
  Object? invoke(NewPaymentIntent intent) {
    context.push('/add_payment_shortcut');
    return null;
  }
}

class MainScreen extends ConsumerStatefulWidget {
  final Widget child;
  const MainScreen({super.key, required this.child});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  bool _manualConnecting = false;
  bool _showOnlineText = true;
  Timer? _onlineTimer;
  bool _hasUpdate = false;
  bool _wasReachable = false;

  @override
  void initState() {
    super.initState();
    _checkUpdates();
  }

  Future<void> _checkUpdates() async {
    try {
      final updateInfo = await UpdateService.checkForUpdate();
      if (updateInfo != null && mounted) {
        setState(() => _hasUpdate = true);
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }
  @override
  void dispose() {
    _onlineTimer?.cancel();
    super.dispose();
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/customers')) return 0;
    if (location.startsWith('/payments')) return 1;
    return 0;
  }

  void _onDestinationSelected(int index) {
    switch (index) {
      case 0:
        context.go('/customers');
        break;
      case 1:
        context.go('/payments');
        break;
    }
  }
  


  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);
    final printerState = ref.watch(printerServiceProvider);
    final syncState = ref.watch(syncControllerProvider);
    
    // Listen to printer state changes to trigger online text collapse
    ref.listen(printerServiceProvider, (previous, next) {
      if (next.isReachable && !_wasReachable) {
        setState(() {
          _manualConnecting = false;
          _showOnlineText = true;
          _wasReachable = true;
        });
        _onlineTimer?.cancel();
        _onlineTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showOnlineText = false);
        });
      } else if (!next.isReachable && _wasReachable) {
        setState(() {
          _manualConnecting = false;
          _wasReachable = false;
        });
      }
    });

    final primaryColor = Theme.of(context).colorScheme.primary;

    return FocusableActionDetector(
      autofocus: true,
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const NewPaymentIntent(),
      },
      actions: <Type, Action<Intent>>{
        NewPaymentIntent: _NewPaymentAction(context),
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            // Top Navigation Bar (Glassmorphism)
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, top: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Pill: Logo & Nav
                  _buildGlassPill(
                    primaryColor: primaryColor,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group, color: primaryColor, size: 24),
                        const SizedBox(width: 24),
                        _buildNavTabs(selectedIndex, primaryColor),
                      ],
                    ),
                  ),
                  
                  // Right Pill: Controls
                  _buildGlassPill(
                    primaryColor: primaryColor,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sync Button
                        Tooltip(
                          message: 'Synced ${DateFormat.jm().format(syncState.lastSync)}',
                          child: IconButton(
                            onPressed: syncState.isSyncing 
                              ? null 
                              : () => ref.read(syncControllerProvider.notifier).syncNow(),
                            icon: syncState.isSyncing 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                              : Icon(Icons.sync, color: primaryColor, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: syncState.isSyncing ? Colors.orange.withValues(alpha: 0.1) : primaryColor.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Printer Status Indicator
                        InkWell(
                          onTap: printerState.isReachable || _manualConnecting ? null : () {
                             setState(() => _manualConnecting = true);
                             Future.delayed(const Duration(seconds: 2), () {
                               if (mounted && !ref.read(printerServiceProvider).isReachable) {
                                 setState(() => _manualConnecting = false);
                               }
                             });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: printerState.isReachable 
                                  ? Colors.green.withValues(alpha: 0.1) 
                                  : (_manualConnecting ? Colors.orange.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_manualConnecting && !printerState.isReachable)
                                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                                else
                                  Icon(
                                    printerState.isReachable ? Icons.print : Icons.print_disabled, 
                                    size: 16, 
                                    color: printerState.isReachable ? Colors.green : Colors.red
                                  ),
                                
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  child: (_manualConnecting && !printerState.isReachable) || (printerState.isReachable && _showOnlineText)
                                    ? Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: Text(
                                          _manualConnecting && !printerState.isReachable ? 'Connecting...' : 'Online',
                                          style: TextStyle(
                                            color: _manualConnecting && !printerState.isReachable ? Colors.orange[800] : Colors.green[800],
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Menu Dropdown
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: primaryColor),
                          offset: const Offset(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tooltip: 'Menu',
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'update',
                              child: Row(
                                children: [
                                  Badge(
                                    isLabelVisible: _hasUpdate,
                                    child: Icon(Icons.system_update_alt_rounded, color: primaryColor, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Check for Updates'),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'logout',
                              child: Row(
                                children: [
                                  Icon(Icons.logout, color: Colors.red, size: 20),
                                  SizedBox(width: 12),
                                  Text('Logout', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'update') {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const AlertDialog(
                                  content: Row(
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(width: 20),
                                      Text('Checking for updates...'),
                                    ],
                                  ),
                                ),
                              );

                              final updateInfo = await UpdateService.checkForUpdate();
                              if (context.mounted) Navigator.pop(context); // close dialog

                              if (updateInfo != null && context.mounted) {
                                final bool? shouldUpdate = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Update Available'),
                                    content: Text('Version ${updateInfo['version']} is available. Do you want to download and install it now?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
                                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Update Now')),
                                    ],
                                  ),
                                );

                                if (shouldUpdate == true && context.mounted) {
                                  // Show progress dialog
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const AlertDialog(
                                      content: Row(
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(width: 20),
                                          Text('Downloading update... Please wait.'),
                                        ],
                                      ),
                                    ),
                                  );

                                  try {
                                    await UpdateService.downloadAndInstallUpdate(updateInfo['url']!, (progress) {});
                                  } catch (e) {
                                    if (context.mounted) {
                                      Navigator.pop(context); // close progress dialog
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
                                    }
                                  }
                                }
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are already on the latest version!')));
                              }
                            } else if (value == 'logout') {
                              await Supabase.instance.client.auth.signOut();
                              if (context.mounted) {
                                context.go('/login');
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassPill({required Widget child, required Color primaryColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildNavTabs(int selectedIndex, Color primaryColor) {
    const tabWidth = 110.0;
    return Stack(
      children: [
        // The sliding pill
        AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          left: selectedIndex * tabWidth,
          top: 0,
          bottom: 0,
          width: tabWidth,
          child: Container(
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        // The clickable text items on top
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNavTabItem('Customers', 0, selectedIndex, tabWidth),
            _buildNavTabItem('Daybook', 1, selectedIndex, tabWidth),
          ],
        ),
      ],
    );
  }

  Widget _buildNavTabItem(String label, int index, int selectedIndex, double width) {
    final isSelected = index == selectedIndex;
    return InkWell(
      onTap: () => _onDestinationSelected(index),
      borderRadius: BorderRadius.circular(20),
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: width,
        height: 36,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600]!,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
