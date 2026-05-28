/// 사업자 유형
enum BusinessEntityType {
  soleProprietor,
  corporation,
}

extension BusinessEntityTypeX on BusinessEntityType {
  String get label => switch (this) {
        BusinessEntityType.soleProprietor => '개인사업자',
        BusinessEntityType.corporation => '법인',
      };
}
