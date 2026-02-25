import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:pedometer/pedometer.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:http/http.dart' as http;
import '../models/day_context.dart';

class DeviceDataService {
  static const String _openWeatherKey = String.fromEnvironment('OPENWEATHER_API_KEY');

  Future<DayContext> collectDayContext() async {
    final results = await Future.wait([
      _getSteps(),
      _getLocationAndWeather(),
      _getCalendarEvents(),
    ]);

    final steps = results[0] as int?;
    final locationWeather = results[1] as Map<String, String?>?;
    final calendarEvents = results[2] as List<String>;

    return DayContext(
      steps: steps,
      location: locationWeather?['location'],
      weather: locationWeather?['weather'],
      calendarEvents: calendarEvents,
    );
  }

  Future<int?> _getSteps() async {
    // Schrittzähler nicht verfügbar im Web
    if (kIsWeb) return null;

    try {
      final stepStream = Pedometer.stepCountStream;
      final stepCount = await stepStream.first.timeout(
        const Duration(seconds: 3),
      );
      return stepCount.steps;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String?>?> _getLocationAndWeather() async {
    try {
      // Standort-Permission prüfen
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      String? locationName;
      // Reverse Geocoding nur auf nativen Plattformen
      if (!kIsWeb) {
        try {
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            locationName = [p.locality, p.country]
                .where((s) => s != null && s.isNotEmpty)
                .join(', ');
          }
        } catch (_) {}
      }

      // Wetter via OpenWeatherMap
      String? weatherDescription;
      if (_openWeatherKey.isNotEmpty) {
        try {
          final url = Uri.parse(
            'https://api.openweathermap.org/data/2.5/weather'
            '?lat=${position.latitude}&lon=${position.longitude}'
            '&appid=$_openWeatherKey&units=metric&lang=de',
          );
          final response = await http.get(url).timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            final temp = (json['main']['temp'] as num).round();
            final desc = json['weather'][0]['description'] as String;
            weatherDescription = '$desc, $temp°C';
          }
        } catch (_) {}
      }

      return {
        'location': locationName,
        'weather': weatherDescription,
      };
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> _getCalendarEvents() async {
    // Kalender nicht verfügbar im Web
    if (kIsWeb) return [];

    try {
      final plugin = DeviceCalendarPlugin();
      final permResult = await plugin.requestPermissions();
      if (permResult.data != true) return [];

      final calendarsResult = await plugin.retrieveCalendars();
      final calendars = calendarsResult.data;
      if (calendars == null || calendars.isEmpty) return [];

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final events = <String>[];
      for (final calendar in calendars) {
        final eventsResult = await plugin.retrieveEvents(
          calendar.id,
          RetrieveEventsParams(startDate: startOfDay, endDate: endOfDay),
        );
        final calEvents = eventsResult.data;
        if (calEvents != null) {
          for (final event in calEvents) {
            if (event.title != null && event.title!.isNotEmpty) {
              events.add(event.title!);
            }
          }
        }
      }
      return events;
    } catch (e) {
      return [];
    }
  }
}
