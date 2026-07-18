import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_manager_interface/core/localization.dart';
import 'package:delivery_manager_interface/models/product_edit_request_model.dart';
import 'package:delivery_manager_interface/widgets/hover_scrollbar.dart';


enum ProposalTableColumn {
  cancel,
  status,
  shippingMethod,
  category,
  productName,
  taxType,
  supplyPrice,
  deliveryPrice,
  shippingFee,
  returnDeliveryPrice,
  freeShipping,
  maxPackagingQuantity,
  pricePoints,
  deliveryDays,
  storageInfo,
  instructions,
  photo,
}

class ProposalListTab extends StatefulWidget {
  final String uid;

  const ProposalListTab({super.key, required this.uid});

  @override
  State<ProposalListTab> createState() => _ProposalListTabState();
}

class _ProposalListTabState extends State<ProposalListTab> {
  final ScrollController _scrollController = ScrollController();
  Map<String, String> _categoryNames = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('categories')
          .get();
      if (mounted) {
        setState(() {
          _categoryNames = {
            for (var doc in snap.docs)
              doc.id: doc.data()['name']?.toString() ?? ''
          };
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _getColumnWidth(ProposalTableColumn col) {
    switch (col) {
      case ProposalTableColumn.cancel:
        return 80.0;
      case ProposalTableColumn.status:
        return 90.0;
      case ProposalTableColumn.shippingMethod:
        return 120.0;
      case ProposalTableColumn.category:
        return 120.0;
      case ProposalTableColumn.productName:
        return 180.0;
      case ProposalTableColumn.taxType:
        return 80.0;
      case ProposalTableColumn.supplyPrice:
        return 110.0;
      case ProposalTableColumn.deliveryPrice:
        return 110.0;
      case ProposalTableColumn.shippingFee:
        return 110.0;
      case ProposalTableColumn.returnDeliveryPrice:
        return 110.0;
      case ProposalTableColumn.freeShipping:
        return 150.0;
      case ProposalTableColumn.maxPackagingQuantity:
        return 120.0;
      case ProposalTableColumn.pricePoints:
        return 160.0;
      case ProposalTableColumn.deliveryDays:
        return 120.0;
      case ProposalTableColumn.storageInfo:
        return 100.0;
      case ProposalTableColumn.instructions:
        return 180.0;
      case ProposalTableColumn.photo:
        return 80.0;
    }
  }

  String _getColumnTitle(ProposalTableColumn col) {
    switch (col) {
      case ProposalTableColumn.cancel:
        return '';
      case ProposalTableColumn.status:
        return tr('pe_col_status');
      case ProposalTableColumn.shippingMethod:
        return tr('pe_col_shipping_method');
      case ProposalTableColumn.category:
        return tr('pe_col_category');
      case ProposalTableColumn.productName:
        return tr('pe_col_product_name');
      case ProposalTableColumn.taxType:
        return tr('pe_col_tax_type');
      case ProposalTableColumn.supplyPrice:
        return tr('pe_col_supply_price');
      case ProposalTableColumn.deliveryPrice:
        return tr('pe_col_delivery_price');
      case ProposalTableColumn.shippingFee:
        return tr('pe_col_shipping_fee');
      case ProposalTableColumn.returnDeliveryPrice:
        return tr('pe_col_return_price');
      case ProposalTableColumn.freeShipping:
        return tr('pe_col_free_shipping');
      case ProposalTableColumn.maxPackagingQuantity:
        return tr('pe_col_max_pkg_qty');
      case ProposalTableColumn.pricePoints:
        return tr('pe_col_sales_qty');
      case ProposalTableColumn.deliveryDays:
        return tr('pe_col_delivery_days');
      case ProposalTableColumn.storageInfo:
        return tr('pe_col_storage');
      case ProposalTableColumn.instructions:
        return tr('pe_col_instructions');
      case ProposalTableColumn.photo:
        return tr('pe_col_photo');
    }
  }

  void _confirmCancelProposal(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            tr('pe_cancel_proposal'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(tr('pe_cancel_proposal_confirm')),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('pe_no')),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await FirebaseFirestore.instance
                      .collection('product_edit_requests')
                      .doc(docId)
                      .delete();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('pe_cancel_success'))),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr(
                            'pe_cancel_fail',
                          ).replaceAll('{error}', e.toString()),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(tr('pe_yes')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTableHeaderRow(List<ProposalTableColumn> columns) {
    return Row(
      children:
          columns.map((col) {
            final width = _getColumnWidth(col);
            final bool isBorderLast = col == columns.last;

            return Container(
              width: width,
              height: 56,
              alignment: Alignment.center,
              decoration:
                  col == ProposalTableColumn.cancel
                      ? const BoxDecoration(color: Colors.transparent)
                      : BoxDecoration(
                        color: Colors.grey[100],
                        border: Border(
                          top: const BorderSide(color: Colors.black),
                          left: const BorderSide(color: Colors.black),
                          bottom: const BorderSide(color: Colors.black),
                          right:
                              isBorderLast
                                  ? const BorderSide(color: Colors.black)
                                  : BorderSide.none,
                        ),
                      ),
              child:
                  col == ProposalTableColumn.cancel
                      ? const SizedBox.shrink()
                      : Text(
                        _getColumnTitle(col),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
            );
          }).toList(),
    );
  }

  Widget _buildTableRowItem(
    BuildContext context,
    QueryDocumentSnapshot doc,
    List<ProposalTableColumn> columns,
  ) {
    final request = ProductEditRequestModel.fromMap(
      doc.id,
      doc.data() as Map<String, dynamic>,
    );

    String statusStr;
    switch (request.status) {
      case 'approved':
        statusStr = tr('pe_status_approved');
        break;
      case 'rejected':
        statusStr = tr('pe_status_rejected');
        break;
      case 'pending':
      default:
        statusStr = tr('pe_status_pending');
        break;
    }

    final String shippingMethod = request.shippingMethod ?? '';
    final Map<String, dynamic>? address = request.address;
    final String addressName = address?['address_name']?.toString() ?? '';
    final String regionsSuffix =
        (shippingMethod == '지역배송' && addressName.isNotEmpty)
            ? ' ($addressName)'
            : '';
    final String categoryId = request.category;
    final String categoryDisplayName = _categoryNames[categoryId] ?? categoryId;
    final String productName = request.productName;
    final String taxType = request.taxType;
    final int supplyPrice = request.supplyPrice.toInt();
    final int deliveryPrice = request.deliveryPrice.toInt();
    final int shippingFee = request.shippingFee.toInt();
    final int returnDeliveryPrice = request.returnDeliveryPrice.toInt();

    final bool noFreeShipping = request.noFreeShipping;
    final int freeShippingThreshold = request.freeShippingThreshold.toInt();
    final String freeShippingStr =
        noFreeShipping
            ? tr('pe_no_free_shipping_label')
            : tr(
              'pe_won_or_more',
            ).replaceAll('{amount}', freeShippingThreshold.toString());

    final int maxPackagingQuantity = request.maxPackagingQuantity;

    final ptsList = request.pricePoints;
    final String pricePointsStr = ptsList
        .map((pt) {
          final qStr = tr(
            'pe_items_count',
          ).replaceAll('{count}', pt['quantity'].toString());
          final pStr = tr('pe_won').replaceAll(
            '{amount}',
            ((pt['price'] as num?)?.toInt() ?? 0).toString(),
          );
          return '$qStr: $pStr';
        })
        .join('\n');

    final int deliveryMinDays = request.deliveryMinDays;
    final int deliveryMaxDays = request.deliveryMaxDays;
    final String deliveryDaysStr = tr('pe_days_range')
        .replaceAll('{min}', deliveryMinDays.toString())
        .replaceAll('{max}', deliveryMaxDays.toString());

    final String storageInfo = request.storageInfo;
    final String instructions = request.instructions;
    final String imgUrl = request.imgUrl;

    return Row(
      children:
          columns.map((col) {
            final width = _getColumnWidth(col);
            final bool isBorderLast = col == columns.last;

            Widget cellChild;
            Alignment alignment = Alignment.center;

            switch (col) {
              case ProposalTableColumn.cancel:
                alignment = Alignment.centerRight;
                cellChild = Container(
                  width: 80,
                  height: 28,
                  color: Colors.black,
                  child: InkWell(
                    onTap: () => _confirmCancelProposal(context, doc.id),
                    child: Center(
                      child: Text(
                        tr('pe_cancel_proposal'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
                break;
              case ProposalTableColumn.status:
                Color statusColor;
                switch (request.status) {
                  case 'approved':
                    statusColor = Colors.green[700]!;
                    break;
                  case 'rejected':
                    statusColor = Colors.red[700]!;
                    break;
                  case 'pending':
                  default:
                    statusColor = Colors.orange[800]!;
                    break;
                }
                cellChild = Text(
                  statusStr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: statusColor,
                  ),
                );
                break;
              case ProposalTableColumn.shippingMethod:
                final List<String> included = address != null && address['includedSigungu'] is List
                    ? List<String>.from(address['includedSigungu'])
                    : [];
                final List<String> excluded = address != null && address['excludedEupmyeondong'] is List
                    ? List<String>.from(address['excludedEupmyeondong'])
                    : [];
                String tooltipText = '';
                if (shippingMethod == '지역배송') {
                  final includedTitle = tr('pe_delivery_region');
                  final excludedTitle = tr('pe_taxable') == '과세' ? '제외 지역' : 'Excluded Regions';
                  tooltipText = '$includedTitle:\n${included.isEmpty ? '-' : included.join('\n')}';
                  if (excluded.isNotEmpty) {
                    tooltipText += '\n\n$excludedTitle:\n${excluded.join('\n')}';
                  }
                }
                final textWidget = Text(
                  '$shippingMethod$regionsSuffix',
                  style: const TextStyle(fontSize: 12),
                );
                cellChild = tooltipText.isNotEmpty
                    ? Tooltip(
                        message: tooltipText,
                        preferBelow: false,
                        child: textWidget,
                      )
                    : textWidget;
                break;
              case ProposalTableColumn.category:
                cellChild = Text(
                  categoryDisplayName,
                  style: const TextStyle(fontSize: 12),
                );
                break;
              case ProposalTableColumn.productName:
                cellChild = Text(
                  productName,
                  style: const TextStyle(fontSize: 12),
                );
                break;
              case ProposalTableColumn.taxType:
                cellChild = Text(taxType, style: const TextStyle(fontSize: 12));
                break;
              case ProposalTableColumn.supplyPrice:
                cellChild = Text(
                  tr('pe_won').replaceAll('{amount}', supplyPrice.toString()),
                  style: const TextStyle(fontSize: 12),
                );
                break;
              case ProposalTableColumn.deliveryPrice:
                cellChild = Text(
                  tr('pe_won').replaceAll('{amount}', deliveryPrice.toString()),
                  style: const TextStyle(fontSize: 12),
                );
                break;
              case ProposalTableColumn.shippingFee:
                cellChild = Text(
                  tr('pe_won').replaceAll('{amount}', shippingFee.toString()),
                  style: const TextStyle(fontSize: 12),
                );
                break;
              case ProposalTableColumn.returnDeliveryPrice:
                cellChild = Text(
                  tr(
                    'pe_won',
                  ).replaceAll('{amount}', returnDeliveryPrice.toString()),
                  style: const TextStyle(fontSize: 12),
                );
                break;
              case ProposalTableColumn.freeShipping:
                cellChild = Text(
                  freeShippingStr,
                  style: const TextStyle(fontSize: 12),
                );
                break;
              case ProposalTableColumn.maxPackagingQuantity:
                cellChild = Text(
                  '$maxPackagingQuantity',
                  style: const TextStyle(fontSize: 12),
                );
                break;
              case ProposalTableColumn.pricePoints:
                cellChild = Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    pricePointsStr,
                    style: const TextStyle(fontSize: 12),
                  ),
                );
                break;
              case ProposalTableColumn.deliveryDays:
                cellChild = Text(
                  deliveryDaysStr,
                  style: const TextStyle(fontSize: 12),
                );
                break;
              case ProposalTableColumn.storageInfo:
                cellChild = Text(
                  storageInfo,
                  style: const TextStyle(fontSize: 12),
                );
                break;
              case ProposalTableColumn.instructions:
                cellChild = Container(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(
                    instructions,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                );
                break;
              case ProposalTableColumn.photo:
                alignment = Alignment.center;
                cellChild =
                    imgUrl.isNotEmpty
                        ? Image.network(
                          imgUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, size: 24),
                        )
                        : const Icon(Icons.image, size: 24, color: Colors.grey);
                break;
            }

            return Container(
              width: width,
              height: 80,
              alignment: alignment,
              padding:
                  col == ProposalTableColumn.cancel
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 8),
              decoration:
                  col == ProposalTableColumn.cancel
                      ? const BoxDecoration(color: Colors.transparent)
                      : BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          left: const BorderSide(color: Colors.black),
                          bottom: const BorderSide(color: Colors.black),
                          right:
                              isBorderLast
                                  ? const BorderSide(color: Colors.black)
                                  : BorderSide.none,
                        ),
                      ),
              child: cellChild,
            );
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('product_edit_requests')
              .where('requested_by', isEqualTo: widget.uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.black),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              tr(
                'pe_error_occurred',
              ).replaceAll('{error}', snapshot.error.toString()),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                tr('pe_no_proposals'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        // Sort in memory by requested_at descending
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final aTime =
              (a.data() as Map<String, dynamic>)['requested_at'] as Timestamp?;
          final bTime =
              (b.data() as Map<String, dynamic>)['requested_at'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        final columns = ProposalTableColumn.values;
        final double totalTableWidth = columns.fold(
          0.0,
          (total, col) => total + _getColumnWidth(col),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HoverScrollbar(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalTableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTableHeaderRow(columns),
                      ...sortedDocs.map(
                        (doc) => _buildTableRowItem(context, doc, columns),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
