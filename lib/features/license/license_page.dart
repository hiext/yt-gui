import 'package:flutter/material.dart';

import '../../core/controllers/license_controller.dart';
import '../../core/models/license_models.dart';
import '../../core/services/license_purchase_link.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utils/platform_utils.dart';

/// License activation & status page. Lets the user enter an activation code,
/// see the current tier, and deactivate to release the device seat.
class LicenseStatusPage extends StatefulWidget {
  const LicenseStatusPage({
    super.key,
    required this.controller,
    this.purchaseLinks = const LicensePurchaseLinkProvider(),
    this.uriOpener = openExternalUri,
  });

  final LicenseController controller;
  final LicensePurchaseLinkProvider purchaseLinks;
  final Future<void> Function(Uri uri) uriOpener;

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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.licenseReleaseDeviceTitle),
        content: Text(
          l10n.licenseReleaseDeviceConfirm(l10n.licenseCurrentDevice),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.licenseCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.licenseReleaseDeviceAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final outcome = await widget.controller.deactivate();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = outcome.success
          ? l10n.licenseCurrentDeviceReleased
          : l10n.licenseOperationFailed(outcome.message ?? 'unknown error');
      _isError = !outcome.success;
    });
  }

  Future<void> _purchase(LicenseTier tier) async {
    final destination = widget.purchaseLinks.destinationFor(tier);
    final l10n = AppLocalizations.of(context)!;
    try {
      await widget.uriOpener(destination.uri);
      if (!mounted) return;
      setState(() {
        _message = destination.isEmailFallback
            ? l10n.licensePurchaseEmailOpened
            : l10n.licensePurchasePageOpened;
        _isError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = l10n.licensePurchaseOpenFailed(destination.uri.toString());
        _isError = true;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    final outcome = await widget.controller.refresh();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = false;
      _message = outcome.success
          ? l10n.licenseRefreshSuccess
          : l10n.licenseRefreshFailed(outcome.message ?? 'unknown error');
      _isError = !outcome.success;
    });
  }

  Future<void> _releaseDevice(LicenseDevice device) async {
    final l10n = AppLocalizations.of(context)!;
    final name = device.deviceName?.trim().isNotEmpty == true
        ? device.deviceName!.trim()
        : device.platform ?? l10n.licenseUnknownDevice;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.licenseReleaseDeviceTitle),
        content: Text(l10n.licenseReleaseDeviceConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.licenseCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.licenseReleaseDeviceAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final outcome = await widget.controller.releaseDevice(device);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = outcome.success
          ? l10n.licenseDeviceReleased(name)
          : l10n.licenseOperationFailed(outcome.message ?? 'unknown error');
      _isError = !outcome.success;
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
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final tier = widget.controller.tier;
        final isActivated = state.isActivated;
        final busy = _busy || widget.controller.isSyncing;
        final syncError = widget.controller.syncError;
        final showSyncError =
            syncError != null && (_message == null || !_isError);
        final displayMessage = showSyncError
            ? l10n.licenseRefreshFailed(syncError)
            : _message;
        final displayIsError = showSyncError || _isError;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(l10n.licenseTitle, style: theme.textTheme.headlineSmall),
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

            _PurchaseJourneyCard(
              purchaseLinks: widget.purchaseLinks,
              onPurchase: _purchase,
            ),
            const SizedBox(height: 24),

            if (!isActivated) ...[
              Text('输入激活码', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                key: const Key('license-code-field'),
                controller: _codeCtrl,
                enabled: !busy,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'HIEXT-XXXXX-XXXXX-XXXXX-XXXXX',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('license-activate-button'),
                onPressed: busy ? null : _activate,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.key_outlined),
                label: Text(
                  busy ? l10n.licenseActivating : l10n.licenseActivate,
                ),
              ),
            ] else ...[
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  key: const Key('license-refresh-button'),
                  onPressed: busy ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    busy ? l10n.licenseRefreshing : l10n.licenseRefresh,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ActivatedInfo(state: state),
              const SizedBox(height: 12),
              _DeviceManager(
                devices: widget.controller.devices,
                activeDevices: widget.controller.activeDeviceCount,
                maxDevices: widget.controller.maxDevices,
                busy: busy,
                onRelease: _releaseDevice,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('license-deactivate-button'),
                onPressed: busy ? null : _deactivate,
                icon: const Icon(Icons.link_off_outlined),
                label: Text(l10n.licenseDeactivateCurrent),
              ),
            ],

            if (displayMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: displayIsError
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  displayMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: displayIsError
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

class _PurchaseJourneyCard extends StatelessWidget {
  const _PurchaseJourneyCard({
    required this.purchaseLinks,
    required this.onPurchase,
  });

  final LicensePurchaseLinkProvider purchaseLinks;
  final ValueChanged<LicenseTier> onPurchase;

  static const _benefits = <(IconData, String, String)>[
    (Icons.download_done_outlined, '8 路并发下载', '同时下载多个清晰度/多个视频，速度拉满'),
    (Icons.auto_awesome_outlined, '无限 AI 智能切片', '每个视频不再限制 3 条，随意生成高光片段'),
    (Icons.playlist_add_check_outlined, '批量下载', '一次勾选多个格式/多条链接，排队自动下'),
    (Icons.devices_outlined, '3 台设备', '一份授权，最多绑定 3 台电脑同时使用'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final proEmailFallback = purchaseLinks
        .destinationFor(LicenseTier.pro)
        .isEmailFallback;
    final teamEmailFallback = purchaseLinks
        .destinationFor(LicenseTier.team)
        .isEmailFallback;
    final anyEmailFallback = proEmailFallback || teamEmailFallback;
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.workspace_premium,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
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
                  Icon(
                    benefit.$1,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
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
            const SizedBox(height: 8),
            Text(
              l10n.licenseTeamPlanSummary,
              key: const Key('license-team-plan-summary'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Divider(
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: 0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.licensePurchaseStepsTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _PurchaseStep(
              number: '1',
              title: l10n.licensePurchaseStepChoose,
              description: proEmailFallback && teamEmailFallback
                  ? l10n.licensePurchaseStepChooseEmail
                  : anyEmailFallback
                  ? l10n.licensePurchaseStepChooseMixed
                  : l10n.licensePurchaseStepChooseOnline,
            ),
            _PurchaseStep(
              number: '2',
              title: l10n.licensePurchaseStepReceive,
              description: l10n.licensePurchaseStepReceiveDescription,
            ),
            _PurchaseStep(
              number: '3',
              title: l10n.licensePurchaseStepActivate,
              description: l10n.licensePurchaseStepActivateDescription,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('license-buy-pro-button'),
                  onPressed: () => onPurchase(LicenseTier.pro),
                  icon: Icon(
                    proEmailFallback ? Icons.email_outlined : Icons.open_in_new,
                  ),
                  label: Text(
                    proEmailFallback
                        ? l10n.licenseEmailBuyPro
                        : l10n.licenseBuyPro,
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('license-buy-team-button'),
                  onPressed: () => onPurchase(LicenseTier.team),
                  icon: Icon(
                    teamEmailFallback
                        ? Icons.email_outlined
                        : Icons.open_in_new,
                  ),
                  label: Text(
                    teamEmailFallback
                        ? l10n.licenseEmailBuyTeam
                        : l10n.licenseBuyTeam,
                  ),
                ),
              ],
            ),
            if (anyEmailFallback) ...[
              const SizedBox(height: 8),
              SelectableText(
                LicensePurchaseLinkProvider.fallbackEmail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PurchaseStep extends StatelessWidget {
  const _PurchaseStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: color,
            foregroundColor: theme.colorScheme.primaryContainer,
            child: Text(number, style: theme.textTheme.labelSmall),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(color: color),
                children: [
                  TextSpan(
                    text: '$title：',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
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
    String fmt(DateTime? d) => d == null
        ? '—'
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // Remaining days until subscription expiry (Team is an annual subscription).
    final expiresAt = state.expiresAt;
    int? remainingDays;
    if (expiresAt != null) {
      final diff = expiresAt.difference(DateTime.now());
      remainingDays = diff.inSeconds <= 0 ? 0 : diff.inDays + 1;
    }
    final nearingExpiry = remainingDays != null && remainingDays <= 7;

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
            if (expiresAt != null) ...[
              Text('订阅到期：${fmt(expiresAt)}'),
              const SizedBox(height: 4),
              if (remainingDays == 0)
                Text(
                  '订阅已到期，已降级为免费版',
                  key: const Key('license-expired-notice'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                Text(
                  '剩余 $remainingDays 天',
                  key: const Key('license-remaining-days'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: nearingExpiry
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: nearingExpiry ? FontWeight.bold : null,
                  ),
                ),
            ],
            Text('离线宽限至：${fmt(state.graceUntil)}'),
            if (nearingExpiry && remainingDays != 0) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('license-renew-prompt'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '订阅即将到期，请及时续订以免功能降级为免费版。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 展示买家设备管理接口返回的全部已激活席位。
class _DeviceManager extends StatelessWidget {
  const _DeviceManager({
    required this.devices,
    required this.activeDevices,
    required this.maxDevices,
    required this.busy,
    required this.onRelease,
  });

  final List<LicenseDevice> devices;
  final int activeDevices;
  final int maxDevices;
  final bool busy;
  final ValueChanged<LicenseDevice> onRelease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    String format(DateTime? value) {
      if (value == null) return '—';
      final local = value.toLocal();
      return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')} '
          '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      key: const Key('license-seat-info'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.licenseDevicesTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(l10n.licenseDeviceUsage(activeDevices, maxDevices)),
              ],
            ),
            const SizedBox(height: 12),
            if (devices.isEmpty) ...[
              Text(l10n.licenseNoDevices),
              const SizedBox(height: 4),
              Text(
                l10n.licenseNoDevicesHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else
              for (final device in devices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    device.isCurrent
                        ? Icons.computer
                        : Icons.devices_other_outlined,
                  ),
                  title: Text(
                    device.deviceName?.trim().isNotEmpty == true
                        ? device.deviceName!.trim()
                        : device.platform ?? l10n.licenseUnknownDevice,
                  ),
                  subtitle: Text(
                    '${l10n.licensePlatform(device.platform ?? '—')} · '
                    '${l10n.licenseLastSeen(format(device.lastSeenAt))}',
                  ),
                  trailing: device.isCurrent
                      ? Chip(label: Text(l10n.licenseCurrentDevice))
                      : TextButton(
                          key: Key('license-release-${device.id}'),
                          onPressed: busy ? null : () => onRelease(device),
                          child: Text(l10n.licenseReleaseDeviceAction),
                        ),
                ),
          ],
        ),
      ),
    );
  }
}
