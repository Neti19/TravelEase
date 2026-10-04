import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../models/trip.dart';
import '../../services/expense_service.dart';
import '../../services/trip_member_service.dart';
import '../../services/trip_service.dart';
import '../../widgets/dashboard_navigation_button.dart';

class ExpenseTrackerScreen extends StatefulWidget {
  final String tripId;

  const ExpenseTrackerScreen({super.key, required this.tripId});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
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

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  static const _ink = Color(0xFF18324B);
  static const _muted = Color(0xFF748397);
  static const _blue = Color(0xFF367BE8);
  static const _canvas = Color(0xFFF4F7FB);

  final ExpenseService _expenseService = ExpenseService();
  final TripService _tripService = TripService();
  final TripMemberService _memberService = TripMemberService();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Trip? _trip;
  List<Map<String, dynamic>> _members = [];

  bool _loading = true;
  String? _error;

  User? get _currentUser => _auth.currentUser;

  String get _currentUserId => _currentUser?.uid ?? '';

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

      final trip = await _tripService.getTrip(widget.tripId);

      if (trip == null) {
        throw Exception('Trip not found.');
      }

      final members = await _memberService.getTripMembers(widget.tripId);

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

  String _memberName(Map<String, dynamic> member) {
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
      final userId = member['userId']?.toString() ?? '';

      if (userId.isNotEmpty) {
        result[userId] = _memberName(member);
      }
    }

    return result;
  }

  List<_Settlement> _calculateSettlements(List<Expense> expenses) {
    final netBalances = <String, double>{};
    final names = <String, String>{..._memberNameMap()};

    for (final expense in expenses) {
      names[expense.paidBy] = expense.paidByName;

      netBalances[expense.paidBy] =
          (netBalances[expense.paidBy] ?? 0) + expense.amount;

      for (final entry in expense.splitBetween.entries) {
        final userId = entry.key;
        final share = entry.value;

        names[userId] ??= expense.splitBetweenNames[userId] ?? 'Traveler';

        netBalances[userId] = (netBalances[userId] ?? 0) - share;
      }
    }

    final debtors = <Map<String, dynamic>>[];
    final creditors = <Map<String, dynamic>>[];

    for (final entry in netBalances.entries) {
      final amount = double.parse(entry.value.toStringAsFixed(2));

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

    while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
      final debtor = debtors[debtorIndex];
      final creditor = creditors[creditorIndex];

      final debt = debtor['amount'] as double;
      final credit = creditor['amount'] as double;

      final payment = debt < credit ? debt : credit;

      if (payment > 0.01) {
        settlements.add(
          _Settlement(
            fromUserId: debtor['userId'].toString(),
            fromName: debtor['name'].toString(),
            toUserId: creditor['userId'].toString(),
            toName: creditor['name'].toString(),
            amount: double.parse(payment.toStringAsFixed(2)),
          ),
        );
      }

      debtor['amount'] = debt - payment;
      creditor['amount'] = credit - payment;

      if ((debtor['amount'] as double) <= 0.01) {
        debtorIndex++;
      }

      if ((creditor['amount'] as double) <= 0.01) {
        creditorIndex++;
      }
    }

    return settlements;
  }

  double _amountYouOwe(List<_Settlement> settlements) {
    return settlements
        .where((item) => item.fromUserId == _currentUserId)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double _amountYouAreOwed(List<_Settlement> settlements) {
    return settlements
        .where((item) => item.toUserId == _currentUserId)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  Future<void> _showAddExpenseDialog() async {
    final titleController = TextEditingController();

    final amountController = TextEditingController();

    final noteController = TextEditingController();

    String category = 'Food';

    DateTime selectedDate = DateTime.now();

    bool splitWithEveryone = true;

    final selectedMemberIds = <String>{
      ..._members
          .map((member) => member['userId']?.toString() ?? '')
          .where((id) => id.isNotEmpty),
    };

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final parsedAmount =
                double.tryParse(amountController.text.trim()) ?? 0;

            final validSelectedMembers = selectedMemberIds
                .where((id) => id.isNotEmpty)
                .toList();

            final selectedCount = validSelectedMembers.length;

            final share = selectedCount == 0 ? 0 : parsedAmount / selectedCount;

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              title: const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: _blue, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Add an expense',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Expense title',
                          hintText: 'Dinner, Taxi, Hotel...',
                          filled: true,
                          fillColor: Color(0xFFF6F8FB),
                          prefixIcon: Icon(Icons.receipt_long),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixText: '₹ ',
                          filled: true,
                          fillColor: Color(0xFFF6F8FB),
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                      ),

                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          filled: true,
                          fillColor: Color(0xFFF6F8FB),
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items:
                            const [
                                  'Food',
                                  'Transport',
                                  'Hotel',
                                  'Activities',
                                  'Shopping',
                                  'Other',
                                ]
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item),
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

                      const SizedBox(height: 14),

                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                          filled: true,
                          fillColor: Color(0xFFF6F8FB),
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'Split with',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: _splitModeCard(
                              selected: splitWithEveryone,
                              icon: Icons.groups_rounded,
                              title: 'Everyone',
                              subtitle: '${_members.length} travelers',
                              onTap: () {
                                setDialogState(() {
                                  splitWithEveryone = true;
                                  selectedMemberIds
                                    ..clear()
                                    ..addAll(
                                      _members
                                          .map(
                                            (member) =>
                                                member['userId']?.toString() ??
                                                '',
                                          )
                                          .where((id) => id.isNotEmpty),
                                    );
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _splitModeCard(
                              selected: !splitWithEveryone,
                              icon: Icons.person_add_alt_1_rounded,
                              title: 'Choose people',
                              subtitle: 'Custom split',
                              onTap: () {
                                setDialogState(() {
                                  splitWithEveryone = false;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      if (!splitWithEveryone)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5EBF2)),
                          ),
                          child: Column(
                            children: _members.map((member) {
                              final userId = member['userId']?.toString() ?? '';

                              if (userId.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              final isSelected = selectedMemberIds.contains(
                                userId,
                              );

                              return CheckboxListTile(
                                value: isSelected,
                                title: Text(_memberName(member)),
                                subtitle: Text(
                                  member['email']?.toString() ?? '',
                                ),
                                onChanged: (value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      selectedMemberIds.add(userId);
                                    } else {
                                      selectedMemberIds.remove(userId);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),

                      if (selectedCount > 0 && parsedAmount > 0)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Equal split',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text('₹${share.toStringAsFixed(2)} per traveler'),
                              Text(
                                '$selectedCount traveler${selectedCount == 1 ? '' : 's'} selected',
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Expense date'),
                        subtitle: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
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
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();

                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );

                    if (title.isEmpty) {
                      _showMessage('Enter an expense title.');
                      return;
                    }

                    if (amount == null || amount <= 0) {
                      _showMessage('Enter a valid amount.');
                      return;
                    }

                    if (selectedMemberIds.isEmpty) {
                      _showMessage('Select at least one traveler.');
                      return;
                    }

                    final selectedIds = selectedMemberIds.toList();

                    final totalPaise = (amount * 100).round();

                    final basePaise = totalPaise ~/ selectedIds.length;

                    final remainder = totalPaise % selectedIds.length;

                    final splitBetween = <String, double>{};

                    final splitNames = <String, String>{};

                    for (int i = 0; i < selectedIds.length; i++) {
                      final userId = selectedIds[i];

                      final sharePaise = basePaise + (i < remainder ? 1 : 0);

                      splitBetween[userId] = sharePaise / 100;

                      final member = _members.firstWhere(
                        (item) => item['userId']?.toString() == userId,
                        orElse: () => {},
                      );

                      splitNames[userId] = member.isNotEmpty
                          ? _memberName(member)
                          : 'Traveler';
                    }

                    try {
                      await _expenseService.addExpense(
                        tripId: widget.tripId,
                        title: title,
                        amount: totalPaise / 100,
                        category: category,
                        note: noteController.text.trim(),
                        date: selectedDate,
                        splitBetween: splitBetween,
                        splitBetweenNames: splitNames,
                      );

                      if (!dialogContext.mounted) return;

                      Navigator.pop(dialogContext);

                      if (!mounted) return;
                      _showMessage('Shared expense added successfully.');
                    } catch (e) {
                      _showMessage(e.toString());
                    }
                  },
                  child: const Text('Add Expense'),
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

  Widget _splitModeCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final foreground = selected ? _blue : _muted;

    return Material(
      color: selected ? const Color(0xFFEAF2FF) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _blue : const Color(0xFFE5EBF2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 19),
              const SizedBox(height: 7),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? _ink : _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    try {
      await _expenseService.deleteExpense(
        tripId: widget.tripId,
        expenseId: expense.id,
      );

      _showMessage('Expense deleted.');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message.replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Expenses'),
          actions: const [DashboardNavigationButton()],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _canvas,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Split expenses',
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            if (_trip?.name.isNotEmpty == true)
              Text(
                _trip!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: const [DashboardNavigationButton()],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 5,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add expense',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),

      body: StreamBuilder<List<Expense>>(
        stream: _expenseService.getExpenses(widget.tripId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load expenses.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final expenses = snapshot.data ?? [];

          final settlements = _calculateSettlements(expenses);

          final youOwe = _amountYouOwe(settlements);

          final youAreOwed = _amountYouAreOwed(settlements);

          final totalSpent = expenses.fold<double>(
            0,
            (sum, expense) => sum + expense.amount,
          );

          final yourPaid = expenses
              .where((expense) => expense.paidBy == _currentUserId)
              .fold<double>(0, (sum, expense) => sum + expense.amount);

          final yourShare = expenses.fold<double>(
            0,
            (sum, expense) => sum + (expense.splitBetween[_currentUserId] ?? 0),
          );

          return RefreshIndicator(
            onRefresh: _loadTripData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
              children: [
                _buildTripHeader(),
                const SizedBox(height: 18),
                _buildSummaryCard(
                  totalSpent: totalSpent,
                  yourPaid: yourPaid,
                  yourShare: yourShare,
                  youOwe: youOwe,
                  youAreOwed: youAreOwed,
                ),

                const SizedBox(height: 18),
                _buildSettlementSection(settlements),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent expenses',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEF6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${expenses.length}',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),

                if (expenses.isEmpty)
                  _buildEmptyState()
                else
                  ...expenses.map((expense) => _buildExpenseCard(expense)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTripHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _trip?.name.isNotEmpty == true ? _trip!.name : 'Your trip',
          style: const TextStyle(
            color: _ink,
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Keep shared spending clear and fair.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6ECF3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_2_rounded, color: _blue, size: 20),
              const SizedBox(width: 9),
              Text(
                'Trip group',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '${_members.length} ${_members.length == 1 ? 'traveler' : 'travelers'}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const Spacer(),
              SizedBox(
                height: 30,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _members.take(5).map((member) {
                      final name = _memberName(member);
                      final initial = name.trim().isEmpty
                          ? '?'
                          : name.trim()[0].toUpperCase();
                      return Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFFE7F0FF),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: _blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173652), Color(0xFF1D5870)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20173652),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total trip spending',
                  style: TextStyle(
                    color: Color(0xFFD8E8F2),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded,
                      color: Color(0xFFB8E8D9),
                      size: 14,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Shared',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '₹${totalSpent.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _summaryTile('You paid', yourPaid)),
              const SizedBox(width: 10),
              Expanded(child: _summaryTile('Your share', yourShare)),
            ],
          ),
          const SizedBox(height: 12),
          _balanceSummary(youOwe, youAreOwed),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, double amount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD8E8F2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceSummary(double youOwe, double youAreOwed) {
    final settled = youOwe <= 0.01 && youAreOwed <= 0.01;
    final owes = youOwe > 0.01;
    final isOwed = youAreOwed > 0.01;
    final bothDirections = owes && isOwed;
    final label = settled
        ? 'You are all settled up'
        : bothDirections
        ? 'Owe ₹${youOwe.toStringAsFixed(2)} · owed ₹${youAreOwed.toStringAsFixed(2)}'
        : owes
        ? 'You owe'
        : 'You are owed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: settled
            ? const Color(0xFFBDE8D3).withValues(alpha: 0.14)
            : (owes
                  ? const Color(0xFFFFD6C9).withValues(alpha: 0.15)
                  : const Color(0xFFBDE8D3).withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            settled
                ? Icons.check_circle_outline_rounded
                : owes && !isOwed
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: settled || !owes
                ? const Color(0xFF9BE0C3)
                : const Color(0xFFFFB69F),
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE5F0F5),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!settled && !bothDirections)
            Text(
              '₹${(owes ? youOwe : youAreOwed).toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettlementSection(List<_Settlement> settlements) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F1FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Color(0xFF1677FF),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Settle up',
                style: TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (settlements.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7F0),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.celebration_rounded,
                    color: Color(0xFF2A9D6F),
                    size: 18,
                  ),
                  SizedBox(width: 9),
                  Text(
                    'Everyone is settled up',
                    style: TextStyle(
                      color: Color(0xFF267A59),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            ...settlements.map((settlement) {
              final involvesYou =
                  settlement.fromUserId == _currentUserId ||
                  settlement.toUserId == _currentUserId;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: involvesYou
                      ? const Color(0xFFF4F8FE)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: settlement.fromUserId == _currentUserId
                                  ? 'You'
                                  : settlement.fromName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ' owes '),
                            TextSpan(
                              text: settlement.toUserId == _currentUserId
                                  ? 'you'
                                  : settlement.toName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      '₹${settlement.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final yourShare = expense.splitBetween[_currentUserId] ?? 0;

    final isPaidByYou = expense.paidBy == _currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(color: const Color(0xFFE6ECF3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: _blue),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${expense.category} • ${_formatDate(expense.date)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    isPaidByYou
                        ? 'You paid ₹${expense.amount.toStringAsFixed(2)}'
                        : '${expense.paidByName} paid ₹${expense.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    yourShare > 0
                        ? 'Your share: ₹${yourShare.toStringAsFixed(2)}'
                        : 'Not included in your share',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteExpense(expense);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
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
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 50,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'No expenses yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            'Add the first shared expense for this trip.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
