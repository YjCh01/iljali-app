import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/data/repositories/account_recovery_repository.dart';

/// 찾기/재설정 방식 선택 (본인인증·아이핀 제외)
class AccountRecoveryMethodSelector extends StatelessWidget {
  const AccountRecoveryMethodSelector({
    super.key,
    required this.memberType,
    this.findMethod,
    this.resetMethod,
    this.onFindMethodChanged,
    this.onResetMethodChanged,
  });

  final MemberType memberType;
  final AccountFindMethod? findMethod;
  final AccountResetMethod? resetMethod;
  final ValueChanged<AccountFindMethod>? onFindMethodChanged;
  final ValueChanged<AccountResetMethod>? onResetMethodChanged;

  bool get _isCorporate => memberType == MemberType.corporate;

  @override
  Widget build(BuildContext context) {
    if (findMethod != null && onFindMethodChanged != null) {
      return Column(
        children: [
          _MethodTile(
            label: _isCorporate ? '사업자등록번호로 찾기' : '연락처로 찾기',
            selected: findMethod == AccountFindMethod.phone,
            onTap: () => onFindMethodChanged!(AccountFindMethod.phone),
          ),
          const SizedBox(height: 8),
          _MethodTile(
            label: '이메일로 찾기',
            selected: findMethod == AccountFindMethod.email,
            onTap: () => onFindMethodChanged!(AccountFindMethod.email),
          ),
        ],
      );
    }

    return Column(
      children: [
        _MethodTile(
          label: '연락처로 찾기',
          selected: resetMethod == AccountResetMethod.phone,
          onTap: () => onResetMethodChanged!(AccountResetMethod.phone),
        ),
        const SizedBox(height: 8),
        _MethodTile(
          label: '이메일로 찾기',
          selected: resetMethod == AccountResetMethod.email,
          onTap: () => onResetMethodChanged!(AccountResetMethod.email),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
