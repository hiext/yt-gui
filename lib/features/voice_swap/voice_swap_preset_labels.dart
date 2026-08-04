import '../../core/services/voice_swap/voice_swap_model_catalog.dart';
import '../../l10n/app_localizations.dart';

/// 预设备色显示名。
String voiceSwapPresetLabel(
  AppLocalizations l10n,
  VoiceSwapPresetVoice voice,
) {
  return switch (voice.nameKey) {
    'voiceSwapPresetZfXiaobei' => l10n.voiceSwapPresetZfXiaobei,
    'voiceSwapPresetZfXiaoni' => l10n.voiceSwapPresetZfXiaoni,
    'voiceSwapPresetZfXiaoxiao' => l10n.voiceSwapPresetZfXiaoxiao,
    'voiceSwapPresetZfXiaoyi' => l10n.voiceSwapPresetZfXiaoyi,
    'voiceSwapPresetZmYunjian' => l10n.voiceSwapPresetZmYunjian,
    'voiceSwapPresetZmYunxi' => l10n.voiceSwapPresetZmYunxi,
    'voiceSwapPresetZmYunxia' => l10n.voiceSwapPresetZmYunxia,
    'voiceSwapPresetZmYunyang' => l10n.voiceSwapPresetZmYunyang,
    _ => voice.nameKey,
  };
}

/// 预设备色性别显示名。
String voiceSwapPresetGender(
  AppLocalizations l10n,
  VoiceSwapPresetVoice voice,
) {
  return voice.genderKey == 'voiceSwapPresetFemale'
      ? l10n.voiceSwapPresetFemale
      : l10n.voiceSwapPresetMale;
}
