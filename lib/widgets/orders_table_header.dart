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
                buildTableHeader('주문 ID'),
                buildTableHeader('수취인'),
                buildTableHeader('전화번호'),
                buildTableHeader('주소'),
                buildTableHeader('상세주소'),
                buildTableHeader('배송 요청사항'),
                buildTableHeader('제품'),
                buildTableHeader('수량'),
                buildTableHeader('가격'),
                buildTableHeader('날짜'),
                buildTableHeader('공급가'),
                buildTableHeader('배송비'),
                buildTableHeader('도서산간 추가 배송비'),
                /*  _buildTableHeader('Estimated settlement'), */
                buildTableHeader('택배사'),
                buildTableHeader('운송장 번호'),
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
