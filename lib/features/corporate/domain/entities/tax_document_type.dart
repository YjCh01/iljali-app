/// 증빙 유형
enum TaxDocumentType {
  transactionStatement,
  taxInvoice,
  cashReceipt,
}

extension TaxDocumentTypeX on TaxDocumentType {
  String get label => switch (this) {
        TaxDocumentType.transactionStatement => '거래명세서',
        TaxDocumentType.taxInvoice => '세금계산서',
        TaxDocumentType.cashReceipt => '현금영수증',
      };
}
