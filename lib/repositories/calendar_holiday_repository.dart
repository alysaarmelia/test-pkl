import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

abstract class HolidayRepository {
  Future<Map<DateTime, List<String>>> fetchHolidaysByYear(int year);
}

class ApiHolidayRepository implements HolidayRepository {
  List<dynamic>? _allHolidayPayloadCache;

  @override
  Future<Map<DateTime, List<String>>> fetchHolidaysByYear(int year) async {
    final holidays = <DateTime, List<String>>{};

    final primaryPayload = await _fetchPrimaryPayload(year);
    if (primaryPayload != null && primaryPayload.isNotEmpty) {
      _appendHolidayItems(
        holidays: holidays,
        payload: primaryPayload,
        year: year,
      );
    }

    if (holidays.isEmpty) {
      final fallbackPayload = await _fetchNagerPayload(year);
      if (fallbackPayload != null && fallbackPayload.isNotEmpty) {
        _appendHolidayItems(
          holidays: holidays,
          payload: fallbackPayload,
          year: year,
        );
      }
    }

    if (holidays.isEmpty) {
      _appendStaticFallbackHolidays(holidays: holidays, year: year);
    }

    _dedupeHolidayMap(holidays);
    return holidays;
  }

  Future<List<dynamic>?> _fetchPrimaryPayload(int year) async {
    final yearEndpoints = <Uri>[
      Uri.parse('https://api-harilibur.vercel.app/api?year=$year'),
      Uri.parse('https://api-harilibur.vercel.app/api?tahun=$year'),
      Uri.parse('https://api-harilibur.vercel.app/api/$year'),
    ];

    for (final endpoint in yearEndpoints) {
      try {
        final response = await http
            .get(endpoint)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) continue;
        final decoded = json.decode(response.body);
        if (decoded is List<dynamic> && decoded.isNotEmpty) {
          return decoded;
        }
      } on TimeoutException catch (_) {
        continue;
      } catch (_) {
        continue;
      }
    }

    if (_allHolidayPayloadCache != null) return _allHolidayPayloadCache;

    try {
      final response = await http
          .get(Uri.parse('https://api-harilibur.vercel.app/api'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final decoded = json.decode(response.body);
      if (decoded is List<dynamic>) {
        _allHolidayPayloadCache = decoded;
        return decoded;
      }
    } on TimeoutException catch (_) {
      return null;
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<List<dynamic>?> _fetchNagerPayload(int year) async {
    try {
      final response = await http
          .get(
            Uri.parse('https://date.nager.at/api/v3/PublicHolidays/$year/ID'),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final decoded = json.decode(response.body);
      if (decoded is List<dynamic> && decoded.isNotEmpty) {
        return decoded;
      }
    } on TimeoutException catch (_) {
      return null;
    } catch (_) {
      return null;
    }

    return null;
  }

  void _appendHolidayItems({
    required Map<DateTime, List<String>> holidays,
    required List<dynamic> payload,
    required int year,
  }) {
    for (final item in payload) {
      if (item is! Map) continue;
      final date = _parseHolidayDate(
        item['holiday_date'] ?? item['date'] ?? item['tanggal'],
      );
      if (date == null || date.year != year) continue;
      final name = _parseHolidayName(item);
      if (name == null || name.isEmpty) continue;
      holidays.putIfAbsent(date, () => <String>[]).add(name);
    }
  }

  DateTime? _parseHolidayDate(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;

    final direct = DateTime.tryParse(value);
    if (direct != null) return _normalizeDate(direct);

    final parts = value.split(RegExp(r'[-/]'));
    if (parts.length != 3) return null;

    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    final third = int.tryParse(parts[2]);
    if (first == null || second == null || third == null) return null;

    if (parts[0].length == 4) {
      return _normalizeDate(DateTime(first, second, third));
    }
    if (parts[2].length == 4) {
      return _normalizeDate(DateTime(third, second, first));
    }

    return null;
  }

  String? _parseHolidayName(Map item) {
    final value =
        item['holiday_name'] ??
        item['localName'] ??
        item['name'] ??
        item['keterangan'] ??
        item['description'];
    if (value is! String) return null;
    return value.trim();
  }

  void _appendStaticFallbackHolidays({
    required Map<DateTime, List<String>> holidays,
    required int year,
  }) {
    final staticHolidays = <DateTime, String>{
      _normalizeDate(DateTime(year, 1, 1)): 'Tahun Baru Masehi',
      _normalizeDate(DateTime(year, 8, 17)): 'Hari Kemerdekaan RI',
      _normalizeDate(DateTime(year, 12, 25)): 'Hari Raya Natal',
    };

    for (final entry in staticHolidays.entries) {
      holidays.putIfAbsent(entry.key, () => <String>[]).add(entry.value);
    }
  }

  void _dedupeHolidayMap(Map<DateTime, List<String>> holidays) {
    for (final entry in holidays.entries) {
      final deduped = entry.value.toSet().toList()..sort();
      entry.value
        ..clear()
        ..addAll(deduped);
    }
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
