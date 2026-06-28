/// 비로그인 둘러보기 — 구직 지도 vs 기업 홈(채용 지도)
enum GuestBrowseMode { seeker, corporate }

abstract final class GuestBrowseIntent {
  static GuestBrowseMode mode = GuestBrowseMode.seeker;

  static void useSeeker() => mode = GuestBrowseMode.seeker;

  static void useCorporate() => mode = GuestBrowseMode.corporate;
}
