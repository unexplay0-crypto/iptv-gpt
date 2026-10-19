class EpgProgram {
  const EpgProgram({
    required this.title,
    required this.start,
    required this.end,
    this.description = '',
    this.channelId = '',
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final String description;
  final String channelId;

  bool get isOnNow {
    final now = DateTime.now();
    return !now.isBefore(start) && now.isBefore(end);
  }

  int get progressPercent {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    final elapsed = DateTime.now().difference(start).inSeconds;
    return (elapsed * 100 / total).clamp(0, 100).round();
  }
}
