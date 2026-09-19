import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MuscleDonutChart extends StatelessWidget {
  final Map<String, double> volumeMap;
  const MuscleDonutChart({required this.volumeMap, super.key});

  @override
  Widget build(BuildContext context) {
    final total = volumeMap.values.fold<double>(0, (a, b) => a + b);
    final sections = volumeMap.entries.map((e) {
      final color = _colorForMuscle(e.key);
      return PieChartSectionData(
        value: e.value,
        color: color,
        radius: 50,
        title: '',
      );
    }).toList();

    final maxEntry = volumeMap.entries.isNotEmpty
        ? volumeMap.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;
    final centerPercent = maxEntry != null && total > 0
        ? (maxEntry.value / total) * 100
        : 0;

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 60,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${centerPercent.toStringAsFixed(0)}%',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Text('TRAINED', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: volumeMap.entries.map((e) {
            final percent = total > 0 ? (e.value / total) * 100 : 0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 12, color: _colorForMuscle(e.key)),
                const SizedBox(width: 4),
                Text('${e.key} ${percent.toStringAsFixed(0)}%'),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _colorForMuscle(String muscle) {
    switch (muscle.toLowerCase()) {
      case 'chest':
        return Colors.blueAccent;
      case 'back':
        return Colors.greenAccent;
      case 'legs':
        return Colors.orangeAccent;
      case 'core':
        return Colors.purpleAccent;
      case 'shoulders':
        return Colors.redAccent;
      case 'arms':
        return Colors.yellowAccent;
      default:
        return Colors.grey;
    }
  }
}
