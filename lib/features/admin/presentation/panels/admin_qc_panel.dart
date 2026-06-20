import 'package:flutter/material.dart';
import 'package:map/core/sync/local_remote_sync_service.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';

class AdminQcPanel extends StatefulWidget {
  const AdminQcPanel({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminQcPanel> createState() => _AdminQcPanelState();
}

class _AdminQcPanelState extends State<AdminQcPanel> {
  final _seekerCountCtrl = TextEditingController(text: '1000');
  final _startIndexCtrl = TextEditingController(text: '1');
  final _postIdCtrl = TextEditingController(text: 'qc_post_real_001');
  final _distributeMaxCtrl = TextEditingController(text: '100');

  @override
  void dispose() {
    _seekerCountCtrl.dispose();
    _startIndexCtrl.dispose();
    _postIdCtrl.dispose();
    _distributeMaxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return AdminPanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminCard(
            title: '가상 구직자 시드',
            subtitle: 'seeker-0001@qc.iljari.co.kr 형식 · 최대 5,000',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AdminField(
                        label: '생성 수',
                        controller: _seekerCountCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AdminField(
                        label: '시작 번호',
                        controller: _startIndexCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                FilledButton(
                  onPressed: !c.apiReady || c.busy
                      ? null
                      : () => c.run(
                            () => c.client.seedSeekers(
                              count: int.tryParse(_seekerCountCtrl.text) ?? 1000,
                              startIndex: int.tryParse(_startIndexCtrl.text) ?? 1,
                            ),
                            successMessage: '구직자 시드 완료',
                          ),
                  child: const Text('구직자 생성'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AdminCard(
            title: '지원 · 채팅 시나리오',
            subtitle: '선택 공고에 가상 지원 + 샘플 채팅(5건)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminField(label: '공고 ID', controller: _postIdCtrl),
                AdminField(
                  label: '공고당 지원 수',
                  controller: _distributeMaxCtrl,
                  keyboardType: TextInputType.number,
                ),
                FilledButton(
                  onPressed: !c.apiReady || c.busy
                      ? null
                      : () => c.run(
                            () => c.client.distributeApplications(
                              postId: _postIdCtrl.text.trim(),
                              maxApplications:
                                  int.tryParse(_distributeMaxCtrl.text) ?? 100,
                            ),
                            successMessage: '지원·채팅 샘플 생성 완료',
                          ),
                  child: const Text('지원 분포 생성'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: !c.apiReady || c.busy
                      ? null
                      : () => c.run(
                            () async {
                              await LocalRemoteSyncService().pullFromServer();
                            },
                            successMessage: '앱 sync pull 완료',
                          ),
                  child: const Text('서버 → 앱 sync pull'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const AdminCard(
            title: 'QC 로그인 계정 (참고)',
            child: Text(
              '구직자 테스트: seeker-0001@qc.iljari.co.kr / QcTest1234!\n'
              '기업: 테스트기업 알파 (BRN 1000000001)',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
