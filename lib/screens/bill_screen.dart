import 'dart:io';
import 'package:flutter/material.dart';

class BillScreen extends StatelessWidget {
  final File image;
  final String text;

  const BillScreen({super.key, required this.image, required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bill Details")),
      body: Column(
        children: [
          Image.file(image, height: 250, width: double.infinity, fit: BoxFit.cover),
          SizedBox(height: 20),
          Text(
            "Extracted Text:",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              text,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
