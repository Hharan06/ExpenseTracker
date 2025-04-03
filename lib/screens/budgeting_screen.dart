import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class BudgetingScreen extends StatefulWidget {
  @override
  _BudgetingScreenState createState() => _BudgetingScreenState();
}

class _BudgetingScreenState extends State<BudgetingScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  String monthYear = "";
  Map<String, dynamic>? monthlyBudget;
  List<Map<String, dynamic>> categories = [];

  @override
  void initState() {
    super.initState();
    monthYear = _getCurrentMonthYear();
    _loadBudgets();
  }

  void _showBudgetOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choose an Option'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.account_balance_wallet, color: Colors.blue),
              title: Text('Set Monthly Budget'),
              onTap: () {
                Navigator.pop(context);
                _showAddBudgetDialog(); // Open Monthly Budget Dialog
              },
            ),
            ListTile(
              leading: Icon(Icons.category, color: Colors.green),
              title: Text('Add Category Budget'),
              onTap: () {
                Navigator.pop(context);
                _showAddCategoryDialog(); // Open Category Budget Dialog
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBudgets() async {
    var budgetData = await _firebaseService.getMonthlyBudget(monthYear);
    var categoryData = await _firebaseService.getCategoryBudgets(monthYear);
    double totalSpent = await _getMonthlyExpenses(monthYear);

    for (var category in categoryData) {
      double categorySpent = await _firebaseService.getCategoryMonthlyExpense(
          monthYear, category['category']);
      category['budget'] = category['budget'];
      category['spent'] = categorySpent;
      category['available'] = category['budget'] - categorySpent;
    }

    setState(() {
      monthlyBudget = budgetData ?? {'totalBudget': 0, 'availableBudget': 0};
      monthlyBudget!['totalSpent'] = totalSpent;
      monthlyBudget!['availableBudget'] =
          (monthlyBudget!['totalBudget'] ?? 0) - totalSpent;
      categories = categoryData;
    });
  }

  String _getCurrentMonthYear() {
    List<String> monthNames = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    DateTime now = DateTime.now();
    return "${monthNames[now.month - 1]} ${now.year}";
  }

  Future<double> _getMonthlyExpenses(String monthYear) async {
    QuerySnapshot querySnapshot =
        await FirebaseFirestore.instance.collection('transactions').get();

    double totalSpent = 0.0;
    for (var doc in querySnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['transactionType'] == "Expense") {
        DateTime transactionDate = DateTime.parse(data['date']);
        String transactionMonthYear =
            "${_getCurrentMonthName(transactionDate.month)} ${transactionDate.year}";

        if (transactionMonthYear == monthYear) {
          totalSpent += double.tryParse(data['amount'].toString()) ?? 0.0;
        }
      }
    }
    return totalSpent;
  }

  String _getCurrentMonthName(int month) {
    List<String> monthNames = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    return monthNames[month - 1];
  }

  void _showAddBudgetDialog() {
    TextEditingController budgetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Monthly Budget'),
        content: TextField(
          controller: budgetController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: "Enter budget amount"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () async {
              double amount = double.tryParse(budgetController.text) ?? 0;
              if (amount > 0) {
                await _firebaseService.addMonthlyBudget(amount, monthYear);
                _loadBudgets();
              }
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    TextEditingController categoryController = TextEditingController();
    TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Category Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: categoryController,
              decoration: InputDecoration(hintText: "Enter category name"),
            ),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: "Enter budget amount"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () async {
              String category = categoryController.text.trim();
              double amount = double.tryParse(amountController.text) ?? 0;
              if (category.isNotEmpty && amount > 0) {
                await _firebaseService.addCategoryBudget(
                    monthYear, category, amount);
                _loadBudgets();
              }
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar:
          AppBar(title: Text("Budget Analysis"), backgroundColor: Colors.black),
      body: monthlyBudget == null
          ? Center(
              child: Text("No budget set. Tap + to add a budget.",
                  style: TextStyle(color: Colors.white)),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Budget Overview
                  Card(
                    color: Colors.grey[900],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("$monthYear",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18)),
                          SizedBox(height: 8),
                          Text("Budget: ₹${monthlyBudget!['totalBudget']}",
                              style: TextStyle(color: Colors.grey)),
                          SizedBox(height: 16),
                          Text("Total Spent: ₹${monthlyBudget!['totalSpent']}",
                              style: TextStyle(color: Colors.red)),
                          Text(
                              "Available Budget: ₹${monthlyBudget!['availableBudget']}",
                              style: TextStyle(color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Category Budgets
                  Expanded(
                    child: ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        var category = categories[index];
                        return Card(
                          color: Colors.grey[850],
                          margin: EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(category['category'],
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Budget: ₹${category['budget']}",
                                    style: TextStyle(color: Colors.grey)),
                                Text("Spent: ₹${category['spent']}",
                                    style: TextStyle(color: Colors.red)),
                                Text("Available: ₹${category['available']}",
                                    style: TextStyle(color: Colors.green)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: Icon(Icons.add),
        onPressed: () {
          _showBudgetOptionsDialog();
        },
      ),
    );
  }
}
