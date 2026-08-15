/// Durée d'un prêt exprimée en clair, p. ex. « 3 j 4 h » ou « 45 min ».
///
/// Utilisée tant que la demande n'a pas été acceptée : l'échéance n'est
/// connue qu'à ce moment-là.
String formatLoanDurationLabel(int minutes) {
  final days = minutes ~/ 1440;
  final hours = (minutes % 1440) ~/ 60;
  final mins = minutes % 60;

  final parts = <String>[
    if (days > 0) '$days j',
    if (hours > 0) '$hours h',
    // Les minutes ne sont détaillées que sur les durées courtes.
    if (mins > 0 && days == 0) '$mins min',
  ];
  return parts.isEmpty ? '$minutes min' : parts.join(' ');
}

String formatLoanDueDateLabel(DateTime dt) {
  final d = dt.toLocal();
  final date =
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  final time =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}
