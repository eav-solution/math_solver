// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../config/app_config.dart';

/// =====================
///  Model
/// =====================

class HistoryItem {
  HistoryItem({
    required this.id,
    required this.imageUrl,
    required this.filename,
    required this.type,
    this.answer,
    this.explanation,
    this.reason,
    this.reasoning,
    this.steps,
    this.createdAtIso,
  });

  final String id;
  final String imageUrl;
  final String filename;
  final String type; // "enough_info" | "not_enough_info"
  final String? answer;
  final String? explanation;
  final String? reasoning;
  final String? steps;
  final String? reason; // for "not_enough_info"
  final String? createdAtIso;

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'] as String,
    imageUrl: json['image_url'] as String,
    filename: json['filename'] as String,
    type: json['type'] as String,
    answer: json['answer'] as String?,
    explanation: json['explanation'] as String?,
    reasoning: json['reasoning'] as String?,
    steps: json['steps'] as String?,
    reason: json['reason'] as String?,
    createdAtIso: json['created_at'] as String?,
  );
}

/// =====================
///  Controller
/// =====================

class HistoryController extends AutoDisposeAsyncNotifier<List<HistoryItem>> {
  static const _endpoint = '${AppConfig.baseUrl}/history';

  /// Called the first time the provider is read.
  @override
  Future<List<HistoryItem>> build() => _fetch();

  /// Force a refetch and show a spinner immediately.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<List<HistoryItem>> _fetch() async {
    final res = await http.get(Uri.parse(_endpoint));
    if (res.statusCode != 200) {
      throw Exception(
        'History fetch failed • status ${res.statusCode}: ${res.body}',
      );
    }
    final decoded = jsonDecode(res.body) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(HistoryItem.fromJson)
        .toList(growable: false);
  }
}

/// Auto-dispose so each visit to HistoryPage gets fresh data.
final historyControllerProvider =
    AsyncNotifierProvider.autoDispose<HistoryController, List<HistoryItem>>(
      HistoryController.new,
    );
