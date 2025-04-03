import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ReceiptDetailsScreen extends StatefulWidget {
  final String billId;

  const ReceiptDetailsScreen({super.key, required this.billId});

  @override
  _ReceiptDetailsScreenState createState() => _ReceiptDetailsScreenState();
}

class _ReceiptDetailsScreenState extends State<ReceiptDetailsScreen> {
  Map<String, double> categoryTotals = {};
  String title = "";
  double totalAmount = 0.0;
  Timestamp? timestamp;

  @override
  void initState() {
    super.initState();
    _fetchReceiptDetails();
  }

  Future<void> _fetchReceiptDetails() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("bills")
          .doc(widget.billId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        setState(() {
          title = data["title"] ?? "Unknown Receipt";
          totalAmount = (data["totalAmount"] is int)
              ? (data["totalAmount"] as int).toDouble()
              : (data["totalAmount"] ?? 0.0);
          timestamp = data["timestamp"];

          // Extract category totals
          categoryTotals = {};
          List<dynamic> categories = data["categories"] ?? [];

          for (var category in categories) {
            String categoryName = category["category"];
            double total = (category["total"] is int)
                ? (category["total"] as int).toDouble()
                : (category["total"] ?? 0.0);
            categoryTotals[categoryName] = total;
          }
        });
      }
    } catch (e) {
      print("❌ Error fetching receipt details: $e");
    }
  }

  Widget _buildBarChart() {
    if (categoryTotals.isEmpty) {
      return Center(
        child: Text(
          "No data to display.",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: BarChart(
        BarChartData(
          maxY: categoryTotals.values.reduce((a, b) => a > b ? a : b) +
              2, // Add padding
          barGroups: categoryTotals.entries.map((entry) {
            int index = categoryTotals.keys.toList().indexOf(entry.key);
            return BarChartGroupData(
              x: index,
              barsSpace: 8, // Spacing between bars
              barRods: [
                BarChartRodData(
                  toY: entry.value,
                  width: 24,
                  gradient: LinearGradient(
                    colors: [Colors.blueAccent, Colors.cyanAccent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 2,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: Text(
                      "\$${value.toInt()}",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() < categoryTotals.length) {
                    return Transform.rotate(
                      angle: -0.5,
                      child: Text(
                        categoryTotals.keys.elementAt(value.toInt()),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    );
                  }
                  return Container();
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            checkToShowHorizontalLine: (value) =>
                value % 2 == 0, // Show lines at even values
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: false, // Hide default border
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  "${categoryTotals.keys.elementAt(group.x)}: \$${rod.toY.toStringAsFixed(2)}",
                  TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                );
              },
            ),
            touchCallback: (event, response) {
              if (event.isInterestedForInteractions &&
                  response != null &&
                  response.spot != null) {
                int index = response.spot!.touchedBarGroupIndex;
                String category = categoryTotals.keys.elementAt(index);
                print("Clicked on category: $category");
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Receipt Details"),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Title: $title",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            Text(
              "Total Amount: \$${totalAmount.toStringAsFixed(2)}",
              style: TextStyle(fontSize: 16, color: Colors.green),
            ),
            if (timestamp != null)
              Text(
                "Date: ${timestamp!.toDate()}",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            SizedBox(height: 20),
            Text(
              "Category Breakdown",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            Expanded(child: _buildBarChart()), // Bar Chart
          ],
        ),
      ),
      backgroundColor: Colors.black,
    );
  }
}
