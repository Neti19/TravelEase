class Expense {
  final String id;
  final String tripId;
  final String title;
  final double amount;
  final String category;
  final String note;
  final DateTime date;

  // Person who actually paid the full expense.
  final String paidBy;
  final String paidByName;

  // Each selected traveler's share.
  // Example:
  // {
  //   "userA": 500.0,
  //   "userB": 500.0,
  //   "userC": 500.0
  // }
  final Map<String, double> splitBetween;

  // Names are stored alongside IDs so the expense/balance
  // screens can display names without repeatedly looking them up.
  final Map<String, String> splitBetweenNames;

  Expense({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    required this.paidBy,
    required this.paidByName,
    required this.splitBetween,
    required this.splitBetweenNames,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'title': title,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'paidBy': paidBy,
      'paidByName': paidByName,
      'splitBetween': splitBetween,
      'splitBetweenNames': splitBetweenNames,
    };
  }

  factory Expense.fromMap(
      Map<String, dynamic> map,
      ) {
    final rawSplitBetween = map['splitBetween'];

    final Map<String, double> splitBetween = {};

    if (rawSplitBetween is Map) {
      rawSplitBetween.forEach((key, value) {
        splitBetween[key.toString()] =
            (value as num?)?.toDouble() ?? 0.0;
      });
    }

    final rawSplitBetweenNames =
    map['splitBetweenNames'];

    final Map<String, String> splitBetweenNames = {};

    if (rawSplitBetweenNames is Map) {
      rawSplitBetweenNames.forEach((key, value) {
        splitBetweenNames[key.toString()] =
            value?.toString() ?? 'Traveler';
      });
    }

    return Expense(
      id: map['id']?.toString() ?? '',
      tripId: map['tripId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      amount:
      (map['amount'] as num?)?.toDouble() ?? 0.0,
      category:
      map['category']?.toString() ?? 'Other',
      note: map['note']?.toString() ?? '',
      date: DateTime.parse(
        map['date']?.toString() ??
            DateTime.now().toIso8601String(),
      ),
      paidBy:
      map['paidBy']?.toString() ?? '',
      paidByName:
      map['paidByName']?.toString() ??
          'Traveler',
      splitBetween: splitBetween,
      splitBetweenNames: splitBetweenNames,
    );
  }
}