import 'package:flutter/material.dart';

Widget buildTableHeader(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
    child: Text(
      text,
      style: TextStyle(fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    ),
  );
}
