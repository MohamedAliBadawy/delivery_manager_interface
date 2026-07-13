import 'package:flutter/material.dart';

final ValueNotifier<String> languageNotifier = ValueNotifier<String>('ko');

const bool showLanguageSelector =
    false; // Set to false to easily hide language switchers before building/deploying

String tr(String key) {
  final lang = languageNotifier.value;
  return localizedTexts[key]?[lang] ?? localizedTexts[key]?['ko'] ?? key;
}

const Map<String, Map<String, String>> localizedTexts = {
  // Login Screen
  'login_title': {'ko': '로그인', 'en': 'Delivery Manager Login'},
  'email_label': {'ko': '이메일', 'en': 'Email'},
  'password_label': {'ko': '비밀번호', 'en': 'Password'},
  'login_button': {'ko': '로그인', 'en': 'Login'},
  'access_denied': {
    'ko': '권한이 없습니다. 관리자에게 문의하세요.',
    'en': 'Access denied. You do not have delivery manager permissions.',
  },

  // Dashboard Tabs
  'tab_new': {'ko': '신규 주문', 'en': 'New Orders'},
  'tab_preparing': {'ko': '준비중', 'en': 'Preparing'},
  'tab_shipping': {'ko': '배송중', 'en': 'In Transit'},
  'tab_completed': {'ko': '배송완료 및 정산', 'en': 'Delivered & Settled'},
  'tab_exchange': {'ko': '교환·반품 요청', 'en': 'Exchanges & Returns'},
  'tab_chat': {'ko': '고객문의', 'en': 'Customer Inquiries'},
  'tab_gift': {'ko': '선물대기', 'en': 'Gift Pending'},

  // Side Menu Items
  'menu_products': {'ko': '상품 관리', 'en': 'Products'},
  'menu_proposals': {'ko': '상품 입점 제안', 'en': 'Store Proposals'},
  'menu_profile': {'ko': '회원정보', 'en': 'Profile'},
  'logout': {'ko': '로그아웃', 'en': 'Logout'},

  // Table Columns
  'col_select_all': {'ko': '전체선택', 'en': 'Select All'},
  'col_date': {'ko': '주문일자', 'en': 'Order Date'},
  'col_id': {'ko': '주문번호', 'en': 'Order ID'},
  'col_product': {'ko': '상품명', 'en': 'Product Name'},
  'col_qty': {'ko': '수량', 'en': 'Qty'},
  'col_recipient': {'ko': '성함', 'en': 'Recipient'},
  'col_phone': {'ko': '전화번호', 'en': 'Phone Number'},
  'col_address': {'ko': '주소', 'en': 'Address'},
  'col_instructions': {'ko': '배송 요청사항', 'en': 'Delivery Instructions'},
  'col_courier': {'ko': '택배사', 'en': 'Courier'},
  'col_tracking': {'ko': '운송장 번호', 'en': 'Tracking Number'},
  'col_action': {'ko': '처리', 'en': 'Action'},
  'col_settlement_date': {'ko': '정산 일자', 'en': 'Settlement Date'},
  'col_product_price': {'ko': '상품가격', 'en': 'Product Price'},
  'col_delivery_fee': {'ko': '배송비', 'en': 'Delivery Fee'},
  'col_island_fee': {'ko': '도서 추가 배송비', 'en': 'Island Add. Fee'},
  'col_settlement_amount': {'ko': '정산금액', 'en': 'Settlement Amount'},
  'col_exchange_reason': {'ko': '사유', 'en': 'Reason'},
  'col_exchange_status': {'ko': '처리상태', 'en': 'Status'},

  // Buttons and Actions
  'btn_confirm': {'ko': '주문확인', 'en': 'Confirm'},
  'btn_cancel': {'ko': '주문취소', 'en': 'Cancel'},
  'btn_excel_download': {'ko': '주문서 다운로드', 'en': 'Download Excel'},
  'btn_tracking_upload': {'ko': '송장번호 일괄 등록', 'en': 'Upload Tracking'},
  'btn_submit': {'ko': '제출', 'en': 'Submit'},
  'btn_close': {'ko': '닫기', 'en': 'Close'},
  'btn_direct_delivery': {'ko': '직접배송처리', 'en': 'Direct Delivery'},
  'direct_delivery_title': {'ko': '직접 배송 처리', 'en': 'Direct Delivery'},
  'direct_delivery_confirm': {
    'ko': '선택한 {count}개의 주문을 직접 배송 처리하시겠습니까?',
    'en':
        'Are you sure you want to process direct delivery for the {count} selected orders?',
  },
  'direct_delivery_success': {
    'ko': '선택한 주문들의 직접 배송 처리가 완료되었습니다.',
    'en': 'Direct delivery processing completed successfully.',
  },
  'direct_delivery_fail': {
    'ko': '직접 배송 처리 실패: {error}',
    'en': 'Failed to process direct delivery: {error}',
  },
  'direct_delivery_label': {'ko': '직접배송', 'en': 'Direct delivery'},
  'btn_cancel_reason_hint': {
    'ko': '사유 선택창(재고부족, 고객요청) -> 주문 취소 처리',
    'en': 'Reason (Stock, Customer) -> Cancel Action',
  },

  // Search and Placeholders
  'search_placeholder': {
    'ko': '검색: 상품명, 성함, 주소 검색',
    'en': 'Search product, recipient, address...',
  },
  'filter_product': {'ko': '필터: 상품별', 'en': 'Filter by Product'},
  'filter_date': {'ko': '필터: 일자별', 'en': 'Filter by Date'},
  'filter_all': {'ko': '전체', 'en': 'All'},

  // Empty lists / labels
  'no_orders': {'ko': '주문이 없습니다', 'en': 'No orders found'},
  'no_inquiries': {'ko': '고객 문의가 없습니다.', 'en': 'No customer inquiries.'},
  'customer': {'ko': '고객', 'en': 'Customer'},
  'loading': {'ko': '로딩 중...', 'en': 'Loading...'},
  'deleted_product': {'ko': '[삭제된 상품]', 'en': '[Deleted Product]'},
  'deleted_user': {'ko': '[삭제된 고객]', 'en': '[Deleted User]'},
  'input_needed': {'ko': '입력 필요', 'en': 'Required'},

  // Cancel Dialog
  'cancel_dialog_title': {
    'ko': '주문 취소 처리 (Cancel Orders)',
    'en': 'Cancel Orders',
  },
  'cancel_dialog_confirm': {
    'ko': '선택한 {count}개의 주문을 취소하시겠습니까?',
    'en': 'Are you sure you want to cancel the {count} selected orders?',
  },
  'cancel_reason_select': {
    'ko': '취소 사유 선택:',
    'en': 'Select Cancellation Reason:',
  },
  'reason_out_of_stock': {'ko': '재고부족', 'en': 'Out of Stock'},
  'reason_customer_request': {'ko': '고객요청', 'en': 'Customer Request'},
  'cancel_success': {
    'ko': '주문이 정상적으로 취소 처리되었습니다.',
    'en': 'Orders cancelled successfully.',
  },
  'cancel_fail': {
    'ko': '주문 취소 실패: {error}',
    'en': 'Failed to cancel orders: {error}',
  },
  'confirm_success': {
    'ko': '선택한 주문들이 확인 완료되었습니다.',
    'en': 'Selected orders confirmed successfully.',
  },
  'confirm_fail': {
    'ko': '주문 확인 실패: {error}',
    'en': 'Failed to confirm orders: {error}',
  },

  // Product Management Popup
  'pm_title': {'ko': '상품 관리 (Product Management)', 'en': 'Product Management'},
  'pm_contract_info': {'ko': '계약 정보', 'en': 'Contract Info'},
  'pm_cutoff_inventory': {
    'ko': '주문 마감 시간/재고 관리',
    'en': 'Order Cutoff & Inventory',
  },
  'pm_product_name': {'ko': '제품명', 'en': 'Product Name'},
  'pm_supply_price': {'ko': '공급가', 'en': 'Supply Price'},
  'pm_shipping_fee': {'ko': '배송비', 'en': 'Shipping Fee'},
  'pm_remote_shipping': {
    'ko': '도서산간 추가 배송비',
    'en': 'Additional Shipping Fee (Remote)',
  },
  'pm_cutoff_time': {'ko': '주문 마감 시간', 'en': 'Cutoff Time'},
  'pm_change': {'ko': '변경', 'en': 'Change'},
  'pm_current_stock': {'ko': '현재 재고', 'en': 'Current Stock'},
  'pm_no_products': {'ko': '제품이 없습니다', 'en': 'No products found'},

  // Store Proposal
  'sp_title': {
    'ko': '상품 입점 제안 (Store Entry Proposal)',
    'en': 'Store Entry Proposal',
  },
  'sp_not_ready': {
    'ko': '새로운 상품 입점 제안 및 등록 기능은 현재 준비 중입니다.',
    'en': 'The store entry proposal feature is currently under preparation.',
  },
  'sp_coming_soon': {
    'ko': '추후 업데이트를 통해 제공될 예정입니다. 문의 사항은 관리자에게 이메일로 연락해주세요.',
    'en':
        'It will be available in a future update. For inquiries, please contact the administrator via email.',
  },

  // Member Info / Profile
  'mi_title': {'ko': '회원정보 (Member Info)', 'en': 'Member Info'},
  'mi_brand_name': {'ko': '브랜드명', 'en': 'Brand Name'},
  'mi_manager_name': {'ko': '담당자명', 'en': 'Representative Name'},
  'mi_contact': {'ko': '담당자 연락처', 'en': 'Representative Contact'},
  'mi_id_email': {'ko': '아이디(이메일)', 'en': 'ID (Email)'},
  'mi_password': {'ko': '비밀번호', 'en': 'Password'},
  'mi_settlement_account': {'ko': '정산계좌', 'en': 'Settlement Account'},
  'mi_business_number': {'ko': '사업자 번호', 'en': 'Business Registration No.'},
  'mi_company_name': {'ko': '상호', 'en': 'Company Name'},
  'mi_email': {'ko': '이메일', 'en': 'Email'},
  'mi_change': {'ko': '변경', 'en': 'Change'},
  'mi_save_success': {
    'ko': '회원정보가 저장되었습니다.',
    'en': 'Member info saved successfully.',
  },
  'mi_save_fail': {'ko': '저장 실패: {error}', 'en': 'Save failed: {error}'},
  'mi_change_password': {'ko': '비밀번호 변경', 'en': 'Change Password'},
  'mi_new_password': {'ko': '새 비밀번호', 'en': 'New Password'},
  'mi_password_change_success': {
    'ko': '비밀번호가 성공적으로 변경되었습니다.',
    'en': 'Password updated successfully.',
  },

  // SnackBar / Alerts
  'tracking_loaded': {
    'ko': '운송장 번호가 필드에 로드되었습니다',
    'en': 'Tracking numbers loaded into fields',
  },
  'order_updated': {'ko': '주문이 업데이트되었습니다', 'en': 'Order updated successfully'},
  'error_occurred': {'ko': '오류 발생', 'en': 'Error occurred'},
  'save': {'ko': '저장', 'en': 'Save'},
  'cancel': {'ko': '취소', 'en': 'Cancel'},
  'time_update_success': {
    'ko': '기준 시간이 성공적으로 업데이트됨',
    'en': 'Cutoff time updated successfully',
  },
  'time_update_fail': {
    'ko': '기준 시간 업데이트 실패',
    'en': 'Failed to update cutoff time',
  },
  'stock_update_success': {
    'ko': '재고가 성공적으로 업데이트됨',
    'en': 'Stock updated successfully',
  },
  'stock_update_fail': {'ko': '재고 업데이트 실패', 'en': 'Failed to update stock'},
  'stock_label': {'ko': '재고', 'en': 'Stock'},
  'stock_required': {'ko': '재고를 입력하세요', 'en': 'Please enter stock quantity'},
  'cutoff_required': {'ko': '기준 시간을 입력하세요', 'en': 'Please enter cutoff time'},
  'product_edit': {'ko': '제품 수정', 'en': 'Edit Product'},
  'updating_cutoff': {'ko': '기준 시간 업데이트 중...', 'en': 'Updating cutoff time...'},
  'updating_stock': {'ko': '재고 업데이트 중...', 'en': 'Updating stock...'},

  // Excel Headers
  'xls_date': {'ko': '날짜', 'en': 'Date'},
  'xls_id': {'ko': '주문 ID', 'en': 'Order ID'},
  'xls_recipient': {'ko': '수취인', 'en': 'Recipient'},
  'xls_phone': {'ko': '전화번호', 'en': 'Phone Number'},
  'xls_address': {'ko': '주소', 'en': 'Address'},
  'xls_detail_address': {'ko': '상세주소', 'en': 'Detail Address'},
  'xls_instructions': {'ko': '배송 요청사항', 'en': 'Delivery Instructions'},
  'xls_product': {'ko': '제품', 'en': 'Product'},
  'xls_qty': {'ko': '수량', 'en': 'Qty'},
  'xls_price': {'ko': '가격', 'en': 'Price'},
  'xls_supply_price': {'ko': '공급가', 'en': 'Supply Price'},
  'xls_shipping': {'ko': '배송비', 'en': 'Shipping Fee'},
  'xls_additional_shipping': {
    'ko': '도서산간 추가 배송비',
    'en': 'Additional Shipping Fee',
  },
  'xls_courier': {'ko': '택배사', 'en': 'Courier'},
  'xls_tracking': {'ko': '운송장 번호', 'en': 'Tracking Number'},
  'btn_delivery_complete': {'ko': '배송완료', 'en': 'Delivery Complete'},
  'btn_track': {'ko': '조회', 'en': 'Track'},
  'delivery_complete_dialog_title': {
    'ko': '배송 완료 처리',
    'en': 'Process Delivery Complete',
  },
  'delivery_complete_dialog_confirm': {
    'ko': '선택한 {count}개의 주문을 배송 완료 처리하시겠습니까?',
    'en':
        'Are you sure you want to complete delivery for the {count} selected orders?',
  },
  'delivery_complete_success': {
    'ko': '선택한 주문들의 배송 완료 처리가 완료되었습니다.',
    'en': 'Delivery completion processed successfully.',
  },
  'delivery_complete_fail': {
    'ko': '배송 완료 처리 실패: {error}',
    'en': 'Failed to process delivery completion: {error}',
  },
  'btn_approve_request': {'ko': '요청 승인', 'en': 'Approve Request'},
  'btn_reject_request': {'ko': '요청 거절', 'en': 'Reject Request'},
  'btn_add_dummy_exchange': {'ko': '더미 교환 추가', 'en': 'Add Dummy Exchange'},
  'btn_add_dummy_refund': {'ko': '더미 반품 추가', 'en': 'Add Dummy Refund'},
  'label_select_reason': {'ko': '-> 사유 선택:', 'en': '-> Select Reason:'},
  'label_reject_exchange_refund': {
    'ko': '-> 교환·반품 요청 거절',
    'en': '-> Reject Request',
  },
  'reason_damaged_product': {
    'ko': '제품 훼손·사용 흔적 발견',
    'en': 'Damaged / Traces of Use',
  },
  'reason_product_damage': {'ko': '제품 훼손', 'en': 'Product damage'},
  'reason_traces_of_use': {'ko': '사용 흔적 발견', 'en': 'Traces of use found'},
  'reason_simple_change_of_mind': {'ko': '고객 단순 변심', 'en': 'Change of Mind'},
  'reason_wrong_delivery': {'ko': '오배송/상품 오발송', 'en': 'Wrong Delivery / Item'},
  'reason_other_reasons': {'ko': '기타 사유', 'en': 'Other Reasons'},
  'exchange_approved': {
    'ko': '요청이 승인되었습니다.',
    'en': 'Request approved successfully.',
  },
  'exchange_rejected': {
    'ko': '요청이 거절되었습니다.',
    'en': 'Request rejected successfully.',
  },
  'dummy_exchange_success': {
    'ko': '더미 교환 요청이 성공적으로 추가되었습니다!',
    'en': 'Dummy exchange request added successfully!',
  },
  'dummy_refund_success': {
    'ko': '더미 반품 요청이 성공적으로 추가되었습니다!',
    'en': 'Dummy refund request added successfully!',
  },
  '대기중': {'ko': '대기중', 'en': 'Pending'},
  '승인됨': {'ko': '승인됨', 'en': 'Approved'},
  '거절됨': {'ko': '거절됨', 'en': 'Rejected'},
  '환불': {'ko': '환불', 'en': 'Refund'},
  '교환': {'ko': '교환', 'en': 'Exchange'},

  // Chat / Inquiries Tab
  'search_customer_placeholder': {
    'ko': '고객명 검색...',
    'en': 'Search customer name...',
  },
  'chat_ongoing': {'ko': '진행중', 'en': 'Ongoing'},
  'chat_completed': {'ko': '상담완료', 'en': 'Completed'},
  'select_chat_hint': {
    'ko': '대화방을 선택하시면 메시지를 확인하실 수 있습니다.',
    'en': 'Select a chat room to view messages.',
  },
  'enter_message_hint': {'ko': '메시지를 입력하세요...', 'en': 'Enter a message...'},
  'no_messages_hint': {
    'ko': '메시지가 없습니다. 대화를 시작해 보세요!',
    'en': 'No messages. start the conversation!',
  },
  'photo_sent_label': {'ko': '사진을 보냈습니다.', 'en': 'Sent a photo.'},
  'shipping_info_title': {'ko': '배송지 정보', 'en': 'Delivery Address'},
  'purchase_stats_title': {'ko': '구매 통계', 'en': 'Purchase Statistics'},
  'total_purchases_label': {'ko': '전체 구매 횟수', 'en': 'Total Purchases'},
  'six_month_repurchases_label': {
    'ko': '6개월 내 재구매',
    'en': '6-Month Repurchases',
  },
  'returning_customer_badge': {'ko': '재구매 고객', 'en': 'Returning Customer'},
  'action_complete_chat': {'ko': '상담 완료 처리', 'en': 'Complete Consultation'},
  'action_resume_chat': {'ko': '진행중으로 변경', 'en': 'Change to Ongoing'},
  'no_shipping_info': {'ko': '배송지 정보 없음', 'en': 'No delivery address info'},

  // Gift Pending Tab
  'gift_sender': {'ko': '보내는 분', 'en': 'Sender'},
  'gift_sender_info': {'ko': '보내는 분 정보', 'en': 'Sender Info'},
  'gift_order_info': {'ko': '주문 정보', 'en': 'Order Info'},
  'gift_status_waiting': {'ko': '수취 대기중', 'en': 'Awaiting Recipient'},
  'gift_awaiting_title': {
    'ko': '수취인의 배송지 입력 대기 중',
    'en': 'Waiting for recipient address',
  },
  'gift_awaiting_desc': {
    'ko': '수취인이 아직 배송 주소를 입력하지 않았습니다. 주소 입력이 완료되면 자동으로 준비중 탭으로 이동합니다.',
    'en':
        'The recipient has not yet provided a delivery address. Once confirmed, this order will move to the Preparing tab automatically.',
  },
  'gift_select_hint': {'ko': '선물 주문을 선택하세요', 'en': 'Select a gift order'},
  'gift_select_hint_sub': {
    'ko': '왼쪽 목록에서 주문을 선택하면 상세 정보를 확인할 수 있습니다.',
    'en': 'Select an order on the left to view its details.',
  },
  'no_gift_orders': {
    'ko': '대기 중인 선물 주문이 없습니다.',
    'en': 'No pending gift orders.',
  },
  'no_gift_orders_hint': {
    'ko': '수취인의 배송지 입력을 기다리는 선물 주문이 없습니다.',
    'en': 'There are no gift orders awaiting a recipient address.',
  },
  'gift_force_ship': {'ko': '강제 배송 처리', 'en': 'Force Ship'},

  // Product Edit Form
  'pe_category_select': {'ko': '카테고리 선택', 'en': 'Category Selection'},
  'pe_food': {'ko': '식품', 'en': 'Food'},
  'pe_life': {'ko': '생활', 'en': 'Life'},
  'pe_other': {'ko': '기타', 'en': 'Other'},
  'pe_product_name': {'ko': '상품명', 'en': 'Product Name'},
  'pe_tax_classification': {'ko': '과세 구분', 'en': 'Tax Classification'},
  'pe_taxable': {'ko': '과세', 'en': 'Taxable'},
  'pe_tax_exempt': {'ko': '면세', 'en': 'Tax-exempt'},
  'pe_product_price_excl': {
    'ko': '상품가격(배송비 미포함)',
    'en': 'Product Price (excl. delivery fee)',
  },
  'pe_delivery_fee': {'ko': '배송비', 'en': 'Delivery Fee'},
  'pe_remote_island_fee': {
    'ko': '도서지역 추가 배송비',
    'en': 'Island/Remote Area Extra Delivery Fee',
  },
  'pe_return_delivery_fee': {'ko': '반품 배송비', 'en': 'Return Delivery Fee'},
  'pe_free_shipping_over': {
    'ko': '~이상 구매 시 무료배송',
    'en': 'Free shipping for orders over',
  },
  'pe_no_free_shipping': {'ko': '무료배송X', 'en': 'No free shipping'},
  'pe_max_pkg_qty': {
    'ko': '1상자 최대 포장수량',
    'en': 'Max packaging quantity per box',
  },
  'pe_single_qty': {'ko': '단일수량', 'en': 'Single quantity'},
  'pe_qty_direct_input': {'ko': '수량(직접입력)', 'en': 'Quantity (direct input)'},
  'pe_product_price': {'ko': '상품가격', 'en': 'Product Price'},
  'pe_add_price_option': {
    'ko': '수량 가격 옵션 추가',
    'en': 'Add quantity price option',
  },
  'pe_delivery_days': {'ko': '배송일', 'en': 'Delivery Date'},
  'pe_enter_number_hint': {'ko': '[ 숫자입력 ] ', 'en': '[Enter number] '},
  'pe_days': {'ko': '일', 'en': 'days'},
  'pe_storage_info': {'ko': '보관법 및 소비기한', 'en': 'Storage method & Expiry date'},
  'pe_product_guide': {'ko': '제품 안내', 'en': 'Product description/guide'},
  'pe_image_list_title': {
    'ko': '이미지 목록 (클릭하여 URL 편집)',
    'en': 'Image List (Click to edit URL)',
  },
  'pe_main_image': {'ko': '메인이미지', 'en': 'Main Image'},
  'pe_add_image_1': {'ko': '추가이미지1', 'en': 'Add. Image 1'},
  'pe_add_image_2': {'ko': '추가이미지2', 'en': 'Add. Image 2'},
  'pe_add_image_3': {'ko': '추가이미지3', 'en': 'Add. Image 3'},
  'pe_add_image_4': {'ko': '추가이미지4', 'en': 'Add. Image 4'},
  'pe_stock': {'ko': '재고', 'en': 'Stock'},
  'pe_request_edit': {'ko': '수정 요청', 'en': 'Request Edit'},
  'pe_review_desc': {
    'ko': '*면밀이 검토 후 좋은 제품, 좋은 가격이 확인 된다면 즉시 승인 됩니다',
    'en':
        '*After close review, if a good product at a good price is confirmed, it will be approved immediately',
  },
  'pe_guide_proposal_title': {
    'ko': '제품 및 서비스 입점 안내',
    'en': 'Product & Service Proposal Guide',
  },
  'pe_guide_proposal_1': {
    'ko': '(1) 제품 및 서비스의 의 용도에 따라 1품목 1종류만 입점 가능합니다.',
    'en':
        '(1) Only 1 item of 1 type can be registered according to the purpose of product and service.',
  },
  'pe_guide_proposal_2': {
    'ko':
        '(2) 더 좋은 가격의 제품/서비스와 더 나은 제품/서비스의 입점 요청이 들어온다면 기존의 제품/서비스는 즉시 퇴점됩니다.',
    'en':
        '(2) If a proposal with a better price or better product/service comes in, the existing product/service will be removed immediately.',
  },
  'pe_guide_proposal_3': {
    'ko':
        '(3) 팽이 멤버십 할인을 정상적으로 제공하는 제품에 한해 입점을 승인합니다. 입점 후 멤버십 할인을 제공하지 않거나, 우회-편법 운영이 확인될 경우 해당 제품은 즉시 퇴점됩니다.',
    'en':
        '(3) Entries are approved only for products providing the membership discount. If the discount is not provided after entry, or bypass/expedient operation is detected, the product will be removed immediately.',
  },
  'pe_guide_settlement_title': {
    'ko': '정산일 및 결제 수수료 안내',
    'en': 'Settlement Date & Payment Fee Guide',
  },
  'pe_guide_settlement_1': {
    'ko': '(1) 정산일: 출고 후 D+3(금년도내 D+1으로 단축예정)',
    'en':
        '(1) Settlement Date: D+3 after shipment (scheduled to shorten to D+1 within this year)',
  },
  'pe_guide_settlement_2': {
    'ko': '(2) 결제 수수료: 3%, 결제 건당 최소 수수료 220원',
    'en': '(2) Payment fee: 3%, minimum fee of 220 KRW per payment transaction',
  },
  'pe_guide_settlement_3': {
    'ko':
        '(3) 환불 및 취소 수수료: 환불 및 판매자 귀책 사유로 인한 취소(품절로 인한 취소, 발송 지연으로 인한 취소, 상품정보 오류로 인한 취소) 발생 시 취소 건당 수수료 1.65%(최소수수료220원) + 330원이 추가로 발생합니다.',
    'en':
        '(3) Refund & Cancellation Fee: For refunds and cancellations due to seller\'s fault (sold out, delayed shipment, product info error), a transaction fee of 1.65% (minimum 220 KRW) + 330 KRW will occur.',
  },
  'pe_prob_high_title': {
    'ko': '아래의 조건을 충족하는 상품은 승인 확률이 높습니다.',
    'en':
        'Products meeting the following conditions have a high probability of approval.',
  },
  'pe_prob_high_1': {
    'ko': '• 온라인 후기로 품질이 입증된 상품',
    'en': '• Products with quality proven by online reviews',
  },
  'pe_prob_high_2': {
    'ko': '• 온라인 최저가보다 낮은 가격인 상품',
    'en': '• Products priced lower than the lowest online price',
  },
  'pe_prob_high_3': {
    'ko': '• 입점되어있는 상품 보다 더 좋은 조건으로 제안하는 상품',
    'en':
        '• Products proposing better conditions than currently registered items',
  },
  'pe_prob_reject_title': {
    'ko': '아래의 조건을 충족하는 상품은 반드시 거절됩니다.',
    'en': 'Products meeting the following conditions will be rejected.',
  },
  'pe_prob_reject_1': {
    'ko': '• 이미 입점되어있는 상품보다 비싼 상품',
    'en': '• Products more expensive than currently registered items',
  },
  'pe_prob_reject_2': {
    'ko': '• 품질이 나쁘고 고객 후기가 별로인 상품',
    'en': '• Products with poor quality and poor reviews',
  },
  'pe_prob_reject_3': {
    'ko': '• 사회에 유익이 되지 못하는 상품',
    'en': '• Products that do not benefit society',
  },
  'pe_prob_reject_4': {
    'ko': '• 온라인 최저가보다 높은 가격인 상품',
    'en': '• Products priced higher than the lowest online price',
  },
  'pe_req_edit_success': {
    'ko': '수정 요청이 완료되었습니다.',
    'en': 'Edit request has been submitted successfully.',
  },
  'pe_req_edit_fail': {'ko': '수정 실패: {error}', 'en': 'Edit failed: {error}'},
  'pe_required_field': {'ko': '필수 입력 항목입니다.', 'en': 'This field is required.'},
  'pe_option_limit_error': {
    'ko': '수량, 가격 옵션은 최대 5개까지만 가능합니다.',
    'en': 'Max 5 quantity/price options allowed.',
  },
  'pe_enter_main_image_url': {
    'ko': '메인 이미지 URL 입력',
    'en': 'Enter Main Image URL',
  },
  'pe_enter_add_image_url': {
    'ko': '추가 이미지 {index} URL 입력',
    'en': 'Enter Additional Image {index} URL',
  },
  'pe_edit_requesting': {'ko': '수정 요청 중...', 'en': 'Requesting edit...'},
  'pe_duplicate_qty_error': {'ko': '중복된 수량입니다.', 'en': 'Duplicate quantity.'},
  'auth_signup': {'ko': '회원가입', 'en': 'Sign Up'},
  'auth_login': {'ko': '로그인', 'en': 'Log In'},
  'auth_mail_order_no': {'ko': '통신판매업신고번호', 'en': 'Mail Order Report No.'},
  'auth_rep_name': {'ko': '대표자명', 'en': 'Representative Name'},
  'auth_company_name': {'ko': '상호명', 'en': 'Company Name'},
  'auth_business_address': {'ko': '사업장주소', 'en': 'Business Address'},
  'auth_job_title': {'ko': '직책', 'en': 'Position / Job Title'},
  'auth_brand_name': {
    'ko': '브랜드명(팽이 상점 노출용)',
    'en': 'Brand Name (visible in store)',
  },
  'auth_reset_password': {'ko': '비밀번호 초기화', 'en': 'Reset Password'},
  'auth_agree_terms': {
    'ko': '판매자 센터 가입 이용 약관을 읽었으며 해당내용에 동의합니다',
    'en': 'I have read and agree to the Seller Center Terms of Service',
  },
  'auth_terms_link': {
    'ko': '온라인 판매자용 이용약관링크',
    'en': 'Terms of Service Link for Online Sellers',
  },
  'auth_signup_success': {
    'ko': '회원가입이 완료되었습니다! 로그인 해주세요.',
    'en': 'Registration complete! Please log in.',
  },
  'auth_reset_success': {
    'ko': '비밀번호 재설정 이메일이 발송되었습니다.',
    'en': 'Password reset email sent successfully.',
  },
  'pe_market_link': {
    'ko': '오픈마켓 판매링크(선택)',
    'en': 'Open Market Link (Optional)',
  },
  'pe_shipping_method': {'ko': '배송방식', 'en': 'Shipping Method'},
  'pe_parcel_delivery': {'ko': '택배배송', 'en': 'Parcel Delivery'},
  'pe_regional_delivery': {'ko': '지역배송', 'en': 'Regional Delivery'},
  'pe_delivery_region': {'ko': '배송지역', 'en': 'Delivery Region'},
  'pe_add_region': {'ko': '지역 추가', 'en': 'Add Region'},
  'pe_change_region': {'ko': '지역 변경', 'en': 'Change Region'},
  'pe_region_already_added': {
    'ko': '이미 추가된 지역입니다.',
    'en': 'This region is already added.',
  },
  'pe_no_regions_selected': {
    'ko': '배송할 지역을 추가해 주세요.',
    'en': 'Please add regions for delivery.',
  },
  'pe_propose_button': {'ko': '입점 제안하기', 'en': 'Propose Entry'},
  'pe_propose_success': {
    'ko': '입점 제안이 완료되었습니다.',
    'en': 'Entry proposal has been submitted successfully.',
  },
  'pe_propose_fail': {'ko': '제안 실패: {error}', 'en': 'Proposal failed: {error}'},
  'pe_proposing': {'ko': '제안 등록 중...', 'en': 'Submitting proposal...'},
  'pe_tab_proposal_list': {'ko': '제안 목록', 'en': 'Proposal List'},
  'pe_tab_proposal_form': {'ko': '상품 입점 제안', 'en': 'Product Listing Proposal'},
  'pe_cancel_proposal': {'ko': '제안 취소', 'en': 'Cancel Proposal'},
  'pe_cancel_proposal_confirm': {
    'ko': '이 제안을 취소하시겠습니까?',
    'en': 'Are you sure you want to cancel this proposal?',
  },
  'pe_no': {'ko': '아니오', 'en': 'No'},
  'pe_yes': {'ko': '예', 'en': 'Yes'},
  'pe_cancel_success': {
    'ko': '제안이 취소되었습니다.',
    'en': 'Proposal cancelled successfully.',
  },
  'pe_cancel_fail': {
    'ko': '취소 실패: {error}',
    'en': 'Cancellation failed: {error}',
  },
  'pe_no_proposals': {
    'ko': '제출한 입점 제안이 없습니다.',
    'en': 'No submitted entry proposals.',
  },
  'pe_col_status': {'ko': '상태', 'en': 'Status'},
  'pe_col_shipping_method': {'ko': '배송방식', 'en': 'Shipping Method'},
  'pe_col_category': {'ko': '카테고리', 'en': 'Category'},
  'pe_col_product_name': {'ko': '상품명', 'en': 'Product Name'},
  'pe_col_tax_type': {'ko': '과세구분', 'en': 'Tax Classification'},
  'pe_col_supply_price': {'ko': '상품가격', 'en': 'Product Price'},
  'pe_col_delivery_price': {'ko': '배송비', 'en': 'Delivery Fee'},
  'pe_col_shipping_fee': {'ko': '도서지역 추가 배송비', 'en': 'Remote Area Add. Fee'},
  'pe_col_return_price': {'ko': '반품 배송비', 'en': 'Return Fee'},
  'pe_col_free_shipping': {'ko': '~이상 구매시 무료배송', 'en': 'Free Shipping Over'},
  'pe_col_max_pkg_qty': {'ko': '1상자 최대 포장 수량', 'en': 'Max Packaging Qty'},
  'pe_col_sales_qty': {'ko': '판매수량', 'en': 'Sales Qty/Pricing'},
  'pe_col_delivery_days': {'ko': '배송일', 'en': 'Delivery Days'},
  'pe_col_storage': {'ko': '보관법 및 소비기한', 'en': 'Storage & Expiry'},
  'pe_col_instructions': {'ko': '제품안내', 'en': 'Product Guide'},
  'pe_col_photo': {'ko': '사진', 'en': 'Photo'},
  'pe_status_pending': {'ko': '검토중', 'en': 'Under Review'},
  'pe_status_rejected': {'ko': '입점 거절', 'en': 'Listing Rejected'},
  'pe_status_approved': {'ko': '입점 승인', 'en': 'Listing Approved'},
  'pe_no_free_shipping_label': {'ko': '무료배송 없음', 'en': 'No Free Shipping'},
  'pe_won_or_more': {'ko': '{amount}원 이상', 'en': '{amount} KRW or more'},
  'pe_items_count': {'ko': '{count}개', 'en': '{count} pcs'},
  'pe_won': {'ko': '{amount}원', 'en': '{amount} KRW'},
  'pe_days_range': {'ko': '{min}~{max}일', 'en': '{min}~{max} days'},
  'pe_error_occurred': {
    'ko': '에러 발생: {error}',
    'en': 'Error occurred: {error}',
  },
  'pe_proposal_success_title': {
    'ko': '입점 제안 완료',
    'en': 'Partnership Proposal Submitted',
  },
  'pe_proposal_success_desc': {
    'ko': '제안이 정상적으로 제출되었습니다.',
    'en': 'The proposal has been successfully submitted.',
  },
  'pe_confirm': {'ko': '확인', 'en': 'Confirm'},
  'pe_change_image': {'ko': '사진 변경', 'en': 'Change Image'},
  'pe_delete_image': {'ko': '사진 삭제', 'en': 'Delete Image'},
  'pe_upload_failed': {'ko': '업로드 실패: {error}', 'en': 'Upload failed: {error}'},
  'pe_no_categories': {
    'ko': '등록된 카테고리가 없습니다.',
    'en': 'No registered categories.',
  },
  'pe_val_one_or_more': {'ko': '1 이상', 'en': '1 or more'},
  'pe_val_max': {'ko': '최대 {max}', 'en': 'Max {max}'},
  'pe_cannot_delete': {'ko': '(삭제 불가)', 'en': '(Cannot delete)'},
  'pe_delete_label': {'ko': '(삭제)', 'en': '(Delete)'},
  'pe_image_required': {
    'ko': '메인 이미지를 등록해 주세요.',
    'en': 'Please upload a main image.',
  },
};
