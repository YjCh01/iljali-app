/// 통근버스·관제탑 동의 안내 문구
abstract final class ShuttleCommuteConsentCopy {
  static const routeShareTitle = '통근 노선 공유 · 버스 현황 참여';
  static const routeShareBody =
      '합격하신 회사가 등록한 모든 통근 노선을 앱에서 확인할 수 있습니다.\n\n'
      '실시간 버스 위치를 확인하려면, 이 과정에서 「노선 관제탑」 역할에 참여할 수 있음에 동의해 주세요. '
      '위치 공유 ON/OFF는 본인 선택이며, 다른 이용자와 분쟁이 없도록 안내를 확인해 주세요.\n\n'
      '자차·도보 등으로 이동하시는 경우 「받지 않음」을 선택해 주세요.';

  static const routeShareDeclineNote =
      '노선 공유를 받지 않으면 버스 위치·탑승 안내를 제공하지 않습니다.';

  static const towerParticipationClause =
      '버스 현황 확인 과정에서 관제탑 역할에 참여할 수 있음에 동의합니다.';

  static const trackingOnPromptTitle = '버스 운행 중 위치 공유';
  static const trackingOnPromptBody =
      '첫 정류장 운행 시각입니다.\n'
      '지금부터 버스 운행 중 위치를 공유(ON)하는 것에 동의하시겠습니까?\n\n'
      '동의하지 않으면 위치는 공유되지 않으며, 언제든 직접 켜거나 끌 수 있습니다.';

  static const driverConsentTitle = '통근 운전자 관제탑 동의';
  static const driverConsentBody =
      '회사와 운전자 모두 동의한 경우, 지정된 운전자의 위치가 '
      '해당 노선 탑승자에게 실시간으로 표시됩니다.\n\n'
      '위치 공유 ON/OFF는 운전자 본인의 선택입니다.';
}
