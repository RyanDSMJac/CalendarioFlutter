class EventItem {
  final String title;
  final String calendarName;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool allDay;
  final String location;
  final String description;

  EventItem({
    required this.title,
    required this.calendarName,
    required this.startDate,
    required this.endDate,
    required this.allDay,
    required this.location,
    required this.description,
  });
}