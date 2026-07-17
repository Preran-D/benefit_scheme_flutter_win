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
import '../payments/payment_cart_panel.dart';

class NewPaymentIntent extends Intent {
  const NewPaymentIntent();
}

class _NewPaymentAction extends Action<NewPaymentIntent> {
  final BuildContext context;
  _NewPaymentAction(this.context);

  @override
  Object? invoke(NewPaymentIntent intent) {
    showDialog(
      context: context,
      builder: (context) => PaymentCartPanel(
        onConfirm: () {
          Navigator.pop(context);
        },
      ),
    );
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
  bool _isHoveringFab = false;

  @override
  void initState() {
    super.initState();
    _checkUpdates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => PaymentCartPanel(
            isAutoOpened: true,
            onConfirm: () {
              Navigator.pop(context);
            },
          ),
        );
      }
    });
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
        floatingActionButton: MouseRegion(
          onEnter: (_) => setState(() => _isHoveringFab = true),
          onExit: (_) => setState(() => _isHoveringFab = false),
          child: FloatingActionButton.extended(
            onPressed: () {
               showDialog(
                 context: context,
                 builder: (context) => PaymentCartPanel(
                   onConfirm: () {
                     Navigator.pop(context);
                   },
                 ),
               );
            },
            icon: const Icon(Icons.add),
            label: const Text('Record'),
            isExtended: _isHoveringFab,
          ),
        ),
        body: Column(
          children: [
            // Top Navigation Bar (Glassmorphism)
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, top: 24),
              child: _buildGlassPill(
                primaryColor: primaryColor,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Logo
                        Icon(Icons.group, color: primaryColor, size: 24),
                        
                        // Right: Controls
                        Row(
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
                      ],
                    ),
                    
                    // Center: Mega Menu
                    _buildMegaMenu(selectedIndex, primaryColor),
                  ],
                ),
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 32.0, right: 32.0, top: 16.0, bottom: 24.0),
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

  Widget _buildMegaMenu(int selectedIndex, Color primaryColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MegaMenuItem(
          title: 'Customers',
          isSelected: selectedIndex == 0,
          primaryColor: primaryColor,
          dropdownItems: [
            _MegaMenuDropdownItem(
              title: 'All Customers',
              icon: Icons.people_outline,
              description: 'View and manage all your customers',
              onTap: () => context.go('/customers?view=list'),
            ),
            _MegaMenuDropdownItem(
              title: 'Summary',
              icon: Icons.pie_chart_outline,
              description: 'Analytics and overview of customer data',
              onTap: () => context.go('/customers?view=summary'),
            ),
          ],
        ),
        const SizedBox(width: 16),
        _MegaMenuItem(
          title: 'Daybook',
          isSelected: selectedIndex == 1,
          primaryColor: primaryColor,
          dropdownItems: [
            _MegaMenuDropdownItem(
              title: 'Daily Payments',
              icon: Icons.today,
              description: 'Track today\'s incoming payments',
              onTap: () => context.go('/payments?view=daily'),
            ),
            _MegaMenuDropdownItem(
              title: 'All Payments',
              icon: Icons.history,
              description: 'Complete history of all transactions',
              onTap: () => context.go('/payments?view=all'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MegaMenuItem extends StatefulWidget {
  final String title;
  final bool isSelected;
  final Color primaryColor;
  final List<_MegaMenuDropdownItem> dropdownItems;

  const _MegaMenuItem({
    required this.title,
    required this.isSelected,
    required this.primaryColor,
    required this.dropdownItems,
  });

  @override
  State<_MegaMenuItem> createState() => _MegaMenuItemState();
}

class _MegaMenuItemState extends State<_MegaMenuItem> {
  final MenuController _menuController = MenuController();
  Timer? _closeTimer;

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, 10),
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(Colors.white),
        elevation: WidgetStateProperty.all(12),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
        )),
        padding: WidgetStateProperty.all(const EdgeInsets.all(16)),
      ),
      menuChildren: [
        MouseRegion(
          onEnter: (_) => _closeTimer?.cancel(),
          onExit: (_) {
            _closeTimer = Timer(const Duration(milliseconds: 200), () {
              if (_menuController.isOpen) _menuController.close();
            });
          },
          child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 12, top: 8),
                child: Text(
                  widget.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.grey[500],
                  ),
                ),
              ),
              ...widget.dropdownItems.map((item) => _buildDropdownCard(item)),
            ],
          ),
        ),
        ),
      ],
      builder: (context, controller, child) {
        return InkWell(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          onHover: (isHovering) {
            if (isHovering) {
              _closeTimer?.cancel();
              if (!controller.isOpen) controller.open();
            } else {
              _closeTimer = Timer(const Duration(milliseconds: 200), () {
                if (controller.isOpen) controller.close();
              });
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: widget.isSelected ? widget.primaryColor : Colors.grey[700],
                    fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: widget.isSelected ? widget.primaryColor : Colors.grey[500],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdownCard(_MegaMenuDropdownItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          _menuController.close();
          item.onTap();
        },
        borderRadius: BorderRadius.circular(16),
        hoverColor: widget.primaryColor.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(item.icon, color: widget.primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MegaMenuDropdownItem {
  final String title;
  final IconData icon;
  final String description;
  final VoidCallback onTap;

  _MegaMenuDropdownItem({
    required this.title,
    required this.icon,
    required this.description,
    required this.onTap,
  });
}
