import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/section_card.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.help, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.threeSteps,
          subtitle: l10n.threeStepsDesc,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Step(number: '1', title: l10n.step1, description: l10n.step1Desc),
              _Step(number: '2', title: l10n.step2, description: l10n.step2Desc),
              _Step(number: '3', title: l10n.step3, description: l10n.step3Desc),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.modeHelp,
          subtitle: l10n.modeHelpDesc,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ModeHelp(
                title: '串行下载',
                description: '一次只下载一个任务，适合带宽有限的场景。',
              ),
              SizedBox(height: 12),
              _ModeHelp(
                title: '队列下载',
                description: '手动管理下载次序，完成后不会自动开始下一个。',
              ),
              SizedBox(height: 12),
              _ModeHelp(
                title: '并发下载',
                description: '同时下载多个任务（1-8），适合带宽充裕的场景。',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.toolConfig,
          subtitle: l10n.toolConfigDesc,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Faq(question: l10n.faqYtDlp, answer: l10n.faqYtDlpAnswer),
              const SizedBox(height: 12),
              _Faq(question: l10n.faqFfmpeg, answer: l10n.faqFfmpegAnswer),
              const SizedBox(height: 12),
              _Faq(question: l10n.faqSites, answer: l10n.faqSitesAnswer),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.resumeHelp,
          subtitle: l10n.resumeHelpDesc,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Faq(question: l10n.faqResumePause, answer: l10n.faqResumePauseAnswer),
              const SizedBox(height: 12),
              _Faq(question: l10n.faqResumeCrash, answer: l10n.faqResumeCrashAnswer),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.description});
  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            child: Text(number, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeHelp extends StatelessWidget {
  const _ModeHelp({required this.title, required this.description});
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.arrow_right, size: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
            ],
          ),
        ),
      ],
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(answer, style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        )),
      ],
    );
  }
}
