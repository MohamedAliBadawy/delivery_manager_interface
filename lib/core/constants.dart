import 'package:flutter/material.dart';

final Map<int, TableColumnWidth> columnWidths = {
  0: FlexColumnWidth(1), // Order ID
  1: FlexColumnWidth(1), // Recipient
  2: FlexColumnWidth(1), // Phone
  3: FlexColumnWidth(1), // Address
  4: FlexColumnWidth(1), // Delivery Note
  5: FlexColumnWidth(1), // Product
  6: FlexColumnWidth(1), // Quantity
  7: FlexColumnWidth(1), // Supply price
  8: FlexColumnWidth(1), // Delivery price
  9: FlexColumnWidth(1), // Shipping fee
  /*     10: FlexColumnWidth(1), // Estimated settlement
 */
  10: FlexColumnWidth(1), // Courier
  11: FlexColumnWidth(1), // Tracking Number
  12: FlexColumnWidth(1.5), // Submit Button (wider)
};
