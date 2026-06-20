import 'package:flutter/material.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';

class AdminWalletPanel extends StatefulWidget {
  const AdminWalletPanel({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminWalletPanel> createState() => _AdminWalletPanelState();
}

class _AdminWalletPanelState extends State<AdminWalletPanel> {
  final _companyKeyCtrl = TextEditingController(text: '1000000001');
  final _creditsCtrl = TextEditingController(text: '30');
  final _slotsCtrl = TextEditingController(text: '30');
  Map<String, dynamic>? _wallet;

  @override
  void dispose() {
    _companyKeyCtrl.dispose();
    _creditsCtrl.dispose();
    _slotsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    final key = _companyKeyCtrl.text.trim();
    if (key.isEmpty) return;
    await widget.controller.run(
      () async {
        _wallet = await widget.controller.client.getWallet(key);
      },
      successMessage: '지갑 조회 완료',
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return AdminPanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminCard(
            title: '푸시·거점 이용권 부여',
            subtitle: '사업자번호(BRN) 기준 — package_credits · location_slots',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminField(label: '사업자번호 (BRN)', controller: _companyKeyCtrl),
                Row(
                  children: [
                    Expanded(
                      child: AdminField(
                        label: '패키지 횟수',
                        controller: _creditsCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AdminField(
                        label: '거점 슬롯 (선택)',
                        controller: _slotsCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    FilledButton(
                      onPressed: !c.apiReady || c.busy
                          ? null
                          : () => c.run(
                                () => c.client.grantWallet(
                                  companyKey: _companyKeyCtrl.text.trim(),
                                  packageCredits:
                                      int.tryParse(_creditsCtrl.text) ?? 0,
                                  locationSlots:
                                      int.tryParse(_slotsCtrl.text),
                                ),
                                successMessage: '이용권 부여 완료',
                              ).then((_) => _loadWallet()),
                      child: const Text('이용권 부여'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: !c.apiReady || c.busy ? null : _loadWallet,
                      child: const Text('현재 잔액 조회'),
                    ),
                  ],
                ),
                if (_wallet != null) ...[
                  const SizedBox(height: 16),
                  _WalletSummary(data: _wallet!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletSummary extends StatelessWidget {
  const _WalletSummary({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BRN: ${data['company_key'] ?? data['brn'] ?? ''}'),
          Text('package_credits: ${data['package_credits']}'),
          Text('available_push_credits: ${data['available_push_credits']}'),
          Text('location_slots: ${data['total_location_slots'] ?? data['location_slots_from_packages']}'),
        ],
      ),
    );
  }
}
