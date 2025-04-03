import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'receipt_details_screen.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  _ReceiptsScreenState createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("Receipts", style: TextStyle(fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Saved Receipts",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _firebaseService.getBills(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.isEmpty) {
                    return Center(
                        child: Text("No receipts found",
                            style: TextStyle(color: Colors.white)));
                  }
                  return ListView(
                    children: snapshot.data!.map((receipt) {
                      return _receiptCard(
                        receipt['billId'],
                        receipt['timestamp'],
                        receipt['categories'],
                        receipt['totalAmount'],
                        receipt['title'],
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptCard(
      String billId,
      Timestamp? timestamp,
      List<dynamic> categories,
      double totalAmount,
      String title) {
    return Card(
      color: Colors.grey[900],
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total Amount: \$${totalAmount.toStringAsFixed(2)}",
                style: TextStyle(color: Colors.green)),
            Text("Categories: ${categories.length}",
                style: TextStyle(color: Colors.grey)),
            if (timestamp != null && timestamp is Timestamp)
              Text(
                "Date: ${timestamp.toDate()}",
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReceiptDetailsScreen(billId: billId),
            ),
          );
        },
      ),
    );
  }
}

extension on String {
  toDate() {}
}
