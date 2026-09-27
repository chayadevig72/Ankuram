import 'package:flutter/material.dart';
import 'database/database_helper.dart';

class NewStudentPage extends StatefulWidget {
  const NewStudentPage({super.key});

  @override
  State<NewStudentPage> createState() => _NewStudentPageState();
}

class _NewStudentPageState extends State<NewStudentPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  bool _advancePaid = false;
  bool _feesPaid = false;

  // =====================================================
  // CONSTANT PURPLE
  // Header and buttons intentionally stay the same
  // =====================================================

  static const Color _purple = Color(0xFF4B185D);
  static const Color _darkPurple = Color(0xFF30113B);

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  // =====================================================
  // SUBMIT STUDENT
  // =====================================================

  Future<void> _submitStudent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    try {
      await DatabaseHelper.instance.insertStudent({
        'name': name,
        'phone': phone,
        'advance_paid': _advancePaid ? 1 : 0,
        'fees_paid': _feesPaid ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name added successfully.',
          ),
          backgroundColor: const Color(0xFF238636),
        ),
      );

      _nameController.clear();
      _phoneController.clear();

      setState(() {
        _advancePaid = false;
        _feesPaid = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save student: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================================
  // BACK
  // =====================================================

  void _cancel() {
    Navigator.pop(context);
  }

  // =====================================================
  // INPUT DECORATION
  // Theme-aware
  // =====================================================

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InputDecoration(
      hintText: hintText,

      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
      ),

      prefixIcon: Icon(
        icon,
        color: colorScheme.onSurfaceVariant,
      ),

      filled: true,

      // Changed from Colors.white
      fillColor: colorScheme.surface,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _purple,
          width: 1.5,
        ),
      ),

      // Theme-aware text inside TextField
      contentPadding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 16,
      ),
    );
  }

  // =====================================================
  // PAYMENT ROW
  // Theme-aware
  // =====================================================

  Widget _paymentRow({
    required bool isPaid,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),

      decoration: BoxDecoration(
        // Changed from Colors.white
        color: colorScheme.surface,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),

      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.currency_rupee_rounded,
                  color: _purple,
                  size: 22,
                ),

                const SizedBox(width: 8),

                Text(
                  '₹1,000',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,

                    // Theme-aware
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isPaid ? 'Paid' : 'Unpaid',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,

                  color: isPaid
                      ? const Color(0xFF238636)
                      : Colors.red.shade700,
                ),
              ),

              const SizedBox(width: 8),

              Switch(
                value: isPaid,
                onChanged: onChanged,

                activeThumbColor: Colors.white,

                activeTrackColor:
                    const Color(0xFF238636),

                inactiveThumbColor: Colors.white,

                inactiveTrackColor:
                    colorScheme.outline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(

      // =================================================
      // THEME-AWARE BACKGROUND
      // =================================================

      backgroundColor: colorScheme.surfaceContainerLowest,

      // =================================================
      // APP BAR
      // KEEPING YOUR ORIGINAL PURPLE
      // =================================================

      appBar: AppBar(
        title: const Text(
          'New Student',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        // DO NOT CHANGE
        backgroundColor: _purple,

        foregroundColor: Colors.white,

        elevation: 0,

        scrolledUnderElevation: 0,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                // =================================================
                // TITLE
                // =================================================

                Text(
                  'Student Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,

                    // Theme-aware
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Enter the student information below.',
                  style: TextStyle(
                    fontSize: 14,

                    // Theme-aware
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 28),

                // =================================================
                // STUDENT NAME
                // =================================================

                Text(
                  'Student Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,

                    // Theme-aware
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: _nameController,

                  textCapitalization:
                      TextCapitalization.words,

                  style: TextStyle(
                    color: colorScheme.onSurface,
                  ),

                  decoration: _inputDecoration(
                    hintText:
                        'Enter student name',
                    icon:
                        Icons.person_outline,
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please enter student name';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // =================================================
                // PHONE
                // =================================================

                Text(
                  'Phone Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,

                    // Theme-aware
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: _phoneController,

                  keyboardType:
                      TextInputType.phone,

                  style: TextStyle(
                    color: colorScheme.onSurface,
                  ),

                  decoration: _inputDecoration(
                    hintText:
                        'Enter phone number',
                    icon:
                        Icons.phone_outlined,
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please enter phone number';
                    }

                    if (value.trim().length !=
                        10) {
                      return 'Enter a valid 10-digit phone number';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 25),

                // =================================================
                // ADVANCE
                // =================================================

                Text(
                  'Advance Payment',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,

                    // Theme-aware
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 8),

                _paymentRow(
                  isPaid: _advancePaid,

                  onChanged: (value) {
                    setState(() {
                      _advancePaid = value;
                    });
                  },
                ),

                const SizedBox(height: 22),

                // =================================================
                // INITIAL FEE
                // =================================================

                Text(
                  'Initial Fees',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,

                    // Theme-aware
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 8),

                _paymentRow(
                  isPaid: _feesPaid,

                  onChanged: (value) {
                    setState(() {
                      _feesPaid = value;
                    });
                  },
                ),

                const SizedBox(height: 35),

                // =================================================
                // SUBMIT BUTTON
                // KEEPING YOUR ORIGINAL PURPLE
                // =================================================

                SizedBox(
                  width: double.infinity,
                  height: 55,

                  child: FilledButton(
                    onPressed: _submitStudent,

                    style: FilledButton.styleFrom(
                      // DO NOT CHANGE
                      backgroundColor: _purple,

                      foregroundColor:
                          Colors.white,

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),

                    child: const Text(
                      'SUBMIT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // =================================================
                // BACK BUTTON
                // KEEPING PURPLE
                // =================================================

                SizedBox(
                  width: double.infinity,
                  height: 55,

                  child: OutlinedButton(
                    onPressed: _cancel,

                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor: _purple,

                      side: const BorderSide(
                        color: _purple,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),

                    child: const Text(
                      'BACK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}