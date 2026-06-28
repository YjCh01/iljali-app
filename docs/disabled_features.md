# 비활성 기능 레지스트리 (MVP)

MVP는 **일용직** 중심(대형 물류·식품 공장) + **아웃소싱·도급사** 플로우에 집중합니다.  
일반직·계약직·상시직 코드는 **삭제하지 않고** dart-define 플래그로 UI·동기화만 차단합니다.

## 목록 조회 방법

AI 또는 개발자가 비활성 기능을 나열하려면:

1. **`lib/core/config/product_feature_flags.dart`** — `ProductFeatureFlags.disabledFeatures` 또는 `listDisabledFeatures()`
2. **이 문서** — 아래 표

```dart
import 'package:map/core/config/product_feature_flags.dart';

void main() {
  for (final line in ProductFeatureFlags.listDisabledFeatures()) {
    print(line);
  }
}
```

## MVP 기본값 (dart-define 미설정 시)

| 플래그 | 기본값 | 의미 |
|--------|--------|------|
| `ENABLE_WORKER_GENERAL` | **false** | 일반직 공고 비활성 |
| `ENABLE_WORKER_CONTRACT` | **true** | 계약직 공고 (기본 활성) |
| `ENABLE_PERMANENT_HIRE` | **false** | 상시직 채용·합격·동기화 비활성 |
| `ENABLE_PREMIUM_PARTNER_WIZARD` | **true** | 제휴사(쿠팡·다이소 등) 위저드 유지 |
| `ENABLE_ENTERPRISE_OUTSOURCING` | **true** | 아웃소싱·도급 플로우 유지 |
| `ENABLE_HIRING_COMMISSION` | **false** | 일용직 채용 성공 수수료·결제·에스컬레이션 비활성 (제휴 채널만 `true`) |
| `ENABLE_EMPLOYER_TRUST_DISPLAY` | **false** | 고용주 평점·신뢰100·배지 (페이즈 2) |
| `ENABLE_SEEKER_EMPLOYER_RATING` | **false** | 구직자 고용주 평가 UI (페이즈 2) |

허용 고용 유형: **일용직 · 단기알바** (`WorkerCategory.daily`, `WorkerCategory.shortTerm`).  
단기알바는 주5일·교대 등 유연 일정, 일용직은 달력 날짜 지정.

**메인 앱 과금**: 공고·지원·출근 확인 **무료**. 유료는 **알림핀 패키지** 등 선택 구매만 (`PUSH_PACKAGE_PRICING.md`).

## 현재 비활성 기능 (MVP 기본)

| ID | 표시명 | 플래그 |
|----|--------|--------|
| `worker_general` | 일반직 공고 | `ENABLE_WORKER_GENERAL` |
| `worker_contract` | 계약직 공고 | `ENABLE_WORKER_CONTRACT` |
| `permanent_hire` | 상시직 채용 | `ENABLE_PERMANENT_HIRE` |
| `hiring_commission` | 일용직 채용 성공 수수료 | `ENABLE_HIRING_COMMISSION` |
| `employer_trust_display` | 고용주 평점·신뢰 배지 | `ENABLE_EMPLOYER_TRUST_DISPLAY` |
| `seeker_employer_rating` | 구직자 고용주 평가 | `ENABLE_SEEKER_EMPLOYER_RATING` |

## 재활성 워크플로

1. `map/dart-define.example` 참고해 `--dart-define=FLAG=true` 추가
2. 예: `flutter run --dart-define=ENABLE_PERMANENT_HIRE=true`
3. 앱 **완전 재시작** (hot reload로는 const 플래그 반영 안 됨)
4. 해당 기능 UI·플로우 수동 확인
5. 선택적: `product_feature_flags.dart`의 `disabledFeatures` 항목과 이 문서 동기화

### 예시 — 상시직만 다시 켜기

```powershell
cd d:\1jari\map
flutter run --dart-define=ENABLE_PERMANENT_HIRE=true
```

### 예시 — 일반·계약·상시직 모두 켜기

```powershell
flutter run `
  --dart-define=ENABLE_WORKER_GENERAL=true `
  --dart-define=ENABLE_WORKER_CONTRACT=true `
  --dart-define=ENABLE_PERMANENT_HIRE=true
```

## 관련 파일

- 플래그 정의: `lib/core/config/product_feature_flags.dart`
- 빌드 예시: `dart-define.example`
- 단위 테스트: `test/core/config/product_feature_flags_test.dart`
