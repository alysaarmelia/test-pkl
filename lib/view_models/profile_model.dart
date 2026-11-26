class ProfileData {
  const ProfileData({
    required this.displayName,
    required this.displayRole,
    required this.displayPin,
    required this.photoUrl,
  });

  final String displayName;
  final String displayRole;
  final String displayPin;
  final String photoUrl;

  bool get hasPhoto => photoUrl.isNotEmpty;

  factory ProfileData.fromMap(Map<String, dynamic> data) {
    final displayName = _firstNonEmpty([
      data['name'],
      data['displayName'],
      data['fullName'],
      data['username'],
    ], 'Nama Tidak Ditemukan');

    final displayRole = _firstNonEmpty([
      data['role'],
      data['team'],
      data['department'],
    ], '- Belum ada role -');

    final displayPin = _firstNonEmpty([
      data['pin'],
      data['chatPin'],
    ], '- Belum ada PIN -').toUpperCase();

    final photoUrl = _valueToString(data['photoUrl']);

    return ProfileData(
      displayName: displayName,
      displayRole: displayRole,
      displayPin: displayPin,
      photoUrl: photoUrl,
    );
  }

  static String _valueToString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  static String _firstNonEmpty(Iterable<dynamic> values, String fallback) {
    for (final value in values) {
      final str = _valueToString(value);
      if (str.isNotEmpty) return str;
    }
    return fallback;
  }
}
