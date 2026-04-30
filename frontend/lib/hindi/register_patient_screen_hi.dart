import 'package:flutter/material.dart';
import '../../models/patient.dart';
import '../../services/storage_service.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/bottom_nav.dart';
import '../../theme.dart';

class RegisterPatientScreenHi extends StatefulWidget {
  const RegisterPatientScreenHi({super.key});

  @override
  State<RegisterPatientScreenHi> createState() => _RegisterPatientScreenHiState();
}

class _RegisterPatientScreenHiState extends State<RegisterPatientScreenHi> {
  final _nameController  = TextEditingController();
  final _ageController   = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedGender = 'पुरुष';
  bool _isSaving = false;

  final List<String> _genders = ['पुरुष', 'महिला', 'अन्य'];
  // Internal values map to English for storage consistency
  final Map<String, String> _genderToEnglish = {
    'पुरुष': 'Male',
    'महिला': 'Female',
    'अन्य': 'Other',
  };

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
      _showSnack('कृपया सभी फ़ील्ड भरें', isError: true);
      return;
    }
    if (int.tryParse(age) == null ||
        int.parse(age) <= 0 ||
        int.parse(age) > 120) {
      _showSnack('कृपया वैध आयु दर्ज करें', isError: true);
      return;
    }
    if (phone.length < 10) {
      _showSnack('कृपया वैध फ़ोन नंबर दर्ज करें', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final patient = Patient(
        id:           DateTime.now().millisecondsSinceEpoch.toString(),
        name:         name,
        age:          int.parse(age),
        gender:       _genderToEnglish[_selectedGender] ?? _selectedGender,
        registeredAt: DateTime.now().toIso8601String(),
        phone:        phone,
      );
      await StorageService.savePatient(patient);
      if (!mounted) return;
      _showSnack('"$name" सफलतापूर्वक पंजीकृत किया गया!');
      _nameController.clear();
      _ageController.clear();
      _phoneController.clear();
      setState(() {
        _isSaving = false;
        _selectedGender = 'पुरुष';
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack('त्रुटि: $e', isError: true);
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
            const RuraxTopBar(title: 'मरीज़ पंजीकरण', showBack: true),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('मरीज़ पंजीकरण',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    const Text('नया मरीज़ जोड़ें',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textLight,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 28),

                    _label('नाम'),
                    const SizedBox(height: 6),
                    _textField(
                        controller: _nameController,
                        hint: 'पूरा नाम',
                        icon: Icons.person_outline,
                        type: TextInputType.name),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('आयु'),
                              const SizedBox(height: 6),
                              _textField(
                                  controller: _ageController,
                                  hint: 'आयु',
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
                              _label('लिंग'),
                              const SizedBox(height: 6),
                              _genderDropdown(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _label('फ़ोन नंबर'),
                    const SizedBox(height: 6),
                    _textField(
                        controller: _phoneController,
                        hint: 'मोबाइल नंबर',
                        icon: Icons.phone_outlined,
                        type: TextInputType.phone),
                    const SizedBox(height: 28),

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
                            Text('सहेजें',
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

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('त्वरित मार्गदर्शिका',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textLight,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 12),
                          ...[
                            'मरीज़ का पूरा कानूनी नाम दर्ज करें',
                            'यदि संभव हो तो पहचान पत्र से आयु सत्यापित करें',
                            'एक वैध 10 अंकों का मोबाइल नंबर दर्ज करें',
                            'सहेजने के बाद जांच के लिए आगे बढ़ें',
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