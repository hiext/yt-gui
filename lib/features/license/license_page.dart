import 'package:flutter/material.dart';

import '../../core/controllers/license_controller.dart';
import '../../core/models/license_models.dart';

/// License activation & status page. Lets the user enter an activation code,
/// see the current tier, and deactivate to release the device seat.
class LicenseStatusPage extends StatefulWidget {
  const LicenseStatusPage({super.key, required this.controller});

  final LicenseController controller;

  @override
  State<LicenseStatusPage> createState() => _LicensePageState();
}

class _LicensePageState extends State<LicenseStatusPage> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final outcome = await widget.controller.activate(_codeCtrl.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = outcome.message;
      _isError = !outcome.success;
    });
    if (outcome.success) _codeCtrl.clear();
  }

  Future<void> _deactivate() async {
    setState(() => _busy = true);
    await widget.controller.deactivate();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = '已取消激活，恢复到免费版';
      _isError = false;
    });
  }

  String _tierLabel(LicenseTier tier) => switch (tier) {
        LicenseTier.free => '免费版 (Free)',
        LicenseTier.pro => '专业版 (Pro)',
        LicenseTier.team => '团队版 (Team)',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final tier = widget.controller.tier;
        final isActivated = tier != LicenseTier.free;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('许可证与升级', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '当前版本：${_tierLabel(tier)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isActivated
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Tier comparison
            _TierComparisonCard(currentTier: tier),
            const SizedBox(height: 24),

            if (!isActivated) ...[
              const _ProUpsellCard(),
              const SizedBox(height: 24),
            ],

            if (!isActivated) ...[
              Text('输入激活码', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                key: const Key('license-code-field'),
                controller: _codeCtrl,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'HIEXT-XXXXX-XXXXX-XXXXX-XXXXX',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('license-activate-button'),
                onPressed: _busy ? null : _activate,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.key_outlined),
                label: Text(_busy ? '激活中...' : '激活'),
              ),
            ] else ...[
              _ActivatedInfo(state: state),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('license-deactivate-button'),
                onPressed: _busy ? null : _deactivate,
                icon: const Icon(Icons.link_off_outlined),
                label: const Text('取消激活（释放本设备）'),
              ),
            ],

            if (_message != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _isError
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TierComparisonCard extends StatelessWidget {
  const _TierComparisonCard({required this.currentTier});

  final LicenseTier currentTier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, String, String, String)>[
      ('下载并发', '1', '8', '8'),
      ('批量下载', '✗', '✓', '✓'),
      ('AI 切片数/视频', '3', '无限', '无限'),
      ('云端同步', '✗', '✗', '✓'),
      ('设备数', '1', '3', '10'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              children: [
                const SizedBox(),
                _header(theme, 'Free', currentTier == LicenseTier.free),
                _header(theme, 'Pro', currentTier == LicenseTier.pro),
                _header(theme, 'Team', currentTier == LicenseTier.team),
              ],
            ),
            for (final row in rows)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(row.$1, style: theme.textTheme.bodyMedium),
                  ),
                  _cell(theme, row.$2),
                  _cell(theme, row.$3),
                  _cell(theme, row.$4),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, String label, bool active) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            color: active ? theme.colorScheme.primary : null,
            fontWeight: active ? FontWeight.bold : null,
          ),
        ),
      );

  Widget _cell(ThemeData theme, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      );
}

class _ProUpsellCard extends StatelessWidget {
  const _ProUpsellCard();

  static const _benefits = <(IconData, String, String)>[
    (Icons.download_done_outlined, '8 路并发下载', '同时下载多个清晰度/多个视频，速度拉满'),
    (Icons.auto_awesome_outlined, '无限 AI 智能切片', '每个视频不再限制 3 条，随意生成高光片段'),
    (Icons.playlist_add_check_outlined, '批量下载', '一次勾选多个格式/多条链接，排队自动下'),
    (Icons.devices_outlined, '3 台设备', '一份授权，最多绑定 3 台电脑同时使用'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium,
                    color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  '专业版 Pro',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '¥128',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '买断永久 · 一次付费',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final benefit in _benefits) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(benefit.$1,
                      size: 20, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          benefit.$2,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          benefit.$3,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Text(
              '在下方输入激活码即可解锁 Pro，永久有效，无需续费。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivatedInfo extends StatelessWidget {
  const _ActivatedInfo({required this.state});

  final LicenseState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String fmt(DateTime? d) =>
        d == null ? '—' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('已激活', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text('激活时间：${fmt(state.activatedAt)}'),
            if (state.expiresAt != null) Text('到期时间：${fmt(state.expiresAt)}'),
            Text('离线宽限至：${fmt(state.graceUntil)}'),
          ],
        ),
      ),
    );
  }
}
