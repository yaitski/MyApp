class User {
  final String login;
  final String name;
  final String qrData;
  final DateTime validUntil;

  User({
    required this.login,
    required this.name,
    required this.qrData,
    required this.validUntil,
  });

  String get formattedDate {
    final day = validUntil.day.toString().padLeft(2, '0');
    final month = validUntil.month.toString().padLeft(2, '0');
    return "$day.$month.${validUntil.year}";
  }

  String get formattedValidUntil {
    final months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];

    return "${validUntil.day} ${months[validUntil.month - 1]} ${validUntil.year}";
  }
}
