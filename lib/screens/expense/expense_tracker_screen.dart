import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../models/trip.dart';
import '../../services/expense_service.dart';
import '../../services/trip_service.dart';

class ExpenseTrackerScreen
    extends StatefulWidget {
  final String tripId;

  const ExpenseTrackerScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<ExpenseTrackerScreen>
  createState() =>
      _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState
    extends State<ExpenseTrackerScreen> {
  final ExpenseService
  _expenseService =
  ExpenseService();

  final TripService _tripService =
  TripService();

  Trip? _trip;

  bool _loadingTrip = true;

  final List<String> _categories = [
    'Food',
    'Transport',
    'Hotel',
    'Activities',
    'Shopping',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final trip =
      await _tripService.getTrip(
        widget.tripId,
      );

      if (!mounted) return;

      setState(() {
        _trip = trip;
        _loadingTrip = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingTrip = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not load trip: $e',
          ),
        ),
      );
    }
  }

  Future<void> _showAddExpenseDialog()
  async {
    final titleController =
    TextEditingController();

    final amountController =
    TextEditingController();

    final noteController =
    TextEditingController();

    String selectedCategory =
        _categories.first;

    DateTime selectedDate =
    DateTime.now();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            return AlertDialog(
              title: const Text(
                'Add Expense',
              ),
              content:
              SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                      titleController,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Expense title',
                        hintText:
                        'Example: Lunch',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                      amountController,
                      keyboardType:
                      const TextInputType
                          .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Amount',
                        prefixText:
                        '₹ ',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    DropdownButtonFormField<
                        String>(
                      initialValue:
                      selectedCategory,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Category',
                        border:
                        OutlineInputBorder(),
                      ),
                      items:
                      _categories.map(
                            (category) {
                          return DropdownMenuItem(
                            value:
                            category,
                            child:
                            Text(
                              category,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged:
                          (value) {
                        if (value !=
                            null) {
                          setDialogState(
                                () {
                              selectedCategory =
                                  value;
                            },
                          );
                        }
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                      noteController,
                      maxLines: 2,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Note (optional)',
                        hintText:
                        'Example: Dinner with friends',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    ListTile(
                      contentPadding:
                      EdgeInsets.zero,
                      leading:
                      const Icon(
                        Icons
                            .calendar_today,
                      ),
                      title:
                      const Text(
                        'Date',
                      ),
                      subtitle:
                      Text(
                        _formatDate(
                          selectedDate,
                        ),
                      ),
                      onTap:
                          () async {
                        final pickedDate =
                        await showDatePicker(
                          context:
                          context,
                          initialDate:
                          selectedDate,
                          firstDate:
                          DateTime(
                            2020,
                          ),
                          lastDate:
                          DateTime(
                            2100,
                          ),
                        );

                        if (pickedDate !=
                            null) {
                          setDialogState(
                                () {
                              selectedDate =
                                  pickedDate;
                            },
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                  const Text(
                    'Cancel',
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      () async {
                    final title =
                    titleController
                        .text
                        .trim();

                    final amount =
                    double.tryParse(
                      amountController
                          .text
                          .trim(),
                    );

                    if (title.isEmpty ||
                        amount == null ||
                        amount <= 0) {
                      ScaffoldMessenger
                          .of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter a valid title and amount.',
                          ),
                        ),
                      );

                      return;
                    }

                    try {
                      await _expenseService
                          .addExpense(
                        tripId:
                        widget.tripId,
                        title:
                        title,
                        amount:
                        amount,
                        category:
                        selectedCategory,
                        note:
                        noteController
                            .text
                            .trim(),
                        date:
                        selectedDate,
                      );

                      if (dialogContext
                          .mounted) {
                        Navigator.pop(
                          dialogContext,
                        );
                      }

                      if (mounted) {
                        ScaffoldMessenger
                            .of(context)
                            .showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Expense added successfully.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger
                            .of(context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to add expense: $e',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child:
                  const Text(
                    'Add',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    amountController.dispose();
    noteController.dispose();
  }

  Future<void> _deleteExpense(
      Expense expense,
      ) async {
    final shouldDelete =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Expense',
          ),
          content: Text(
            'Do you want to delete "${expense.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
              const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
              const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _expenseService
          .deleteExpense(
        expense.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
            Text('Expense deleted.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete expense: $e',
            ),
          ),
        );
      }
    }
  }

  double _calculateTotal(
      List<Expense> expenses,
      ) {
    double total = 0;

    for (final expense in expenses) {
      total += expense.amount;
    }

    return total;
  }

  Map<String, double>
  _calculateCategoryTotals(
      List<Expense> expenses,
      ) {
    final Map<String, double>
    totals = {};

    for (final category in _categories) {
      totals[category] = 0;
    }

    for (final expense in expenses) {
      totals[expense.category] =
          (totals[expense.category] ??
              0) +
              expense.amount;
    }

    return totals;
  }

  String _formatDate(
      DateTime date,
      ) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Color _categoryColor(
      String category,
      ) {
    switch (category) {
      case 'Food':
        return Colors.orange;

      case 'Transport':
        return Colors.blue;

      case 'Hotel':
        return Colors.purple;

      case 'Activities':
        return Colors.green;

      case 'Shopping':
        return Colors.pink;

      default:
        return Colors.grey;
    }
  }

  IconData _categoryIcon(
      String category,
      ) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;

      case 'Transport':
        return Icons.directions_car;

      case 'Hotel':
        return Icons.hotel;

      case 'Activities':
        return Icons.local_activity;

      case 'Shopping':
        return Icons.shopping_bag;

      default:
        return Icons.more_horiz;
    }
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding:
          const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 28,
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                title,
                style:
                const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                value,
                style:
                const TextStyle(
                  fontSize: 17,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySummary(
      Map<String, double>
      categoryTotals,
      ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding:
        const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              'Category-wise Spending',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            ..._categories.map(
                  (category) {
                final amount =
                    categoryTotals[
                    category] ??
                        0;

                return Padding(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                        _categoryColor(
                          category,
                        ).withValues(
                          alpha: 0.15,
                        ),
                        child: Icon(
                          _categoryIcon(
                            category,
                          ),
                          size: 19,
                          color:
                          _categoryColor(
                            category,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Text(
                          category,
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight
                                .w500,
                          ),
                        ),
                      ),
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseItem(
      Expense expense,
      ) {
    return Card(
      elevation: 1,
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
          _categoryColor(
            expense.category,
          ).withValues(
            alpha: 0.15,
          ),
          child: Icon(
            _categoryIcon(
              expense.category,
            ),
            color:
            _categoryColor(
              expense.category,
            ),
          ),
        ),
        title: Text(
          expense.title,
          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment:
          CrossAxisAlignment
              .start,
          children: [
            const SizedBox(
              height: 3,
            ),
            Text(
              '${expense.category} • ${_formatDate(expense.date)}',
            ),
            if (expense.note
                .isNotEmpty)
              Text(
                expense.note,
                maxLines: 1,
                overflow:
                TextOverflow
                    .ellipsis,
              ),
          ],
        ),
        isThreeLine:
        expense.note.isNotEmpty,
        trailing: Row(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Text(
              '₹${expense.amount.toStringAsFixed(2)}',
              style:
              const TextStyle(
                fontWeight:
                FontWeight.bold,
                fontSize: 15,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
              ),
              onPressed: () =>
                  _deleteExpense(
                    expense,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    if (_loadingTrip) {
      return const Scaffold(
        body: Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    if (_trip == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Trip could not be found.',
          ),
        ),
      );
    }

    final budget =
        _trip!.budget;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Trip Expenses',
        ),
      ),
      body:
      StreamBuilder<List<Expense>>(
        stream:
        _expenseService
            .getExpenses(
          widget.tripId,
        ),
        builder:
            (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                const EdgeInsets.all(
                  20,
                ),
                child: Text(
                  'Unable to load expenses.\n\n${snapshot.error}',
                  textAlign:
                  TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot
              .connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
              CircularProgressIndicator(),
            );
          }

          final expenses =
              snapshot.data ?? [];

          final totalSpent =
          _calculateTotal(
            expenses,
          );

          final remaining =
              budget - totalSpent;

          final categoryTotals =
          _calculateCategoryTotals(
            expenses,
          );

          return SingleChildScrollView(
            padding:
            const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 3,
                  child: Padding(
                    padding:
                    const EdgeInsets.all(
                      18,
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          child: Icon(
                            Icons
                                .account_balance_wallet,
                            size: 30,
                          ),
                        ),
                        const SizedBox(
                          width: 14,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              const Text(
                                'Trip Budget',
                                style:
                                TextStyle(
                                  color:
                                  Colors
                                      .grey,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                '₹${budget.toStringAsFixed(2)}',
                                style:
                                const TextStyle(
                                  fontSize:
                                  24,
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                '${_trip!.startLocation} → ${_trip!.destination}',
                                maxLines: 1,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Row(
                  children: [
                    _buildSummaryCard(
                      title: 'Spent',
                      value:
                      '₹${totalSpent.toStringAsFixed(2)}',
                      icon:
                      Icons.money_off,
                      color:
                      Colors.red,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    _buildSummaryCard(
                      title: remaining <
                          0
                          ? 'Over Budget'
                          : 'Remaining',
                      value:
                      '₹${remaining.abs().toStringAsFixed(2)}',
                      icon:
                      remaining < 0
                          ? Icons.warning
                          : Icons.savings,
                      color:
                      remaining < 0
                          ? Colors.red
                          : Colors.green,
                    ),
                  ],
                ),

                const SizedBox(
                  height: 12,
                ),

                if (remaining < 0)
                  Card(
                    color:
                    Colors.red.shade50,
                    child:
                    const Padding(
                      padding:
                      EdgeInsets.all(
                        14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .warning_amber_rounded,
                            color:
                            Colors.red,
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Text(
                              'You have exceeded your trip budget.',
                              style:
                              TextStyle(
                                color:
                                Colors.red,
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(
                  height: 16,
                ),

                _buildCategorySummary(
                  categoryTotals,
                ),

                const SizedBox(
                  height: 24,
                ),

                const Text(
                  'Recent Expenses',
                  style:
                  TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                if (expenses.isEmpty)
                  Card(
                    child: Padding(
                      padding:
                      const EdgeInsets.all(
                        30,
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons
                                  .receipt_long,
                              size: 50,
                              color: Colors
                                  .grey
                                  .shade400,
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            const Text(
                              'No expenses added yet.',
                              style:
                              TextStyle(
                                fontSize:
                                16,
                                color:
                                Colors
                                    .grey,
                              ),
                            ),
                            const SizedBox(
                              height: 6,
                            ),
                            const Text(
                              'Tap + to add your first expense.',
                              style:
                              TextStyle(
                                color:
                                Colors
                                    .grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...expenses.map(
                    _buildExpenseItem,
                  ),

                const SizedBox(
                  height: 80,
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton:
      FloatingActionButton.extended(
        onPressed:
        _showAddExpenseDialog,
        icon:
        const Icon(Icons.add),
        label:
        const Text('Add Expense'),
      ),
    );
  }
}