/// A recent economic development surfaced in the "What's changing?" feed.
///
/// [id] resolves to localized copy in the UI; [indicatorId] links the event
/// to the indicator it concerns so tapping it can open the detail screen.
class EconomicEvent {
  const EconomicEvent({
    required this.id,
    required this.indicatorId,
    required this.occurredAt,
  });

  /// 'inflationUp' | 'rupeeSlip' | 'rateCut' | 'remittancesUp'.
  final String id;

  /// The [EconomicIndicator.id] this event belongs to.
  final String indicatorId;

  /// When the event (nominally) happened; demo events are relative to now.
  final DateTime occurredAt;
}
