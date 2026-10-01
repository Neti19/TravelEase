import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../models/trip.dart';
import '../../services/expense_service.dart';
import '../../services/trip_member_service.dart';
import '../../services/trip_service.dart';

class ExpenseTrackerScreen extends StatefulWidget {
  final String tripId;

  const ExpenseTrackerScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<ExpenseTrackerScreen> createState() =>
      _ExpenseTrackerScreenState();
}

class _Settlement {
  final String fromUserId;
  final String fromName;
  final String toUserId;
  final String toName;
  final double amount;

  const _Settlement({
    required this.fromUserId,
    required this.fromName,
    required this.toUserId,
    required this.toName,
    required this.amount,
  });
}

class _ExpenseTrackerScreenState
    extends State<ExpenseTrackerScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final TripService _tripService = TripService();
  final TripMemberService _memberService =
  TripMemberService();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Trip? _trip;
  List<Map<String, dynamic>> _members = [];

  bool _loading = true;
  String? _error;

  User? get _currentUser => _auth.currentUser;

  String get _currentUserId =>
      _currentUser?.uid ?? '';

  String get _currentUserName {
    final user = _currentUser;

    if (user == null) {
      return 'You';
    }

    if (user.displayName?.trim().isNotEmpty == true) {
      return user.displayName!.trim();
    }

    if (user.email?.trim().isNotEmpty == true) {
      return user.email!.trim();
    }

    return 'You';
  }

  @override
  void initState() {
    super.initState();
    _loadTripData();
  }

  Future<void> _loadTripData() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final trip = await _tripService.getTrip(
        widget.tripId,
      );

      if (trip == null) {
        throw Exception('Trip not found.');
      }

      final members =
      await _memberService.getTripMembers(
        widget.tripId,
      );

      if (!mounted) return;

      setState(() {
        _trip = trip;
        _members = members;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _memberName(
      Map<String, dynamic> member,
      ) {
    final name = member['name']?.toString().trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final email = member['email']?.toString().trim();

    if (email != null && email.isNotEmpty) {
      return email;
    }

    return 'Traveler';
  }

  Map<String, String> _memberNameMap() {
    final result = <String, String>{};

    for (final member in _members) {
      final userId =
          member['userId']?.toString() ?? '';

      if (userId.isNotEmpty) {
        result[userId] = _memberName(member);
      }
    }

    return result;
  }

  List<_Settlement> _calculateSettlements(
      List<Expense> expenses,
      ) {
    final netBalances = <String, double>{};
    final names = <String, String>{
      ..._memberNameMap(),
    };

    for (final expense in expenses) {
      names[expense.paidBy] =
          expense.paidByName;

      netBalances[expense.paidBy] =
          (netBalances[expense.paidBy] ?? 0) +
              expense.amount;

      for (final entry
      in expense.splitBetween.entries) {
        final userId = entry.key;
        final share = entry.value;

        names[userId] ??=
            expense.splitBetweenNames[userId] ??
                'Traveler';

        netBalances[userId] =
            (netBalances[userId] ?? 0) - share;
      }
    }

    final debtors = <Map<String, dynamic>>[];
    final creditors = <Map<String, dynamic>>[];

    for (final entry in netBalances.entries) {
      final amount =
      double.parse(entry.value.toStringAsFixed(2));

      if (amount < -0.01) {
        debtors.add({
          'userId': entry.key,
          'name': names[entry.key] ?? 'Traveler',
          'amount': -amount,
        });
      } else if (amount > 0.01) {
        creditors.add({
          'userId': entry.key,
          'name': names[entry.key] ?? 'Traveler',
          'amount': amount,
        });
      }
    }

    final settlements = <_Settlement>[];

    int debtorIndex = 0;
    int creditorIndex = 0;

    while (
    debtorIndex < debtors.length &&
        creditorIndex < creditors.length) {
      final debtor = debtors[debtorIndex];
      final creditor = creditors[creditorIndex];

      final debt =
      debtor['amount'] as double;
      final credit =
      creditor['amount'] as double;

      final payment =
      debt < credit ? debt : credit;

      if (payment > 0.01) {
        settlements.add(
          _Settlement(
            fromUserId:
            debtor['userId'].toString(),
            fromName:
            debtor['name'].toString(),
            toUserId:
            creditor['userId'].toString(),
            toName:
            creditor['name'].toString(),
            amount: double.parse(
              payment.toStringAsFixed(2),
            ),
          ),
        );
      }

      debtor['amount'] = debt - payment;
      creditor['amount'] = credit - payment;

      if ((debtor['amount'] as double) <=
          0.01) {
        debtorIndex++;
      }

      if ((creditor['amount'] as double) <=
          0.01) {
        creditorIndex++;
      }
    }

    return settlements;
  }

  double _amountYouOwe(
      List<_Settlement> settlements,
      ) {
    return settlements
        .where(
          (item) =>
      item.fromUserId == _currentUserId,
    )
        .fold(
      0.0,
          (sum, item) => sum + item.amount,
    );
  }

  double _amountYouAreOwed(
      List<_Settlement> settlements,
      ) {
    return settlements
        .where(
          (item) =>
      item.toUserId == _currentUserId,
    )
        .fold(
      0.0,
          (sum, item) => sum + item.amount,
    );
  }

  Future<void> _showAddExpenseDialog() async {
    final titleController =
    TextEditingController();

    final amountController =
    TextEditingController();

    final noteController =
    TextEditingController();

    String category = 'Food';

    DateTime selectedDate = DateTime.now();

    bool splitWithEveryone = true;

    final selectedMemberIds = <String>{
      ..._members
          .map(
            (member) =>
        member['userId']?.toString() ?? '',
      )
          .where(
            (id) => id.isNotEmpty,
      ),
    };

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            final parsedAmount =
                double.tryParse(
                  amountController.text
                      .trim(),
                ) ??
                    0;

            final validSelectedMembers =
            selectedMemberIds
                .where(
                  (id) => id.isNotEmpty,
            )
                .toList();

            final selectedCount =
                validSelectedMembers.length;

            final share =
            selectedCount == 0
                ? 0
                : parsedAmount /
                selectedCount;

            return AlertDialog(
              title: const Text(
                'Add Shared Expense',
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller:
                        titleController,
                        textCapitalization:
                        TextCapitalization
                            .sentences,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'Expense title',
                          hintText:
                          'Dinner, Taxi, Hotel...',
                          prefixIcon: Icon(
                            Icons.receipt_long,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      TextField(
                        controller:
                        amountController,
                        keyboardType:
                        const TextInputType
                            .numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                        decoration:
                        const InputDecoration(
                          labelText: 'Amount',
                          prefixText: '₹ ',
                          prefixIcon: Icon(
                            Icons.currency_rupee,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      DropdownButtonFormField<
                          String>(
                        initialValue: category,
                        decoration:
                        const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(
                            Icons.category_outlined,
                          ),
                        ),
                        items: const [
                          'Food',
                          'Transport',
                          'Hotel',
                          'Activities',
                          'Shopping',
                          'Other',
                        ]
                            .map(
                              (item) =>
                              DropdownMenuItem(
                                value: item,
                                child:
                                Text(item),
                              ),
                        )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setDialogState(() {
                            category = value;
                          });
                        },
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      TextField(
                        controller:
                        noteController,
                        maxLines: 2,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'Note (optional)',
                          prefixIcon: Icon(
                            Icons.notes,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      const Text(
                        'Split with',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      RadioListTile<bool>(
                        contentPadding:
                        EdgeInsets.zero,
                        title: const Text(
                          'Everyone',
                        ),
                        subtitle: Text(
                          '${_members.length} trip member${_members.length == 1 ? '' : 's'}',
                        ),
                        value: true,
                        groupValue:
                        splitWithEveryone,
                        onChanged: (_) {
                          setDialogState(() {
                            splitWithEveryone =
                            true;

                            selectedMemberIds
                              ..clear()
                              ..addAll(
                                _members
                                    .map(
                                      (member) =>
                                  member[
                                  'userId']
                                      ?.toString() ??
                                      '',
                                )
                                    .where(
                                      (id) =>
                                  id.isNotEmpty,
                                ),
                              );
                          });
                        },
                      ),

                      RadioListTile<bool>(
                        contentPadding:
                        EdgeInsets.zero,
                        title: const Text(
                          'Selected travelers',
                        ),
                        subtitle: const Text(
                          'Choose who shares this expense',
                        ),
                        value: false,
                        groupValue:
                        splitWithEveryone,
                        onChanged: (_) {
                          setDialogState(() {
                            splitWithEveryone =
                            false;
                          });
                        },
                      ),

                      if (!splitWithEveryone)
                        Container(
                          margin:
                          const EdgeInsets.only(
                            top: 4,
                          ),
                          decoration:
                          BoxDecoration(
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                            border: Border.all(
                              color: Colors
                                  .grey
                                  .shade300,
                            ),
                          ),
                          child: Column(
                            children: _members
                                .map(
                                  (member) {
                                final userId =
                                    member[
                                    'userId']
                                        ?.toString() ??
                                        '';

                                if (userId
                                    .isEmpty) {
                                  return const SizedBox
                                      .shrink();
                                }

                                final isSelected =
                                selectedMemberIds
                                    .contains(
                                  userId,
                                );

                                return CheckboxListTile(
                                  value:
                                  isSelected,
                                  title: Text(
                                    _memberName(
                                      member,
                                    ),
                                  ),
                                  subtitle:
                                  Text(
                                    member[
                                    'email']
                                        ?.toString() ??
                                        '',
                                  ),
                                  onChanged:
                                      (value) {
                                    setDialogState(
                                          () {
                                        if (value ==
                                            true) {
                                          selectedMemberIds
                                              .add(
                                            userId,
                                          );
                                        } else {
                                          selectedMemberIds
                                              .remove(
                                            userId,
                                          );
                                        }
                                      },
                                    );
                                  },
                                );
                              },
                            )
                                .toList(),
                          ),
                        ),

                      if (selectedCount >
                          0 &&
                          parsedAmount > 0)
                        Container(
                          width: double.infinity,
                          margin:
                          const EdgeInsets.only(
                            top: 14,
                          ),
                          padding:
                          const EdgeInsets.all(
                            14,
                          ),
                          decoration:
                          BoxDecoration(
                            color: const Color(
                              0xFFEAF4FF,
                            ),
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              const Text(
                                'Equal split',
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                '₹${share.toStringAsFixed(2)} per traveler',
                              ),
                              Text(
                                '$selectedCount traveler${selectedCount == 1 ? '' : 's'} selected',
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(
                        height: 8,
                      ),

                      ListTile(
                        contentPadding:
                        EdgeInsets.zero,
                        leading: const Icon(
                          Icons.calendar_today,
                        ),
                        title: const Text(
                          'Expense date',
                        ),
                        subtitle: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        ),
                        onTap: () async {
                          final picked =
                          await showDatePicker(
                            context: context,
                            initialDate:
                            selectedDate,
                            firstDate: DateTime(
                              2000,
                            ),
                            lastDate: DateTime(
                              2100,
                            ),
                          );

                          if (picked != null) {
                            setDialogState(() {
                              selectedDate =
                                  picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
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
                  const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title =
                    titleController.text
                        .trim();

                    final amount =
                    double.tryParse(
                      amountController.text
                          .trim(),
                    );

                    if (title.isEmpty) {
                      _showMessage(
                        'Enter an expense title.',
                      );
                      return;
                    }

                    if (amount == null ||
                        amount <= 0) {
                      _showMessage(
                        'Enter a valid amount.',
                      );
                      return;
                    }

                    if (selectedMemberIds
                        .isEmpty) {
                      _showMessage(
                        'Select at least one traveler.',
                      );
                      return;
                    }

                    final selectedIds =
                    selectedMemberIds
                        .toList();

                    final totalPaise =
                    (amount * 100).round();

                    final basePaise =
                        totalPaise ~/
                            selectedIds.length;

                    final remainder =
                        totalPaise %
                            selectedIds.length;

                    final splitBetween =
                    <String, double>{};

                    final splitNames =
                    <String, String>{};

                    for (
                    int i = 0;
                    i < selectedIds.length;
                    i++
                    ) {
                      final userId =
                      selectedIds[i];

                      final sharePaise =
                          basePaise +
                              (i < remainder
                                  ? 1
                                  : 0);

                      splitBetween[userId] =
                          sharePaise / 100;

                      final member =
                      _members.firstWhere(
                            (item) =>
                        item['userId']
                            ?.toString() ==
                            userId,
                        orElse: () => {},
                      );

                      splitNames[userId] =
                      member.isNotEmpty
                          ? _memberName(
                        member,
                      )
                          : 'Traveler';
                    }

                    try {
                      await _expenseService
                          .addExpense(
                        tripId:
                        widget.tripId,
                        title: title,
                        amount: totalPaise /
                            100,
                        category:
                        category,
                        note:
                        noteController.text
                            .trim(),
                        date: selectedDate,
                        splitBetween:
                        splitBetween,
                        splitBetweenNames:
                        splitNames,
                      );

                      if (!mounted) return;

                      Navigator.pop(
                        dialogContext,
                      );

                      _showMessage(
                        'Shared expense added successfully.',
                      );
                    } catch (e) {
                      _showMessage(
                        e.toString(),
                      );
                    }
                  },
                  child:
                  const Text('Add Expense'),
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
    try {
      await _expenseService.deleteExpense(
        tripId: widget.tripId,
        expenseId: expense.id,
      );

      _showMessage(
        'Expense deleted.',
      );
    } catch (e) {
      _showMessage(
        e.toString(),
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message.replaceFirst(
              'Exception: ',
              '',
            ),
          ),
          behavior:
          SnackBarBehavior.floating,
        ),
      );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title:
          const Text('Expenses'),
        ),
        body: Center(
          child: Padding(
            padding:
            const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign:
              TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Trip Expenses',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed:
        _showAddExpenseDialog,
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'Add Expense',
        ),
      ),

      body: StreamBuilder<List<Expense>>(
        stream: _expenseService
            .getExpenses(
          widget.tripId,
        ),
        builder: (
            context,
            snapshot,
            ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child:
              CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load expenses.\n${snapshot.error}',
                textAlign:
                TextAlign.center,
              ),
            );
          }

          final expenses =
              snapshot.data ?? [];

          final settlements =
          _calculateSettlements(
            expenses,
          );

          final youOwe =
          _amountYouOwe(
            settlements,
          );

          final youAreOwed =
          _amountYouAreOwed(
            settlements,
          );

          final totalSpent =
          expenses.fold<double>(
            0,
                (sum, expense) =>
            sum + expense.amount,
          );

          final yourPaid =
          expenses
              .where(
                (expense) =>
            expense.paidBy ==
                _currentUserId,
          )
              .fold<double>(
            0,
                (sum, expense) =>
            sum + expense.amount,
          );

          final yourShare =
          expenses.fold<double>(
            0,
                (sum, expense) =>
            sum +
                (expense.splitBetween[
                _currentUserId] ??
                    0),
          );

          return RefreshIndicator(
            onRefresh: _loadTripData,
            child: ListView(
              padding:
              const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                100,
              ),
              children: [
                _buildSummaryCard(
                  totalSpent: totalSpent,
                  yourPaid: yourPaid,
                  yourShare: yourShare,
                  youOwe: youOwe,
                  youAreOwed: youAreOwed,
                ),

                const SizedBox(
                  height: 20,
                ),

                _buildSettlementSection(
                  settlements,
                ),

                const SizedBox(
                  height: 20,
                ),

                Text(
                  'Expenses',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                if (expenses.isEmpty)
                  _buildEmptyState()
                else
                  ...expenses.map(
                        (expense) =>
                        _buildExpenseCard(
                          expense,
                        ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required double totalSpent,
    required double yourPaid,
    required double yourShare,
    required double youOwe,
    required double youAreOwed,
  }) {
    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(
              0.05,
            ),
            blurRadius: 18,
            offset:
            const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip spending',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  'Total spent',
                  totalSpent,
                ),
              ),
              Expanded(
                child: _summaryItem(
                  'You paid',
                  yourPaid,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  'Your share',
                  yourShare,
                ),
              ),
              Expanded(
                child: _balanceSummary(
                  youOwe,
                  youAreOwed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
      String label,
      double amount,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color:
            Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _balanceSummary(
      double youOwe,
      double youAreOwed,
      ) {
    String text;

    if (youOwe > 0.01 &&
        youAreOwed > 0.01) {
      text =
      'Owed ₹${youAreOwed.toStringAsFixed(2)}\nOwe ₹${youOwe.toStringAsFixed(2)}';
    } else if (youAreOwed > 0.01) {
      text =
      'You are owed\n₹${youAreOwed.toStringAsFixed(2)}';
    } else if (youOwe > 0.01) {
      text =
      'You owe\n₹${youOwe.toStringAsFixed(2)}';
    } else {
      text = 'All settled';
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          'Your balance',
          style: TextStyle(
            color:
            Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSettlementSection(
      List<_Settlement> settlements,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF8FBFF,
        ),
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color: const Color(
            0xFFDCEBFA,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFE5F1FF,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(
                    0xFF1677FF,
                  ),
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              const Text(
                'Who owes whom',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          if (settlements.isEmpty)
            const Text(
              'Everyone is settled up 🎉',
              style: TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            )
          else
            ...settlements.map(
                  (settlement) {
                final involvesYou =
                    settlement
                        .fromUserId ==
                        _currentUserId ||
                        settlement
                            .toUserId ==
                            _currentUserId;

                return Container(
                  margin:
                  const EdgeInsets.only(
                    bottom: 8,
                  ),
                  padding:
                  const EdgeInsets.all(
                    13,
                  ),
                  decoration:
                  BoxDecoration(
                    color: involvesYou
                        ? Colors.white
                        : const Color(
                      0xFFFDFDFD,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text:
                          TextSpan(
                            style:
                            TextStyle(
                              color: Colors
                                  .grey
                                  .shade800,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text:
                                settlement.fromUserId ==
                                    _currentUserId
                                    ? 'You'
                                    : settlement.fromName,
                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                              const TextSpan(
                                text:
                                ' owes ',
                              ),
                              TextSpan(
                                text:
                                settlement.toUserId ==
                                    _currentUserId
                                    ? 'you'
                                    : settlement.toName,
                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        '₹${settlement.amount.toStringAsFixed(2)}',
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(
      Expense expense,
      ) {
    final yourShare =
        expense.splitBetween[
        _currentUserId] ??
            0;

    final isPaidByYou =
        expense.paidBy ==
            _currentUserId;

    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(18),
        side: BorderSide(
          color:
          Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(
                  0xFFEAF4FF,
                ),
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Color(
                  0xFF1677FF,
                ),
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    expense.title,
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    '${expense.category} • ${_formatDate(expense.date)}',
                    style:
                    TextStyle(
                      color: Colors
                          .grey
                          .shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(
                    height: 7,
                  ),
                  Text(
                    isPaidByYou
                        ? 'You paid ₹${expense.amount.toStringAsFixed(2)}'
                        : '${expense.paidByName} paid ₹${expense.amount.toStringAsFixed(2)}',
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    yourShare > 0
                        ? 'Your share: ₹${yourShare.toStringAsFixed(2)}'
                        : 'Not included in your share',
                    style:
                    TextStyle(
                      color: Colors
                          .grey
                          .shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            Column(
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${expense.amount.toStringAsFixed(2)}',
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                PopupMenuButton<String>(
                  padding:
                  EdgeInsets.zero,
                  onSelected:
                      (value) {
                    if (value ==
                        'delete') {
                      _deleteExpense(
                        expense,
                      );
                    }
                  },
                  itemBuilder:
                      (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color:
                            Colors.red,
                          ),
                          SizedBox(
                            width: 8,
                          ),
                          Text(
                            'Delete',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding:
      const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 50,
            color:
            Colors.grey.shade400,
          ),
          const SizedBox(
            height: 12,
          ),
          const Text(
            'No expenses yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            'Add the first shared expense for this trip.',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              color:
              Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}