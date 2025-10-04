class Expense {
  final String id;
  final String title;
  final double amount;
  final String date;
  final String category;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'], 
      title: json['title'] ?? '',
      amount: (json['amount'] as num).toDouble(),
      date: json['date'],
      category: json['category'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'amount': amount,
      'date': date,
      'category': category,
    };
  }
}
