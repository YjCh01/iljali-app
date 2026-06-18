/// 출근 확인 방식
enum CheckInMethod {
  gps('gps', 'GPS'),
  qr('qr', 'QR코드');

  const CheckInMethod(this.code, this.label);

  final String code;
  final String label;

  static CheckInMethod? fromCode(String? code) {
    if (code == null) return null;
    for (final m in values) {
      if (m.code == code) return m;
    }
    return null;
  }
}
