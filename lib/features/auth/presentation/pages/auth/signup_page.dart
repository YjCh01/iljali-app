import 'package:flutter/material.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/presentation/pages/auth/corporate_sign_up_flow.dart';
import 'package:map/features/auth/presentation/pages/auth/individual_sign_up_flow.dart';

/// 회원가입 화면
class SignUpPage extends StatelessWidget {
  const SignUpPage({
    super.key,
    required this.memberType,
  });

  final MemberType memberType;

  @override
  Widget build(BuildContext context) {
    if (memberType == MemberType.corporate) {
      return const CorporateSignUpFlow();
    }
    return const IndividualSignUpFlow();
  }
}
