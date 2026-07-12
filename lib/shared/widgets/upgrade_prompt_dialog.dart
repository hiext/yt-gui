import 'package:flutter/material.dart';

import '../../core/models/license_models.dart';
import '../../core/controllers/license_controller.dart';

/// Banner-style upgrade prompt shown inline when a feature is gated. Simpler
/// than a full AlertDialog so it doesn't block the user's flow.
class UpgradeBanner extends StatelessWidget {
  const UpgradeBanner({
    super.key,
    required this.tier,
    required this.feature,
    this.onUpgrade,
  });

  final LicenseTier tier;
  final String feature;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.workspace_premium_outlined,
                color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            if (onUpgrade != null)
              TextButton(
                onPressed: onUpgrade,
                child: Text(_buttonLabel),
              ),
          ],
        ),
      ),
    );
  }

  String get _message => switch (tier) {
        LicenseTier.free => '升级到 Pro / Team 解锁 $feature',
        LicenseTier.pro => '升级到 Team 解锁 $feature',
        LicenseTier.team => '$feature（已解锁）',
      };

  String get _buttonLabel => switch (tier) {
        LicenseTier.free => '了解 Pro',
        LicenseTier.pro => '了解 Team',
        LicenseTier.team => '',
      };
}

/// Full-screen dialog shown from the app shell after activation succeeds or
/// when the user clicks "Upgrade" from the nav rail.
class UpgradeDialog extends StatelessWidget {
  const UpgradeDialog({super.key, required this.controller});

  final LicenseController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActivated = controller.tier != LicenseTier.free;
    final codeCtrl = TextEditingController();

    return AlertDialog(
      title: Text(isActivated ? '升级 / 管理许可证' : '激活 Pro / Team'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本：${_tierLabel(controller.tier)}',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            // Quick tier comparison
            _TierRow(label: '下载并发', free: '1', pro: '8', team: '8'),
            _TierRow(label: 'AI 切片/视频', free: '3', pro: '无限', team: '无限'),
            _TierRow(label: '批量下载', free: '✗', pro: '✓', team: '✓'),
            _TierRow(label: '云端同步', free: '✗', pro: '✗', team: '✓'),
            const SizedBox(height: 16),
            if (!isActivated) ...[
              TextField(
                key: const Key('upgrade-code-field'),
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'HIEXT-XXXXX-XXXXX-XXXXX-XXXXX',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              if (controller.state.expiresAt != null)
                Text('到期时间：${_fmt(controller.state.expiresAt)}'),
              Text('离线宽限至：${_fmt(controller.state.graceUntil)}'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        if (!isActivated)
          FilledButton(
            key: const Key('upgrade-activate-button'),
            onPressed: () async {
              final outcome = await controller.activate(codeCtrl.text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(outcome.message)),
                );
                if (outcome.success) Navigator.of(context).pop();
              }
            },
            child: const Text('激活'),
          ),
      ],
    );
  }

  String _tierLabel(LicenseTier t) => switch (t) {
        LicenseTier.free => '免费版',
        LicenseTier.pro => '专业版 Pro',
        LicenseTier.team => '团队版 Team',
      };

  String _fmt(DateTime? d) =>
      d == null ? '—' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.label,
    required this.free,
    required this.pro,
    required this.team,
  });

  final String label;
  final String free;
  final String pro;
  final String team;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: theme.textTheme.bodySmall)),
          Expanded(child: Text(free, textAlign: TextAlign.center, style: theme.textTheme.bodySmall)),
          Expanded(
            child: Text(pro, textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(team, textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
