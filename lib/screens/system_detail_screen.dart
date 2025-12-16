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
  List<FlSpot> _cpuSpots = [];
  List<FlSpot> _ramSpots = [];
  List<FlSpot> _diskSpots = [];
  List<FlSpot> _netSpots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final pb = PocketBaseService().pb;
      final records = await pb.collection('system_stats').getList(
        page: 1,
        perPage: 50,
        filter: 'system = "${widget.system.id}"',
        sort: '-created',
      );

      final reversed = records.items.reversed.toList();
      
      if (reversed.isNotEmpty) {
         debugPrint('SAMPLE RECORD DATA: ${reversed.last.data}');
      }

      List<FlSpot> cpu = [];
      List<FlSpot> ram = [];
      List<FlSpot> disk = [];
      List<FlSpot> net = []; // in MB/s or KB/s

      for (var r in reversed) {
        // Parse time: created is UTC string
        final DateTime time = DateTime.parse(r.created).toLocal();
        final double xVal = time.millisecondsSinceEpoch.toDouble();

        dynamic getDouble(dynamic val) {
           if (val is int) return val.toDouble();
           if (val is double) return val;
           if (val is String) return double.tryParse(val) ?? 0.0;
           return 0.0;
        }

        // Helper to extract nested values
        double extract(String key, {String? altKey}) {
           double val = 0.0;
           if (r.data.containsKey(key)) val = getDouble(r.data[key]);
           else if (altKey != null && r.data.containsKey(altKey)) val = getDouble(r.data[altKey]);
           // Check stats/info if not found
           else if (r.data['stats'] is Map) {
              final s = r.data['stats'];
              if (s.containsKey(key)) val = getDouble(s[key]);
              else if (altKey != null && s.containsKey(altKey)) val = getDouble(s[altKey]);
           } else if (r.data['info'] is Map) { // fallback
              final i = r.data['info'];
              if (i.containsKey(key)) val = getDouble(i[key]);
              else if (altKey != null && i.containsKey(altKey)) val = getDouble(i[altKey]);
           }
           return val;
        }

        double cpuVal = extract('cpu', altKey: 'cpu_percent');
        double ramVal = extract('mp', altKey: 'memory_percent');
        double diskVal = extract('dp', altKey: 'disk_percent');
        
        // Network: usually sent + recv. Beszel keys might be 'bandwidth' or 'net_sent'/'net_recv'
        // Trying 'ns' (net sent) and 'nr' (net recv) or 'sent'/'recv' if using Beszel agent.
        // Assuming MB/s for simplicity or raw bytes. If raw bytes, might need conversion.
        // Let's assume standard Beszel agent keys 'ns' (Net Sent MB) 'nr' (Net Received MB)
        double netSent = extract('ns', altKey: 'net_sent');
        double netRecv = extract('nr', altKey: 'net_recv');
        double netVal = netSent + netRecv; 

        cpu.add(FlSpot(xVal, cpuVal));
        ram.add(FlSpot(xVal, ramVal));
        disk.add(FlSpot(xVal, diskVal));
        net.add(FlSpot(xVal, netVal));
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
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint("Error fetching history: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.system.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildChartCard(tr('history_cpu'), _cpuSpots, Colors.blue, isPercent: true),
            const SizedBox(height: 16),
            _buildChartCard(tr('history_ram'), _ramSpots, Colors.purple, isPercent: true),
            const SizedBox(height: 16),
            _buildChartCard(tr('history_disk'), _diskSpots, Colors.orange, isPercent: true),
            const SizedBox(height: 16),
            _buildChartCard('${tr('history_network')} (MB/s)', _netSpots, Colors.green, isPercent: false),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, List<FlSpot> spots, Color color, {required bool isPercent}) {
    double? maxY;
    if (isPercent) maxY = 100;
    
    // For network, find simple max if not empty
    if (!isPercent && spots.isNotEmpty) {
       double maxVal = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
       maxY = maxVal + (maxVal * 0.2); // +20% buffer
       if (maxY < 1) maxY = 1;
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : spots.isEmpty
                      ? Center(child: Text(tr('no_history')))
                      : LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true, 
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                                      },
                                    )),
                                bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                         final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                                         return Padding(
                                           padding: const EdgeInsets.only(top: 8.0),
                                           child: Text(
                                             DateFormat('HH:mm').format(date),
                                             style: const TextStyle(fontSize: 10),
                                           ),
                                         );
                                      },
                                      reservedSize: 30,
                                    )),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false))),
                            borderData: FlBorderData(show: true),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: color,
                                barWidth: 3,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: color.withOpacity(0.2),
                                ),
                              ),
                            ],
                            minY: 0,
                            maxY: maxY, 
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                                    final timeStr = DateFormat('HH:mm:ss').format(date);
                                    return LineTooltipItem(
                                      '$timeStr\n${spot.y.toStringAsFixed(2)}',
                                      const TextStyle(color: Colors.white),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
