import 'package:delivery_manager_interface/core/constants.dart';
import 'package:delivery_manager_interface/widgets/table_header.dart';
import 'package:flutter/material.dart';

Widget ordersTableHeader(ScrollController headerScrollController) {
  return SizedBox(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: headerScrollController,
      child: Container(
        width: 1600,

        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Table(
          border: TableBorder.all(color: Colors.black),
          columnWidths: columnWidths,
          children: [
            TableRow(
              children: [
                buildTableHeader('날짜'), // Date
                buildTableHeader('주문 ID'), // Order ID
                buildTableHeader('수취인'), // Recipient Name
                buildTableHeader('전화번호'), // Phone Number
                buildTableHeader('주소'), // Address
                buildTableHeader('상세주소'), // Detailed Address
                buildTableHeader('배송 요청사항'), // Delivery Request / Instructions
                buildTableHeader('제품'), // Product
                buildTableHeader('수량'), // Quantity
                buildTableHeader('가격'), // Price
                buildTableHeader('공급가'), // Supply Price
                buildTableHeader('배송비'), // Delivery Fee / Shipping Fee
                buildTableHeader('도서산간 추가 배송비'), // Additional Remote Area Delivery Fee
                /*  _buildTableHeader('Estimated settlement'), */
                buildTableHeader('택배사'), // Courier / Carrier
                buildTableHeader('운송장 번호'), // Tracking Number
                buildTableHeader(''),
                buildTableHeader(''),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
