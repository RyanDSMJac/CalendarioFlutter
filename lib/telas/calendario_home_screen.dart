import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:intl/intl.dart';
import '../models/evento_item.dart';

class CalendarHomeScreen extends StatefulWidget {
  const CalendarHomeScreen({Key? key}) : super(key: key);

  @override
  State<CalendarHomeScreen> createState() => _CalendarHomeScreenState();
}

class _CalendarHomeScreenState extends State<CalendarHomeScreen> {
  late final DeviceCalendarPlugin _deviceCalendarPlugin;

  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  List<EventItem> _events = [];

  @override
  void initState() {
    super.initState();
    _deviceCalendarPlugin = DeviceCalendarPlugin();
  }

  Future<void> _fetchAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
      _events = [];
    });

    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && !(permissionsGranted.data ?? false)) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (permissionsGranted.isSuccess && !(permissionsGranted.data ?? false)) {
          setState(() {
            _errorMessage = 'Permissão de acesso ao calendário negada pelo usuário.';
            _isLoading = false;
          });
          return;
        }
      }

      if (!permissionsGranted.isSuccess) {
        setState(() {
          _errorMessage =
              'Falha ao verificar permissões: ${permissionsGranted.errors.map((e) => e.errorMessage).join(', ')}';
          _isLoading = false;
        });
        return;
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null) {
        setState(() {
          _errorMessage = 'Não foi possível recuperar os calendários do dispositivo.';
          _isLoading = false;
        });
        return;
      }

      final calendars = calendarsResult.data!;
      List<EventItem> collectedEvents = [];

      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final endDate = startDate.add(const Duration(days: 7));

      for (var calendar in calendars) {
        if (calendar.id == null) continue;

        final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
          calendar.id,
          RetrieveEventsParams(startDate: startDate, endDate: endDate),
        );

        if (eventsResult.isSuccess && eventsResult.data != null) {
          for (var event in eventsResult.data!) {
            collectedEvents.add(
              EventItem(
                title: event.title ?? 'Sem Título',
                calendarName: calendar.name ?? 'Calendário Padrão',
                startDate: event.start,
                endDate: event.end,
                allDay: event.allDay ?? false,
                location: event.location ?? '',
                description: event.description ?? '',
              ),
            );
          }
        }
      }

      collectedEvents.sort((a, b) {
        if (a.startDate == null && b.startDate == null) return 0;
        if (a.startDate == null) return 1;
        if (b.startDate == null) return -1;
        return a.startDate!.compareTo(b.startDate!);
      });

      setState(() {
        _events = collectedEvents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocorreu um erro inesperado: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compromissos (7 Dias)'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchAppointments,
              icon: const Icon(Icons.refresh),
              label: const Text('Consultar compromissos'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Consultando calendários...'),
                        ],
                      ),
                    )
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Toque em "Consultar compromissos" para carregar a agenda dos próximos 7 dias.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    if (_events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, color: Colors.grey, size: 48),
            SizedBox(height: 12),
            Text(
              'Nenhum compromisso encontrado para hoje e os próximos 6 dias.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        final dateFormat = DateFormat('dd/MM/yyyy');
        final timeFormat = DateFormat('HH:mm');

        String dateStr = event.startDate != null
            ? dateFormat.format(event.startDate!)
            : 'Data inválida';
        String timeStr = '';

        if (event.allDay) {
          timeStr = 'Dia inteiro';
        } else {
          String startStr = event.startDate != null
              ? timeFormat.format(event.startDate!)
              : '--:--';
          String endStr = event.endDate != null
              ? timeFormat.format(event.endDate!)
              : '--:--';
          timeStr = '$startStr às $endStr';
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (event.allDay)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Dia Inteiro',
                          style: TextStyle(
                            color: Colors.indigo,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      event.calendarName,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$dateStr, $timeStr',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (event.location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.location,
                          style: TextStyle(color: Colors.grey.shade800),
                        ),
                      ),
                    ],
                  ),
                ],
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.description,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}