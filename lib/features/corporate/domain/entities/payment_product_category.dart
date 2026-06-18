/// 결제 상품 구분 (증빙·회계 분류)
enum PaymentProductCategory {
  hiringCommission,
  pushPackage,
  pushNotification,
  pushTicket,
  permanentCommission,
}

extension PaymentProductCategoryX on PaymentProductCategory {
  String get label => switch (this) {
        PaymentProductCategory.hiringCommission => '채용 수수료',
        PaymentProductCategory.pushPackage => '일자리 알림핀',
        PaymentProductCategory.pushNotification => 'PUSH·노출 결제',
        PaymentProductCategory.pushTicket => 'PUSH 알림권',
        PaymentProductCategory.permanentCommission => '상시직 수수료',
      };
}
