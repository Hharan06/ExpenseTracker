import 'dart:convert';
import 'package:expensetracker/screens/budgeting_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'add_transaction_screen.dart';
import '../services/firebase_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'receipts_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'budgeting_screen.dart';

const String geminiApiKey = "AIzaSyCA5B_d2M4BaCFj1nO6xJFQsjjrOBrBqQA";

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomeScreen(),
    ReceiptsScreen(),
    BudgetingScreen(),
  ];

  void _onItemTapped(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex], // ✅ No more index errors
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Receipts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Budget',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  Uint8List? _webImage;
  String _extractedText = "";
  double totalSpending = 0.0;
  double totalIncome = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchTransactionData(); // Fetch data when the screen loads
  }

  Future<void> _fetchTransactionData() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("transactions")
          .orderBy("date", descending: true) // Sort by latest transaction
          .get();

      double spending = 0.0;
      double income = 0.0;

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;

        if (data != null && data.containsKey("amount")) {
          double amount;

          /// Handle cases where amount is stored as String, int, or double
          if (data["amount"] is String) {
            amount = double.tryParse(data["amount"]) ?? 0.0;
          } else if (data["amount"] is int) {
            amount = (data["amount"] as int).toDouble();
          } else {
            amount = data["amount"] ?? 0.0;
          }

          String type = data["transactionType"] ?? "";

          if (type == "Expense") {
            spending += amount;
          } else if (type == "Income") {
            income += amount;
          }
        }
      }

      setState(() {
        totalSpending = spending;
        totalIncome = income;
      });
    } catch (e) {
      print("❌ Error fetching transaction data: $e");
    }
  }

  double getBalance() {
    return totalIncome - totalSpending;
  }

  Future<void> _captureImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      String? imageName = await _getImageNameFromUser(); // Prompt user for name

      if (imageName == null || imageName.isEmpty) {
        print("⚠️ Image name is required!");
        return;
      }

      print("📷 Image Name: $imageName");

      if (kIsWeb) {
        Uint8List imageBytes =
            await image.readAsBytes(); // Convert to bytes for web
        setState(() {
          _webImage = imageBytes;
          _selectedImage = null;
        });
      } else {
        setState(() {
          _selectedImage = File(image.path);
          _webImage = null;
        });
      }

      await _extractText(imageName); // Pass imageName
    }
  }

  Future<String?> _getImageNameFromUser() async {
    TextEditingController _controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Enter Image Name"),
        content: TextField(
          controller: _controller,
          decoration: InputDecoration(hintText: "Image name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null), // Cancel
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _controller.text.trim()), // Confirm
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(String transactionId) async {
    try {
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(transactionId)
          .delete();

      await _fetchTransactionData();
      setState(() {}); // Refresh UI
    } catch (e) {
      print("❌ Error deleting transaction: $e");
    }
  }

  Future<void> _extractText(String imageName) async {
    if (_selectedImage == null && _webImage == null) return;

    final inputImage = _selectedImage != null
        ? InputImage.fromFile(_selectedImage!)
        : InputImage.fromBytes(
            bytes: _webImage!,
            metadata: InputImageMetadata(
              size: Size(300, 300),
              rotation: InputImageRotation.rotation0deg,
              format: InputImageFormat.nv21,
              bytesPerRow: 300,
            ),
          );

    final textRecognizer = TextRecognizer();
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    String extractedText = recognizedText.text;

    print("Extracted Text: $extractedText");

    await sendToGemini(extractedText, imageName); // Pass imageName
  }

  Future<void> sendToGemini(String extractedText, String imageName) async {
    final String apiUrl =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey";

    String prompt = """
Based on the following receipt data, categorize the items and calculate the total amount for each category. The items are listed first and prices of corresponding items are listed below that. Return the data in a JSON format.

Receipt Data:
$extractedText

Expected JSON format:
{
  "title": "$imageName",
  "categories": [
    {
      "category": "Dairy",
      "items": ["Milk", "Cottage Cheese", "Natural Yogurt"],
      "total": 2.44
    },
    {
      "category": "Vegetables & Fruits",
      "items": ["Cherry Tomatoes 1lb", "Bananas 1lb", "Aubergine"],
      "total": 3.59
    },
    {
      "category": "Snacks",
      "items": ["Cheese Crackers", "Chocolate Cookies"],
      "total": 8.41
    },
    {
      "category": "Meat",
      "items": ["Chicken Breast"],
      "total": 4.98
    },
    {
      "category": "Household",
      "items": ["Toilet Paper", "Baby Wipes"],
      "total": 1.59
    }
  ],
  "totalAmount": 25.97
}

For the title, dont extract from the image instead use $imageName
""";

    final Map<String, dynamic> requestPayload = {
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ]
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestPayload),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        String jsonResponse =
            data["candidates"][0]["content"]["parts"][0]["text"];
        print("Gemini Response: $jsonResponse");

        await _firebaseService.saveBillToFirestore(extractedText, jsonResponse);
      } else {
        print("Gemini API Error: ${response.body}");
      }
    } catch (e) {
      print("Error calling Gemini API: $e");
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: Icon(Icons.camera_alt, color: Colors.orange),
            title: Text("Upload Bill Image"),
            onTap: () {
              Navigator.pop(context);
              _captureImage();
            },
          ),
          ListTile(
            leading: Icon(Icons.add, color: Colors.blue),
            title: Text("Add New Transaction"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddTransactionScreen()),
              ).then((_) {
                _fetchTransactionData(); // Fetch updated data after returning from the screen
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Good Afternoon", style: TextStyle(fontSize: 16)),
        actions: [
          CircleAvatar(
            backgroundImage: NetworkImage("https://via.placeholder.com/50"),
          ),
          SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Hariharan",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoCard("Spending", "\$${totalSpending.toStringAsFixed(2)}",
                    Colors.pink, Icons.arrow_upward),
                _infoCard("Income", "\$${totalIncome.toStringAsFixed(2)}",
                    Colors.green, Icons.arrow_downward),
              ],
            ),
            SizedBox(height: 10),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Balance: \$${getBalance().toStringAsFixed(2)}",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            SizedBox(height: 20),
            const Text("Recent transactions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _firebaseService.getTransactions(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  return ListView(
                    children: snapshot.data!.map((transaction) {
                      return _transactionCard(
                        transaction['id'] ?? "", // ✅ Fix: Ensure ID is not null
                        transaction['amount']?.toString() ??
                            "0.00", // ✅ Fix: Convert to String
                        transaction['category'] ??
                            "Unknown", // ✅ Fix: Prevent null
                        transaction['date'] ?? "No date",
                        transaction['details'] ?? "No details",
                        transaction['paymentMode'] ?? "Unknown",
                        transaction['transactionType'] ?? "Unknown",
                        () async {
                          if (transaction['id'] != null) {
                            // ✅ Ensure ID is valid before deleting
                            await _deleteTransaction(transaction['id']);
                          }
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showUploadOptions,
        tooltip: "Upload Bill or Add Transaction",
        child: Icon(Icons.upload_file),
      ),
    );
  }

  Widget _infoCard(String title, String amount, Color color, IconData icon) {
    return Container(
      width: 150,
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          SizedBox(height: 5),
          Text(title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          SizedBox(height: 5),
          Text(amount,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _transactionCard(
    String transactionId,
    String amount,
    String category,
    String date,
    String details,
    String paymentMode,
    String transactionType,
    VoidCallback onDelete, // ✅ Passed delete function from parent
  ) {
    return Card(
      color: Colors.black, // ✅ Improved UI with card background
      elevation: 2, // ✅ Added slight elevation for better visibility
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: Text(
          details,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$transactionType - $category",
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(date, style: TextStyle(color: Colors.grey)),
            Text("Payment Mode: $paymentMode",
                style: TextStyle(color: Colors.blueGrey)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min, // ✅ Keeps Row compact
          children: [
            Text("\$$amount",
                style: TextStyle(color: Colors.green, fontSize: 16)),
            SizedBox(
                width: 10), // ✅ Added spacing between amount & delete button
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                _deleteTransaction(transactionId);
              },
            ),
          ],
        ),
      ),
    );
  }
}
