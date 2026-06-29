import 'package:flutter/material.dart';

import '../../app/branding.dart';
import '../../design_system/design_system.dart';

/// Privacy and data-use explainer for the Intelligence / LLM settings.
class IntelligencePrivacyDialog {
  IntelligencePrivacyDialog._();

  static Future<void> show(BuildContext context) {
    final theme = Theme.of(context);

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, size: 22),
            SizedBox(width: AppSpacing.sm),
            Text('Privacy & data use'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppBranding.name} keeps indexing on your machine. '
                  'These are the points where your data may reach an external service:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _PrivacyPoint(
                  title: 'LLM chat requests',
                  body:
                      'When you ask a question, your question and the most relevant '
                      'text excerpts from your indexed documents are sent to the LLM '
                      'provider you selected (OpenAI, Anthropic, Google Gemini, or DeepSeek) '
                      'to generate an answer. Full PDFs are not uploaded—only the snippets '
                      'retrieved for that question.',
                ),
                _PrivacyPoint(
                  title: 'Provider privacy policies',
                  body:
                      'Each LLM provider processes requests under its own terms, '
                      'retention rules, and privacy policy. Review the policy for your '
                      'chosen provider before sending sensitive company data.',
                ),
                const _PrivacyPoint(
                  title: 'API keys',
                  body:
                      'You must supply your own API key for the provider you choose. '
                      'Keys are saved locally in the backend database on this computer '
                      'and are used only to call that provider. They are never sent to '
                      'third-party app servers—everything runs on your machine.',
                ),
                const _PrivacyPoint(
                  title: 'What stays local',
                  body:
                      'PDF indexing, embeddings, vector search (Qdrant), and document '
                      'storage run entirely on your computer. The Flutter app talks only '
                      'to your local backend—not directly to LLM providers.',
                ),
                const _PrivacyPoint(
                  title: 'Local model (this PC)',
                  body:
                      'If you use a local model, the app scans your hardware, recommends '
                      'a suitable on-device model, and manages download and setup for you. '
                      'Your questions and retrieved document excerpts are answered on this '
                      'computer without being sent to a cloud LLM.',
                ),
                const _PrivacyPoint(
                  title: 'Other sources (email)',
                  body:
                      'If you connect email in Sources, the backend contacts your mail '
                      'server over IMAP to sync messages. That is separate from Intelligence '
                      'settings but may index email content locally for search.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  final String title;
  final String body;

  const _PrivacyPoint({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: AppColors.textTertiary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer link that opens the privacy explainer dialog.
class IntelligencePrivacyFooter extends StatelessWidget {
  const IntelligencePrivacyFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: () => IntelligencePrivacyDialog.show(context),
          icon: Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          label: Text(
            'Privacy & data use',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
