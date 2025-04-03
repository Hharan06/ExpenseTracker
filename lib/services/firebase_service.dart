import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔹 Add a new transaction to Firestore
  Future<void> addTransaction(String amount, String transactionType,
      String category, String paymentMode, String details) async {
    await _firestore.collection('transactions').add({
      'amount': amount,
      'transactionType': transactionType, // New field for transaction type
      'category': category,
      'paymentMode': paymentMode,
      'details': details,
      'date': DateTime.now().toIso8601String(),
    });
  }

  /// 🔹 Fetch all transactions, ordered by date
  Future<List<Map<String, dynamic>>> getTransactions() async {
    QuerySnapshot querySnapshot = await _firestore
        .collection('transactions')
        .orderBy('date', descending: true)
        .get();

    return querySnapshot.docs.map((doc) {
      return {
        'id': doc.id, // ✅ Include document ID for deletion
        'amount': doc['amount']?.toString() ?? "0.00", // ✅ Ensure string format
        'transactionType': doc['transactionType'] ?? "Unknown",
        'category': doc['category'] ?? "Unknown",
        'date': doc['date'] ?? "No date",
        'details': doc['details'] ?? "No details",
        'paymentMode': doc['paymentMode'] ?? "Unknown",
      };
    }).toList();
  }

  /// 🔥 Save a bill extracted from Gemini API into Firestore
  Future<void> saveBillToFirestore(
      String extractedText, String jsonResponse) async {
    try {
      // Ensure the JSON string is properly formatted
      jsonResponse = jsonResponse.trim(); // Remove any leading/trailing spaces

      // Remove Markdown-style code block if present (e.g., ```json)
      if (jsonResponse.startsWith("```json")) {
        jsonResponse =
            jsonResponse.replaceAll("```json", "").replaceAll("```", "");
      }

      // Convert JSON string to a map
      Map<String, dynamic> billData = jsonDecode(jsonResponse);

      // Save to Firestore
      await _firestore.collection("bills").add({
        "timestamp": FieldValue.serverTimestamp(), // Auto timestamp
        "title": billData["title"],
        "categories": billData["categories"], // Categorized items
        "totalAmount": billData["totalAmount"], // Total amount
      });

      print("✅ Bill successfully saved in Firestore!");
    } catch (e) {
      print("❌ Error saving bill to Firestore: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getBills() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection("bills")
          .orderBy("timestamp", descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        return {
          "billId": doc.id,
          "timestamp": doc["timestamp"],
          "categories": doc["categories"],
          "totalAmount": (doc["totalAmount"] is int)
              ? (doc["totalAmount"] as int).toDouble() // Convert int → double
              : (doc["totalAmount"] ?? 0.0),
          "title": doc["title"]
        };
      }).toList();
    } catch (e) {
      print("❌ Error fetching bills: $e");
      return [];
    }
  }

  // Add Monthly Budget
  Future<void> addMonthlyBudget(double amount, String monthYear) async {
    await _firestore.collection('budgets').doc(monthYear).set({
      'totalBudget': amount,
      'totalSpent': 0,
      'availableBudget': amount,
    });
  }

  // Add Budget for a Category
  Future<void> addCategoryBudget(
      String monthYear, String category, double amount) async {
    await _firestore
        .collection('budgets')
        .doc(monthYear)
        .collection('categories')
        .doc(category)
        .set({
      'budget': amount,
      'spent': 0,
      'available': amount,
    });
  }

  // Fetch Monthly Budget
  Future<Map<String, dynamic>?> getMonthlyBudget(String monthYear) async {
    DocumentSnapshot doc =
        await _firestore.collection('budgets').doc(monthYear).get();
    return doc.exists ? doc.data() as Map<String, dynamic> : null;
  }

  // Fetch Budgeted Categories
  Future<List<Map<String, dynamic>>> getCategoryBudgets(
      String monthYear) async {
    QuerySnapshot querySnapshot = await _firestore
        .collection('budgets')
        .doc(monthYear)
        .collection('categories')
        .get();
    return querySnapshot.docs
        .map((doc) => {
              'category': doc.id,
              'budget': doc['budget'],
              'spent': doc['spent'],
            })
        .toList();
  }

  Future<double> getMonthlyExpenses(String monthYear) async {
    QuerySnapshot querySnapshot =
        await _firestore.collection('transactions').get();

    double totalSpent = 0.0;
    for (var doc in querySnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;

      if (data['transactionType'] == "Expense" &&
          _isSameMonthYear(data['date'], monthYear)) {
        totalSpent += double.tryParse(data['amount'].toString()) ?? 0.0;
      }
    }
    return totalSpent;
  }

  // ✅ Fetch total expenses for a specific category within the month
  Future<double> getCategoryMonthlyExpense(
      String monthYear, String category) async {
    QuerySnapshot querySnapshot =
        await _firestore.collection('transactions').get();

    double totalSpent = 0.0;
    for (var doc in querySnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;

      if (data['transactionType'] == "Expense" &&
          data['category'] == category &&
          _isSameMonthYear(data['date'], monthYear)) {
        totalSpent += double.tryParse(data['amount'].toString()) ?? 0.0;
      }
    }
    return totalSpent;
  }

// ✅ Helper function to compare date with monthYear
  bool _isSameMonthYear(String dateString, String monthYear) {
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

    int year =
        int.parse(dateString.substring(0, 4)); // Extract year (e.g., 2025)
    int monthIndex =
        int.parse(dateString.substring(5, 7)); // Extract month (e.g., 03 → 3)

    String formattedMonthYear = "${monthNames[monthIndex - 1]} $year";
    return formattedMonthYear == monthYear;
  }
}
