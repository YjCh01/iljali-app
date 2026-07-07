import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/member_type.dart';

/// 개인/기업 회원 유형 탭
class AccountRecoveryMemberTabs extends StatelessWidget {
  const AccountRecoveryMemberTabs({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final MemberType value;
  final ValueChanged<MemberType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TabButton(
            label: '개인회원',
            selected: value == MemberType.individual,
            onTap: () => onChanged(MemberType.individual),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TabButton(
            label: '기업회원',
            selected: value == MemberType.corporate,
            onTap: () => onChanged(MemberType.corporate),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.searchBarBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
