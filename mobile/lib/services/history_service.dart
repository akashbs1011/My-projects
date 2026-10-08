import '../models/history_entry.dart';
import 'api_client.dart';

class HistoryPage {
  const HistoryPage({required this.items, required this.total});

  final List<HistoryEntry> items;
  final int total;
}

class HistoryService {
  const HistoryService(this._api);

  final ApiClient _api;

  Future<HistoryPage> list({int limit = 50, int skip = 0}) async {
    final data = await _api.get('/predictions/history', query: {
      'limit': limit,
      'skip': skip,
    });
    return HistoryPage(
      items: (data['items'] as List)
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<HistoryEntry> get(String id) async => HistoryEntry.fromJson(
      await _api.get('/predictions/history/$id') as Map<String, dynamic>);

  Future<void> remove(String id) => _api.delete('/predictions/history/$id');

  Future<void> clear() => _api.delete('/predictions/history');
}
