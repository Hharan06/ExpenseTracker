import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  String _selectedType = "Expense";
  String _selectedCategory = "Food and Dining";
  String _selectedPaymentMode = "Cash";

  final List<String> transactionTypes = ["Expense", "Income", "Transfer"];
  final List<String> categories = [
    "Food and Dining",
    "Shopping",
    "Medical",
    "Entertainment",
    "Others"
  ];
  final List<String> paymentModes = ["Cash", "Bank Account"];

  Future<void> _addTransaction() async {
    if (_amountController.text.isNotEmpty &&
        _detailsController.text.isNotEmpty) {
      await _firebaseService.addTransaction(
        _amountController.text,
        _selectedType,
        _selectedCategory,
        _selectedPaymentMode,
        _detailsController.text,
      );
      Navigator.pop(context); // Go back to HomeScreen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Transaction")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Transaction Type Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: transactionTypes.map((type) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(
                      color: _selectedType == type
                          ? Colors.blue
                          : Colors.grey[800],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: _selectedType == type
                            ? Colors.white
                            : Colors.grey[400],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Amount"),
            ),
            SizedBox(height: 10),
            DropdownButtonFormField(
              value: _selectedCategory,
              items: categories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) =>
                  setState(() => _selectedCategory = value.toString()),
              decoration: InputDecoration(labelText: "Category"),
            ),
            SizedBox(height: 10),
            DropdownButtonFormField(
              value: _selectedPaymentMode,
              items: paymentModes.map((mode) {
                return DropdownMenuItem(value: mode, child: Text(mode));
              }).toList(),
              onChanged: (value) =>
                  setState(() => _selectedPaymentMode = value.toString()),
              decoration: InputDecoration(labelText: "Payment Mode"),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: InputDecoration(labelText: "Other Details"),
            ),
            SizedBox(height: 10),
            Text(
              "Date & Time: ${DateTime.now()}",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addTransaction,
              child: Text("Add Transaction"),
            ),
          ],
        ),
      ),
    );
  }
}
