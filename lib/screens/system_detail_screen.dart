import 'package:beszel_pro/models/system.dart';
import 'package:beszel_pro/services/pocketbase_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class SystemDetailScreen extends StatefulWidget {
  final System system;

  const SystemDetailScreen({super.key, required this.system});

  @override
  State<SystemDetailScreen> createState() => _SystemDetailScreenState();
}

class _SystemDetailScreenState extends State<SystemDetailScreen> {
  // Selected category: 0=CPU, 1=Memory, 2=Disk, 3=Network
  int _selectedCategory = 0;

  // Chart data
  List<FlSpot> _cpuSpots = [];
  List<FlSpot> _ramSpots = [];
  List<FlSpot> _diskSpots = [];
  List<FlSpot> _netSpots = [];

  // Latest stats from system_stats
  Map<String, dynamic>? _latestStats;

  // Per-core CPU usage
  List<int> _cpuCoresUsage = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _unsubscribeFromRealtime();
    super.dispose();
  }

  Future<void> _subscribeToRealtime() async {
    try {
      final pb = PocketBaseService().pb;
      await pb.collection('systems').subscribe(widget.system.id, (e) {
        if (!mounted) return;
        if (e.action == 'update') {
          final updatedSystem = System.fromRecord(e.record!);
          final now = DateTime.now().millisecondsSinceEpoch.toDouble();

          setState(() {
            _addSpot(_cpuSpots, now, updatedSystem.cpuPercent);
            _addSpot(_ramSpots, now, updatedSystem.memoryPercent);
            _addSpot(_diskSpots, now, updatedSystem.diskPercent);

            // Update network from info['bb']
            if (updatedSystem.info['bb'] != null &&
                updatedSystem.info['bb'] is num) {
              _addSpot(
                _netSpots,
                now,
                (updatedSystem.info['bb'] as num).toDouble() / 1024,
              ); // KB/s
            }
          });
        }
      });

      // Also subscribe to system_stats for detailed data
      await pb.collection('system_stats').subscribe('*', (e) {
        if (!mounted) return;
        if (e.action == 'create' &&
            e.record?.data['system'] == widget.system.id) {
          final stats = e.record?.data['stats'];
          if (stats != null) {
            setState(() {
              _latestStats = stats;
              // Update per-core CPU usage
              if (stats['cpus'] != null && stats['cpus'] is List) {
                _cpuCoresUsage = (stats['cpus'] as List)
                    .map((v) => (v is num) ? v.toInt() : 0)
                    .toList();
              }
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Subscription failed: $e');
    }
  }

  Future<void> _unsubscribeFromRealtime() async {
    try {
      final pb = PocketBaseService().pb;
      await pb.collection('systems').unsubscribe(widget.system.id);
      await pb.collection('system_stats').unsubscribe('*');
    } catch (_) {}
  }

  void _addSpot(List<FlSpot> spots, double x, double y) {
    spots.add(FlSpot(x, y));
    if (spots.length > 60) {
      spots.removeAt(0);
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final pb = PocketBaseService().pb;
      final records = await pb
          .collection('system_stats')
          .getList(
            page: 1,
            perPage: 60,
            filter: 'system = "${widget.system.id}"',
            sort: '-created',
          );

      final reversed = records.items.reversed.toList();

      List<FlSpot> cpu = [];
      List<FlSpot> ram = [];
      List<FlSpot> disk = [];
      List<FlSpot> net = [];

      for (var r in reversed) {
        final DateTime time = DateTime.parse(r.created).toLocal();
        final double xVal = time.millisecondsSinceEpoch.toDouble();

        double getDouble(dynamic val) {
          if (val is int) return val.toDouble();
          if (val is double) return val;
          if (val is String) return double.tryParse(val) ?? 0.0;
          return 0.0;
        }

        double extract(String key) {
          if (r.data['stats'] is Map) {
            final s = r.data['stats'];
            if (s.containsKey(key)) return getDouble(s[key]);
          }
          return 0.0;
        }

        cpu.add(FlSpot(xVal, extract('cpu')));
        ram.add(FlSpot(xVal, extract('mp')));
        disk.add(FlSpot(xVal, extract('dp')));

        // Network: ns + nr (bytes/s to KB/s)
        double netVal = (extract('ns') + extract('nr')) / 1024;
        net.add(FlSpot(xVal, netVal));
      }

      // Get latest stats for detailed view
      if (records.items.isNotEmpty) {
        final latest = records.items.first.data['stats'];
        if (latest != null) {
          _latestStats = latest;
          if (latest['cpus'] != null && latest['cpus'] is List) {
            _cpuCoresUsage = (latest['cpus'] as List)
                .map((v) => (v is num) ? v.toInt() : 0)
                .toList();
          }
        }
      }

      if (mounted) {
        setState(() {
          _cpuSpots = cpu;
          _ramSpots = ram;
          _diskSpots = disk;
          _netSpots = net;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint("Error fetching history: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(title: Text(widget.system.name), elevation: 0),
      body: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Sidebar
        SizedBox(width: 140, child: _buildSidebar()),
        const VerticalDivider(width: 1),
        // Main content
        Expanded(child: _buildMainPanel()),
      ],
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // Horizontal category tabs
        SizedBox(height: 80, child: _buildHorizontalTabs()),
        const Divider(height: 1),
        // Main content
        Expanded(child: _buildMainPanel()),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSidebarItem(0, Icons.memory, 'CPU', widget.system.cpuPercent),
          _buildSidebarItem(
            1,
            Icons.storage,
            tr('ram'),
            widget.system.memoryPercent,
          ),
          _buildSidebarItem(
            2,
            Icons.disc_full,
            tr('disk'),
            widget.system.diskPercent,
          ),
          _buildSidebarItem(3, Icons.network_check, tr('network'), null),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    int index,
    IconData icon,
    String label,
    double? value,
  ) {
    final isSelected = _selectedCategory == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.7);

    return InkWell(
      onTap: () => setState(() => _selectedCategory = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
              : null,
          border: isSelected
              ? Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
            if (value != null) ...[
              const SizedBox(height: 4),
              Text(
                '${value.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: value / 100,
                backgroundColor: Colors.grey.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation(_getUsageColor(value)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalTabs() {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      children: [
        _buildTabItem(0, Icons.memory, 'CPU', widget.system.cpuPercent),
        _buildTabItem(1, Icons.storage, tr('ram'), widget.system.memoryPercent),
        _buildTabItem(
          2,
          Icons.disc_full,
          tr('disk'),
          widget.system.diskPercent,
        ),
        _buildTabItem(3, Icons.network_check, tr('network'), null),
      ],
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, double? value) {
    final isSelected = _selectedCategory == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 90,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (value != null)
                Text(
                  '${value.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainPanel() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_selectedCategory) {
      case 0:
        return _buildCpuPanel();
      case 1:
        return _buildMemoryPanel();
      case 2:
        return _buildDiskPanel();
      case 3:
        return _buildNetworkPanel();
      default:
        return _buildCpuPanel();
    }
  }

  Widget _buildCpuPanel() {
    // Get CPU model from system info
    String cpuModel = widget.system.info['m']?.toString() ?? 'Unknown';
    int cores = widget.system.info['c'] is num
        ? (widget.system.info['c'] as num).toInt()
        : 0;
    int threads = widget.system.info['t'] is num
        ? (widget.system.info['t'] as num).toInt()
        : 0;

    // Uptime
    int uptimeSeconds = widget.system.info['u'] is num
        ? (widget.system.info['u'] as num).toInt()
        : 0;
    String uptime = _formatUptime(uptimeSeconds);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'CPU',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  cpuModel,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '60 ${tr('seconds')} ${tr('utilization')} %',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // Main chart
          _buildMiniChart(_cpuSpots, Colors.blue, isPercent: true, height: 150),
          const SizedBox(height: 24),

          // Per-core CPU grid
          if (_cpuCoresUsage.isNotEmpty) ...[
            Text(
              'CPU ${tr('cores')}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildCpuCoreGrid(),
            const SizedBox(height: 24),
          ],

          // Stats grid
          _buildStatsGrid([
            _StatItem(
              tr('utilization'),
              '${widget.system.cpuPercent.toStringAsFixed(1)}%',
            ),
            _StatItem(tr('cores'), cores.toString()),
            _StatItem(tr('threads'), threads.toString()),
            _StatItem(tr('uptime'), uptime),
          ]),
        ],
      ),
    );
  }

  Widget _buildMemoryPanel() {
    double memTotal = _latestStats?['m'] is num
        ? (_latestStats!['m'] as num).toDouble()
        : 0;
    double memUsed = _latestStats?['mu'] is num
        ? (_latestStats!['mu'] as num).toDouble()
        : 0;
    double memBuffCache = _latestStats?['mb'] is num
        ? (_latestStats!['mb'] as num).toDouble()
        : 0;
    double swapTotal = _latestStats?['s'] is num
        ? (_latestStats!['s'] as num).toDouble()
        : 0;
    double swapUsed = _latestStats?['su'] is num
        ? (_latestStats!['su'] as num).toDouble()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('ram'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${memUsed.toStringAsFixed(2)} / ${memTotal.toStringAsFixed(2)} GB',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          _buildMiniChart(
            _ramSpots,
            Colors.purple,
            isPercent: true,
            height: 150,
          ),
          const SizedBox(height: 24),

          _buildStatsGrid([
            _StatItem(tr('total'), '${memTotal.toStringAsFixed(2)} GB'),
            _StatItem(tr('used'), '${memUsed.toStringAsFixed(2)} GB'),
            _StatItem('Buffer/Cache', '${memBuffCache.toStringAsFixed(2)} GB'),
            _StatItem(
              tr('utilization'),
              '${widget.system.memoryPercent.toStringAsFixed(1)}%',
            ),
            if (swapTotal > 0) ...[
              _StatItem(
                'Swap',
                '${swapUsed.toStringAsFixed(2)} / ${swapTotal.toStringAsFixed(2)} GB',
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _buildDiskPanel() {
    double diskTotal = _latestStats?['d'] is num
        ? (_latestStats!['d'] as num).toDouble()
        : 0;
    double diskUsed = _latestStats?['du'] is num
        ? (_latestStats!['du'] as num).toDouble()
        : 0;
    double diskRead = _latestStats?['dr'] is num
        ? (_latestStats!['dr'] as num).toDouble()
        : 0;
    double diskWrite = _latestStats?['dw'] is num
        ? (_latestStats!['dw'] as num).toDouble()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('disk'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${diskUsed.toStringAsFixed(2)} / ${diskTotal.toStringAsFixed(2)} GB',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          _buildMiniChart(
            _diskSpots,
            Colors.orange,
            isPercent: true,
            height: 150,
          ),
          const SizedBox(height: 24),

          _buildStatsGrid([
            _StatItem(tr('total'), '${diskTotal.toStringAsFixed(2)} GB'),
            _StatItem(tr('used'), '${diskUsed.toStringAsFixed(2)} GB'),
            _StatItem(
              tr('utilization'),
              '${widget.system.diskPercent.toStringAsFixed(1)}%',
            ),
            _StatItem('Read', '${diskRead.toStringAsFixed(2)} MB/s'),
            _StatItem('Write', '${diskWrite.toStringAsFixed(2)} MB/s'),
          ]),
        ],
      ),
    );
  }

  Widget _buildNetworkPanel() {
    double netSent = _latestStats?['ns'] is num
        ? (_latestStats!['ns'] as num).toDouble()
        : 0;
    double netRecv = _latestStats?['nr'] is num
        ? (_latestStats!['nr'] as num).toDouble()
        : 0;

    // Network interfaces
    Map<String, dynamic>? ni = _latestStats?['ni'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('network'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '↑ ${_formatBytesSpeed(netSent)}  ↓ ${_formatBytesSpeed(netRecv)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          _buildMiniChart(
            _netSpots,
            Colors.green,
            isPercent: false,
            height: 150,
          ),
          const SizedBox(height: 24),

          _buildStatsGrid([
            _StatItem('Upload', _formatBytesSpeed(netSent)),
            _StatItem('Download', _formatBytesSpeed(netRecv)),
          ]),

          // Network interfaces
          if (ni != null && ni.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Interfaces', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...ni.entries.map((e) {
              final data = e.value;
              if (data is List && data.length >= 4) {
                return Card(
                  child: ListTile(
                    title: Text(e.key),
                    subtitle: Text(
                      '↑ ${_formatBytes(data[2].toDouble())} / ↓ ${_formatBytes(data[3].toDouble())}',
                    ),
                    trailing: Text(
                      '${_formatBytesSpeed(data[0].toDouble())} / ${_formatBytesSpeed(data[1].toDouble())}',
                    ),
                  ),
                );
              }
              return const SizedBox();
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCpuCoreGrid() {
    // Calculate number of columns based on core count
    int crossAxisCount = 4;
    if (_cpuCoresUsage.length <= 2)
      crossAxisCount = 2;
    else if (_cpuCoresUsage.length <= 8)
      crossAxisCount = 4;
    else
      crossAxisCount = 4;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.8,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _cpuCoresUsage.length,
      itemBuilder: (context, index) {
        final usage = _cpuCoresUsage[index];
        final color = _getUsageColor(usage.toDouble());

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CPU $index',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$usage%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: usage / 100,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniChart(
    List<FlSpot> spots,
    Color color, {
    required bool isPercent,
    double height = 120,
  }) {
    double? maxY = isPercent ? 100 : null;
    if (!isPercent && spots.isNotEmpty) {
      maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2;
      if (maxY! < 1) maxY = 1;
    }

    return SizedBox(
      height: height,
      child: spots.isEmpty
          ? Center(child: Text(tr('no_history')))
          : LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.2),
                    ),
                  ),
                ],
                minY: 0,
                maxY: maxY,
              ),
            ),
    );
  }

  Widget _buildStatsGrid(List<_StatItem> items) {
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: items
          .map(
            (item) => SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    item.value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Color _getUsageColor(double usage) {
    if (usage < 50) return Colors.green;
    if (usage < 80) return Colors.orange;
    return Colors.red;
  }

  String _formatUptime(int seconds) {
    if (seconds <= 0) return '-';
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (days > 0) return '${days}d ${hours}h ${mins}m';
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  String _formatBytes(double bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    while (bytes >= 1024 && i < suffixes.length - 1) {
      bytes /= 1024;
      i++;
    }
    return '${bytes.toStringAsFixed(2)} ${suffixes[i]}';
  }

  String _formatBytesSpeed(double bytesPerSec) {
    return '${_formatBytes(bytesPerSec)}/s';
  }
}

class _StatItem {
  final String label;
  final String value;
  _StatItem(this.label, this.value);
}
