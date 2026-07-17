/// 통근버스·관제탑 동의 안내 문구
abstract final class ShuttleCommuteConsentCopy {
  static const routeShareTitle = '통근 노선 공유 · 버스 현황 참여';
  static const routeShareBody =
      '합격하신 회사가 등록한 모든 통근 노선을 앱에서 확인할 수 있습니다.\n\n'
      '실시간 버스 위치는 어드민이 승인한 「버스위치 공유 담당」 1명이 자신의 위치를 '
      '공유하는 방식으로 제공됩니다. 본인은 위치를 공유하지 않으면서 다른 분의 위치만 '
      '확인하는 것은 어렵기 때문에, 확인에 동의하시면 본인이 담당으로 지정될 경우 '
      '위치를 공유하는 데에도 동의하는 것으로 간주됩니다.\n\n'
      '자차·도보 등으로 이동하시는 경우 「받지 않음」을 선택해 주세요.';

  static const routeShareDeclineNote =
      '노선 공유를 받지 않으면 버스 위치·탑승 안내를 제공하지 않습니다.';

  static const towerParticipationClause =
      '버스 현황을 확인하는 대신, 본인이 버스위치 공유 담당으로 지정되면 '
      '위치를 공유하는 데 동의합니다.';

  static const trackingOnPromptTitle = '버스 운행 시작 시각';
  static const trackingOnPromptBody =
      '오늘 버스위치 공유 담당으로 지정되어 있습니다.\n'
      '지금부터 위치 공유를 시작하시겠습니까?\n\n'
      '관제 화면에서 언제든 직접 켜고 끌 수 있습니다.';
}
