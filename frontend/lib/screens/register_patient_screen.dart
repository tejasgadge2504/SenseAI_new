import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../services/storage_service.dart';
import '../widgets/top_bar.dart';
import '../widgets/bottom_nav.dart';
import '../theme.dart';

class RegisterPatientScreen extends StatefulWidget {
  const RegisterPatientScreen({super.key});

  @override
  State<RegisterPatientScreen> createState() => _RegisterPatientScreenState();
}

class _RegisterPatientScreenState extends State<RegisterPatientScreen> {
  final _nameController  = TextEditingController();
  final _ageController   = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedGender = 'Male';
  bool _isSaving = false;

  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _savePatient() async {
    final name  = _nameController.text.trim();
    final age   = _ageController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || age.isEmpty || phone.isEmpty) {
      _showSnack('Please fill in all fields', isError: true);
      return;
    }
    if (int.tryParse(age) == null ||
        int.parse(age) <= 0 ||
        int.parse(age) > 120) {
      _showSnack('Please enter a valid age', isError: true);
      return;
    }
    if (phone.length < 10) {
      _showSnack('Please enter a valid phone number', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final patient = Patient(
        id:           DateTime.now().millisecondsSinceEpoch.toString(),
        name:         name,
        age:          int.parse(age),
        gender:       _selectedGender,
        registeredAt: DateTime.now().toIso8601String(),
        phone:        phone,
      );
      await StorageService.savePatient(patient);
      if (!mounted) return;
      _showSnack('Patient "$name" registered successfully!');
      _nameController.clear();
      _ageController.clear();
      _phoneController.clear();
      setState(() {
        _isSaving = false;
        _selectedGender = 'Male';
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack('Error: $e', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle,
            color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: isError ? Colors.redAccent : AppColors.darkGreen,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const RuraxTopBar(title: 'Register Patient', showBack: true),
            Expanded(
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Register Patient',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    const Text('ONBOARD NEW PATIENT',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textLight,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 28),

                    // ── Name ─────────────────────────────────────────────
                    _label('NAME'),
                    const SizedBox(height: 6),
                    _textField(
                        controller: _nameController,
                        hint: 'Full Name',
                        icon: Icons.person_outline,
                        type: TextInputType.name),
                    const SizedBox(height: 16),

                    // ── Age + Gender ──────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('AGE'),
                              const SizedBox(height: 6),
                              _textField(
                                  controller: _ageController,
                                  hint: 'Age',
                                  icon: Icons.calendar_today_outlined,
                                  type: TextInputType.number),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('GENDER'),
                              const SizedBox(height: 6),
                              _genderDropdown(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Phone ─────────────────────────────────────────────
                    _label('PHONE NUMBER'),
                    const SizedBox(height: 6),
                    _textField(
                        controller: _phoneController,
                        hint: 'Mobile Number',
                        icon: Icons.phone_outlined,
                        type: TextInputType.phone),
                    const SizedBox(height: 28),

                    // ── Save button ───────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _savePatient,
                        child: _isSaving
                            ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Save',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(width: 8),
                            Icon(Icons.check_circle_outline, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Quick guide ───────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('QUICK GUIDE',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textLight,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 12),
                          ...[
                            "Enter patient's legal name",
                            "Verify age with ID if possible",
                            "Enter a valid 10-digit mobile number",
                            "Proceed to diagnosis after saving",
                          ].map((tip) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 5),
                                  child: CircleAvatar(
                                      radius: 4,
                                      backgroundColor: AppColors.midGreen),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(tip,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textMid,
                                            height: 1.4))),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RuraxBottomNav(
          selectedIndex: 1,
          onTap: (i) {
            if (i == 0) Navigator.pop(context);
          }),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textLight,
          letterSpacing: 1.1));

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
  }) =>
      Container(
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: TextField(
          controller: controller,
          keyboardType: type,
          style: const TextStyle(fontSize: 15, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.textHint, size: 20),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      );

  Widget _genderDropdown() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedGender,
        icon: const Icon(Icons.keyboard_arrow_down,
            color: AppColors.textHint, size: 20),
        isExpanded: true,
        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
        items: _genders
            .map((g) => DropdownMenuItem(
            value: g,
            child: Row(children: [
              const Icon(Icons.people_outline,
                  color: AppColors.textHint, size: 18),
              const SizedBox(width: 8),
              Text(g),
            ])))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _selectedGender = v);
        },
      ),
    ),
  );
}