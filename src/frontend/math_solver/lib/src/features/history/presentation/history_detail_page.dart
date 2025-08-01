import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:math_solver/src/widgets/markdown_with_math.dart'; // ← NEW

import '../controller/history_controller.dart';

/// Shows either the full solution or the failure-reason.
class HistoryDetailPage extends StatelessWidget {
  const HistoryDetailPage({super.key, required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: item.id,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(imageUrl: item.imageUrl),
                ),
              ),
              const Divider(height: 32),
              if (item.type == 'enough_info') ...[
                _kv(theme, 'Answer', item.answer),
                _kv(theme, 'Explanation', item.explanation),
                _kv(theme, 'Reasoning', item.reasoning),
                _kv(theme, 'Steps', item.steps),
              ] else
                _kv(theme, 'Reason', item.reason),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders a label–value pair; value supports Markdown + LaTeX.
  Widget _kv(ThemeData theme, String k, String? v) =>
      v == null
          ? const SizedBox.shrink()
          : Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k, style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                MarkdownWithMath(data: v), // ← UPDATED
              ],
            ),
          );
}
