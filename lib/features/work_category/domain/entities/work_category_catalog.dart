import 'package:flutter/material.dart';
import 'package:map/features/work_category/domain/entities/work_category_definition.dart';

/// 단기알바·일용직 현장 업무 카테고리 (30종)
abstract final class WorkCategoryCatalog {
  static const logistics = WorkCategoryDefinition(
    id: 'logistics',
    label: '물류·창고',
    icon: Icons.warehouse_outlined,
    keywords: ['물류', '창고', '센터', '풀필', 'wms', '입고', '출고'],
  );

  static const picking = WorkCategoryDefinition(
    id: 'picking',
    label: '피킹·포장',
    icon: Icons.inventory_2_outlined,
    keywords: ['피킹', '포장', '패킹', '손해보상', '택배포장'],
  );

  static const sorting = WorkCategoryDefinition(
    id: 'sorting',
    label: '분류·검수',
    icon: Icons.fact_check_outlined,
    keywords: ['분류', '검수', '소팅', '선별', '검품'],
  );

  static const loading = WorkCategoryDefinition(
    id: 'loading',
    label: '상하차',
    icon: Icons.local_shipping_outlined,
    keywords: ['상하차', '하역', '적재', '컨테이너', '지게차'],
  );

  static const delivery = WorkCategoryDefinition(
    id: 'delivery',
    label: '배송·퀵',
    icon: Icons.delivery_dining_outlined,
    keywords: ['배송', '퀵', '라이더', '배달', '드라이버'],
  );

  static const foodProduction = WorkCategoryDefinition(
    id: 'food_production',
    label: '식품가공',
    icon: Icons.set_meal_outlined,
    keywords: ['식품', '가공', '공장', '생산', 'HACCP', '냉동'],
  );

  static const kitchenHelper = WorkCategoryDefinition(
    id: 'kitchen_helper',
    label: '조리보조',
    icon: Icons.restaurant_outlined,
    keywords: ['조리', '주방', '보조', '쿠킹', '식당', '급식'],
  );

  static const cleaning = WorkCategoryDefinition(
    id: 'cleaning',
    label: '청소·미화',
    icon: Icons.cleaning_services_outlined,
    keywords: ['청소', '미화', '환경', '빌딩', '관리'],
  );

  static const eventStaff = WorkCategoryDefinition(
    id: 'event_staff',
    label: '행사진행',
    icon: Icons.celebration_outlined,
    keywords: ['행사', '이벤트', '전시', '페스티벌', 'MC', '스태프'],
  );

  static const promotion = WorkCategoryDefinition(
    id: 'promotion',
    label: '홍보·판촉',
    icon: Icons.campaign_outlined,
    keywords: ['홍보', '판촉', '프로모', '체험', '샘플링'],
  );

  static const survey = WorkCategoryDefinition(
    id: 'survey',
    label: '설문·리서치',
    icon: Icons.poll_outlined,
    keywords: ['설문', '리서치', '조사', '아르바이트', '현장조사'],
  );

  static const retail = WorkCategoryDefinition(
    id: 'retail',
    label: '매장판매',
    icon: Icons.storefront_outlined,
    keywords: ['매장', '판매', '리테일', '편의점', '마트', '다이소'],
  );

  static const cashier = WorkCategoryDefinition(
    id: 'cashier',
    label: '계산·포스',
    icon: Icons.point_of_sale_outlined,
    keywords: ['계산', '포스', '캐셔', '카운터'],
  );

  static const inventory = WorkCategoryDefinition(
    id: 'inventory',
    label: '재고관리',
    icon: Icons.bar_chart_outlined,
    keywords: ['재고', '실사', '카운트', 'inventory'],
  );

  static const assembly = WorkCategoryDefinition(
    id: 'assembly',
    label: '조립·생산',
    icon: Icons.precision_manufacturing_outlined,
    keywords: ['조립', '생산', '라인', '공정', '제조'],
  );

  static const qualityCheck = WorkCategoryDefinition(
    id: 'quality_check',
    label: '품질검사',
    icon: Icons.verified_outlined,
    keywords: ['품질', 'QC', '검사', '불량'],
  );

  static const officeHelper = WorkCategoryDefinition(
    id: 'office_helper',
    label: '사무보조',
    icon: Icons.description_outlined,
    keywords: ['사무', '문서', '입력', '엑셀', '스캔', '자료'],
  );

  static const callCenter = WorkCategoryDefinition(
    id: 'call_center',
    label: '콜·고객응대',
    icon: Icons.support_agent_outlined,
    keywords: ['콜', '상담', '고객', 'CS', '응대', '아웃바운드'],
  );

  static const moving = WorkCategoryDefinition(
    id: 'moving',
    label: '이사·운반',
    icon: Icons.move_to_inbox_outlined,
    keywords: ['이사', '운반', '짐', '포장이사'],
  );

  static const constructionHelper = WorkCategoryDefinition(
    id: 'construction_helper',
    label: '현장보조',
    icon: Icons.construction_outlined,
    keywords: ['현장', '공사', '건설', '보조', '양중'],
  );

  static const security = WorkCategoryDefinition(
    id: 'security',
    label: '경비·안내',
    icon: Icons.security_outlined,
    keywords: ['경비', '안내', '출입', '통제', '가드'],
  );

  static const parking = WorkCategoryDefinition(
    id: 'parking',
    label: '주차관리',
    icon: Icons.local_parking_outlined,
    keywords: ['주차', '발렛', 'parking'],
  );

  static const driving = WorkCategoryDefinition(
    id: 'driving',
    label: '운전·배차',
    icon: Icons.directions_car_outlined,
    keywords: ['운전', '배차', '버스', '셔틀', '탑승'],
  );

  static const agriculture = WorkCategoryDefinition(
    id: 'agriculture',
    label: '농업·수확',
    icon: Icons.agriculture_outlined,
    keywords: ['농업', '수확', '과수', '하우스', '농장'],
  );

  static const childcare = WorkCategoryDefinition(
    id: 'childcare',
    label: '돌봄·보육',
    icon: Icons.child_care_outlined,
    keywords: ['돌봄', '보육', '유치', '키즈', '아이'],
  );

  static const educationHelper = WorkCategoryDefinition(
    id: 'education_helper',
    label: '교육보조',
    icon: Icons.school_outlined,
    keywords: ['교육', '학원', '튜터', '보조교사', '강의'],
  );

  static const hotel = WorkCategoryDefinition(
    id: 'hotel',
    label: '숙박·호텔',
    icon: Icons.hotel_outlined,
    keywords: ['호텔', '숙박', '리조트', '객실', '프론트'],
  );

  static const beauty = WorkCategoryDefinition(
    id: 'beauty',
    label: '미용·뷰티',
    icon: Icons.face_retouching_natural_outlined,
    keywords: ['미용', '뷰티', '헤어', '네일', '피부'],
  );

  static const petCare = WorkCategoryDefinition(
    id: 'pet_care',
    label: '반려동물',
    icon: Icons.pets_outlined,
    keywords: ['반려', '펫', '동물', '애견', '캣'],
  );

  static const other = WorkCategoryDefinition(
    id: 'other',
    label: '기타현장',
    icon: Icons.work_outline,
    keywords: [],
  );

  static const List<WorkCategoryDefinition> all = [
    logistics,
    picking,
    sorting,
    loading,
    delivery,
    foodProduction,
    kitchenHelper,
    cleaning,
    eventStaff,
    promotion,
    survey,
    retail,
    cashier,
    inventory,
    assembly,
    qualityCheck,
    officeHelper,
    callCenter,
    moving,
    constructionHelper,
    security,
    parking,
    driving,
    agriculture,
    childcare,
    educationHelper,
    hotel,
    beauty,
    petCare,
    other,
  ];

  static WorkCategoryDefinition? findById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }
}
