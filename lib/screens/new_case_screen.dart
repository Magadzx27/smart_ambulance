import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/ambulance_request.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'hospital_selection_screen.dart';

class NewCaseScreen extends StatefulWidget {
  const NewCaseScreen({super.key});
  @override
  State<NewCaseScreen> createState() => _NewCaseScreenState();
}

class _NewCaseScreenState extends State<NewCaseScreen> {
  final _formKey = GlobalKey<FormState>();

  // Patient Info
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _descController = TextEditingController();

  // Vital Signs
  final _heartRateController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _bpController = TextEditingController();
  final _tempController = TextEditingController();

  String _caseType = 'accident';
  String _severity = 'high';
  bool _isLocating = false;

  static const caseTypes = [
    {'value': 'accident',       'label': 'حادث',           'icon': Icons.car_crash},
    {'value': 'heart_attack',   'label': 'نوبة قلبية',     'icon': Icons.favorite},
    {'value': 'childbirth',     'label': 'ولادة',          'icon': Icons.child_care},
    {'value': 'other',          'label': 'حالات أخرى',    'icon': Icons.medical_services},
  ];

  static final severities = [
    {'value': 'high',   'label': 'حرجة 🔴',  'color': Color(0xFFE53935)},
    {'value': 'medium', 'label': 'متوسطة 🟡', 'color': Color(0xFFF9A825)},
    {'value': 'low',    'label': 'خفيفة 🟢',  'color': Color(0xFF43A047)},
  ];

  Future<void> _proceed() async {
    if (!_formKey.currentState!.validate()) return;
    
    FocusScope.of(context).unfocus();

    setState(() => _isLocating = true);
    
    Position? position;
    try {
      position = await LocationService.getCurrentPosition();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString(), style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red),
      );
      setState(() => _isLocating = false);
      return;
    }

    if (position != null) {
      try {
        await ApiService.updateLocation(position.latitude, position.longitude);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث الموقع: $e', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange),
        );
      }
    }

    final caseLabel = caseTypes.firstWhere((c) => c['value'] == _caseType)['label'] as String;
    final desc = _descController.text.isNotEmpty ? _descController.text : caseLabel;

    List<Hospital> hospitals = [];
    try {
      hospitals = await ApiService.searchHospitals(_caseType, desc);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString(), style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red),
      );
      setState(() => _isLocating = false);
      return;
    }
    
    setState(() => _isLocating = false);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HospitalSelectionScreen(
          hospitals: hospitals,
          request: AmbulanceRequest(
            title: desc,
            severity: _severity,
            hospitalId: 0, // updated after selection
            patientName: _nameController.text.isNotEmpty ? _nameController.text : null,
            patientAge: int.tryParse(_ageController.text),
            caseClassification: _caseType,
            description: _descController.text.isNotEmpty ? _descController.text : null,
            heartRate: int.tryParse(_heartRateController.text),
            oxygenSaturation: int.tryParse(_spo2Controller.text),
            bloodPressure: _bpController.text.isNotEmpty ? _bpController.text : null,
            bodyTemperature: double.tryParse(_tempController.text),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        title: const Text('حالة جديدة 🚑', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Patient Info Section
            _sectionTitle('بيانات المريض (اختياري)'),
            const SizedBox(height: 12),
            _buildTextField(_nameController, 'الاسم', Icons.person),
            const SizedBox(height: 12),
            _buildTextField(_ageController, 'العمر', Icons.cake, keyboardType: TextInputType.number, validator: (v) {
              if (v != null && v.isNotEmpty) {
                final age = int.tryParse(v);
                if (age == null || age < 0 || age > 150) return 'عمر المريض غير صالح';
              }
              return null;
            }),
            const SizedBox(height: 24),

            // Case Type
            _sectionTitle('نوع الحالة *'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.4,
              children: caseTypes.map((type) {
                final selected = _caseType == type['value'];
                return GestureDetector(
                  onTap: () => setState(() => _caseType = type['value'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFE53935) : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? const Color(0xFFE53935) : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(type['icon'] as IconData, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(type['label'] as String,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Severity
            _sectionTitle('درجة الخطورة *'),
            const SizedBox(height: 12),
            Row(
              children: severities.map((s) {
                final selected = _severity == s['value'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _severity = s['value'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? (s['color'] as Color).withOpacity(0.2) : const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? s['color'] as Color : Colors.white12,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        s['label'] as String,
                        style: TextStyle(
                          color: selected ? s['color'] as Color : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Description
            _sectionTitle('وصف الحالة'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('اكتب وصفاً مختصراً للحالة...', Icons.description),
              validator: (v) {
                if (v != null && v.length > 1000) return 'وصف الحالة طويل جدًا';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Vital Signs
            _sectionTitle('الإشارات الحيوية (يدوي)'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _buildTextField(_heartRateController, 'BPM ضربات القلب', Icons.monitor_heart, keyboardType: TextInputType.number, validator: (v) {
                if (v != null && v.isNotEmpty) {
                  final bpm = int.tryParse(v);
                  if (bpm == null || bpm < 20 || bpm > 250) return 'معدل نبض القلب غير طبيعي';
                }
                return null;
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(_spo2Controller, 'SpO2 الأكسجين %', Icons.air, keyboardType: TextInputType.number, validator: (v) {
                if (v != null && v.isNotEmpty) {
                  final spo2 = int.tryParse(v);
                  if (spo2 == null || spo2 < 0 || spo2 > 100) return 'نسبة الأكسجين غير صحيحة';
                }
                return null;
              })),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _buildTextField(_bpController, 'ضغط الدم', Icons.speed, validator: (v) {
                if (v != null && v.isNotEmpty) {
                  if (!RegExp(r'^\d{2,3}\/\d{2,3}$').hasMatch(v)) return 'صيغة ضغط الدم غير صحيحة';
                }
                return null;
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(_tempController, 'درجة الحرارة °C', Icons.thermostat, keyboardType: TextInputType.number, validator: (v) {
                if (v != null && v.isNotEmpty) {
                  final temp = double.tryParse(v);
                  if (temp == null || temp < 30 || temp > 45) return 'درجة الحرارة غير منطقية';
                }
                return null;
              })),
            ]),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isLocating ? null : _proceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isLocating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.navigate_next_rounded, size: 28),
                label: Text(
                  _isLocating ? 'جارٍ المعالجة...' : 'اختيار المستشفى',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Align(
    alignment: Alignment.centerRight,
    child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
  );

  Widget _buildTextField(TextEditingController c, String label, IconData icon,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
    prefixIcon: Icon(icon, color: Colors.white38, size: 20),
    filled: true,
    fillColor: const Color(0xFF161B22),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}