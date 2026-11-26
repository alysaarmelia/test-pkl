import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Immutable representation of a single company profile entry that powers
/// the marketing site as well as the admin CMS tooling.
class CompanyProfileData {
  CompanyProfileData({
    required this.id,
    required this.displayName,
    required this.legalType,
    required this.tagline,
    required this.summary,
    required this.history,
    required List<String> coreValues,
    required List<String> focusAreas,
    this.brandColor,
    this.isPublished = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  })  : coreValues = List.unmodifiable(coreValues),
        focusAreas = List.unmodifiable(focusAreas);

  factory CompanyProfileData.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return CompanyProfileData(
      id: snapshot.id,
      displayName: _asString(data['displayName']) ?? '',
      legalType: _asString(data['legalType']) ?? '',
      tagline: _asString(data['tagline']) ?? '',
      summary: _asString(data['summary']) ?? '',
      history: _asString(data['history']) ?? '',
      coreValues: _stringList(data['coreValues']),
      focusAreas: _stringList(data['focusAreas']),
      brandColor: _parseColor(data['brandColor']),
      isPublished: data['isPublished'] != false,
      sortOrder: _asInt(data['sortOrder']) ?? 0,
      createdAt: _asDate(data['createdAt']),
      updatedAt: _asDate(data['updatedAt']),
    );
  }

  final String id;
  final String displayName;
  final String legalType;
  final String tagline;
  final String summary;
  final String history;
  final List<String> coreValues;
  final List<String> focusAreas;
  final Color? brandColor;
  final bool isPublished;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Convenience getter for binding the current brand color inside admin form.
  String? get brandColorHex => colorToHex(brandColor);

  Map<String, dynamic> toFirestorePayload() {
    return {
      'displayName': displayName,
      'legalType': legalType,
      'tagline': tagline,
      'summary': summary,
      'history': history,
      'coreValues': List<String>.from(coreValues),
      'focusAreas': List<String>.from(focusAreas),
      'brandColor': colorToHex(brandColor),
      'isPublished': isPublished,
      'sortOrder': sortOrder,
    };
  }

  CompanyProfileData copyWith({
    String? id,
    String? displayName,
    String? legalType,
    String? tagline,
    String? summary,
    String? history,
    List<String>? coreValues,
    List<String>? focusAreas,
    Color? brandColor,
    bool? isPublished,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearBrandColor = false,
  }) {
    return CompanyProfileData(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      legalType: legalType ?? this.legalType,
      tagline: tagline ?? this.tagline,
      summary: summary ?? this.summary,
      history: history ?? this.history,
      coreValues: coreValues ?? this.coreValues,
      focusAreas: focusAreas ?? this.focusAreas,
      brandColor: clearBrandColor ? null : (brandColor ?? this.brandColor),
      isPublished: isPublished ?? this.isPublished,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static Color? colorFromHex(String? hex) => _parseColor(hex);

  static String? colorToHex(Color? color) {
    if (color == null) return null;
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}

String? _asString(dynamic value) {
  if (value is String) return value;
  if (value == null) return null;
  return value.toString();
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _asDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

List<String> _stringList(dynamic value) {
  if (value is Iterable) {
    return value
        .map((element) => _asString(element)?.trim())
        .whereType<String>()
        .where((element) => element.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split('\n')
        .map((e) => e.trim())
        .where((element) => element.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

Color? _parseColor(dynamic value) {
  if (value is Color) return value;
  if (value is int) {
    return Color(value);
  }
  final hex = _asString(value);
  if (hex == null || hex.isEmpty) return null;
  var cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.length == 6) {
    cleaned = 'FF$cleaned';
  }
  if (cleaned.length == 8) {
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed != null) {
      return Color(parsed);
    }
  }
  return null;
}
