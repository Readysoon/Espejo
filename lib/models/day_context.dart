class DayContext {
  final int? steps;
  final String? location;
  final String? weather;
  final List<String> calendarEvents;

  DayContext({
    this.steps,
    this.location,
    this.weather,
    this.calendarEvents = const [],
  });

  /// Erstellt einen lesbaren Text-Block für den Mistral System-Prompt
  String toPromptString() {
    final buffer = StringBuffer();
    buffer.writeln('Heutige Tagesdaten:');

    if (steps != null) {
      buffer.writeln('- Schritte: $steps');
    }
    if (location != null) {
      buffer.writeln('- Aktueller Standort: $location');
    }
    if (weather != null) {
      buffer.writeln('- Wetter: $weather');
    }
    if (calendarEvents.isNotEmpty) {
      buffer.writeln('- Kalendereinträge heute:');
      for (final event in calendarEvents) {
        buffer.writeln('  • $event');
      }
    }

    return buffer.toString();
  }

  bool get isEmpty =>
      steps == null &&
      location == null &&
      weather == null &&
      calendarEvents.isEmpty;
}
