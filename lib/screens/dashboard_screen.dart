import 'package:beszel_pro/models/system.dart';
import 'package:beszel_pro/screens/system_detail_screen.dart';
import 'package:beszel_pro/services/pocketbase_service.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:beszel_pro/screens/setup_screen.dart';
import 'package:beszel_pro/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beszel_pro/screens/login_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:beszel_pro/services/notification_service.dart';
import 'package:beszel_pro/services/alert_manager.dart';
import 'package:beszel_pro/screens/alerts_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<System> _systems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    NotificationService().initialize();
    AlertManager().loadAlerts();
    _fetchSystems();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _unsubscribeFromRealtime();
    super.dispose();
  }

  Future<void> _fetchSystems() async {
    try {
      final pb = PocketBaseService().pb;
      final records = await pb.collection('systems').getFullList(
            sort: '-updated',
          );

      if (records.isNotEmpty) {
        debugPrint('SYSTEM RECORD RAW DATA: ${records.first.data}');
      }

      if (mounted) {
        setState(() {
          _systems = records.map((r) => System.fromRecord(r)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load systems: $e';
          _isLoading = false;
        });
      }
    }
  }



  // ... 

  Future<void> _subscribeToRealtime() async {
    try {
      final pb = PocketBaseService().pb;
      pb.collection('systems').subscribe('*', (e) {
        if (!mounted) return;

        if (e.action == 'create') {
          setState(() {
            _systems.insert(0, System.fromRecord(e.record!));
          });
        } else if (e.action == 'update') {
          // debugPrint('REALTIME UPDATE: ${e.record!.data}');
          final updatedSystem = System.fromRecord(e.record!);
          
          setState(() {
            final index = _systems.indexWhere((s) => s.id == e.record!.id);
            if (index != -1) {
              final oldSystem = _systems[index];
              
              // 1. Check for DOWN status
              if (oldSystem.status == 'up' && updatedSystem.status == 'down') {
                _triggerAlert(
                  updatedSystem, 
                  tr('alert_system_down_title'), 
                  tr('alert_system_down_body', args: [updatedSystem.name]),
                  'error'
                );
              }

              // 2. Check for High Resource Usage (e.g. > 90%)
              if (updatedSystem.cpuPercent > 90 && oldSystem.cpuPercent <= 90) {
                 _triggerAlert(
                  updatedSystem, 
                  tr('alert_high_cpu_title'), 
                  tr('alert_high_cpu_body', args: [updatedSystem.name, updatedSystem.cpuPercent.toStringAsFixed(1)]),
                  'warning'
                );
              }
              
              if (updatedSystem.diskPercent > 90 && oldSystem.diskPercent <= 90) {
                 _triggerAlert(
                  updatedSystem, 
                  tr('alert_high_disk_title'), 
                  tr('alert_high_disk_body', args: [updatedSystem.name, updatedSystem.diskPercent.toStringAsFixed(1)]),
                  'warning'
                );
              }

              _systems[index] = updatedSystem;
            }
          });
        } else if (e.action == 'delete') {
          setState(() {
            _systems.removeWhere((s) => s.id == e.record!.id);
          });
        }
      });
    } catch (e) {
      debugPrint('Realtime subscription failed: $e');
    }
  }

  void _triggerAlert(System system, String title, String body, String type) {
    // Show local notification
    NotificationService().showNotification(
      id: system.id.hashCode, 
      title: title, 
      body: body
    );
    
    // Save to history
    AlertManager().addAlert(title, body, type, system.name);
  }

  Future<void> _unsubscribeFromRealtime() async {
    try {
      final pb = PocketBaseService().pb;
      await pb.collection('systems').unsubscribe('*');
    } catch (_) {}
  }

  void _logout() async {
    final pb = PocketBaseService().pb;
    pb.authStore.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pb_url');

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SetupScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('dashboard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
               Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AlertsScreen()),
              );
            },
            tooltip: 'Alerts',
          ),
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
            tooltip: 'Select Language',
            onSelected: (Locale locale) {
              context.setLocale(locale);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<Locale>>[
              const PopupMenuItem<Locale>(
                value: Locale('en'),
                child: Row(
                  children: [
                    Text('🇺🇸 English'),
                  ],
                ),
              ),
              const PopupMenuItem<Locale>(
                value: Locale('ru'),
                child: Row(
                  children: [
                    Text('🇷🇺 Русский'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              Provider.of<AppProvider>(context).themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              final provider = Provider.of<AppProvider>(context, listen: false);
              provider.toggleTheme(
                  provider.themeMode != ThemeMode.dark); 
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: tr('logout'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _systems.length,
                  itemBuilder: (context, index) {
                    final system = _systems[index];
                    return _SystemCard(system: system);
                  },
                ),
    );
  }
}

class _SystemCard extends StatelessWidget {
  final System system;

  const _SystemCard({required this.system});

  Color _getStatusColor(double usage) {
    if (usage < 50) return Colors.green;
    if (usage < 80) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SystemDetailScreen(system: system),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      system.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: system.status == 'up' ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      system.status.toUpperCase(),
                      style: TextStyle(
                        color: system.status == 'up' ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(system.host, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(tr('cpu'), system.cpuPercent, Icons.memory),
                  _buildStat(tr('ram'), system.memoryPercent, Icons.storage),
                  _buildStat(tr('disk'), system.diskPercent, Icons.donut_large),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, double value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: _getStatusColor(value), size: 24),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(1)}%',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
