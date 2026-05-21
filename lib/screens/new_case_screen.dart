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

  // ✅ FIX: القيم تطابق تماماً ما يقبله الـ API
  // case_classification: accident | heart_attack | childbirth | other
  // severity: high | medium | low
  String _caseType = 'accident';
  String _severity = 'high';
  bool _isLocating = false;

  static const caseTypes = [
    {'value': 'accident', 'label': 'حادث', 'icon': Icons.car_crash},
    {'value': 'heart_attack', 'label': 'نوبة قلبية', 'icon': Icons.favorite},
    {'value': 'childbirth', 'label': 'ولادة', 'icon': Icons.child_care},
    {'value': 'other', 'label': 'حالات أخرى', 'icon': Icons.medical_services},
  ];

  static final severities = [
    {
      'value': 'high',
      'label': 'حرجة 🔴',
      'color': const Color(0xFFE53935)
    },
    {
      'value': 'medium',
      'label': 'متوسطة 🟡',
      'color': const Color(0xFFF9A825)
    },
    {
      'value': 'low',
      'label': 'خفيفة 🟢',
      'color': const Color(0xFF43A047)
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _descController.dispose();
    _heartRateController.dispose();
    _spo2Controller.dispose();
    _bpController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLocating = true);

    // ── الخطوة 1: جلب الموقع ──────────────────────────────────
    Position? position;
    try {
      position = await LocationService.getCurrentPosition();
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
      setState(() => _isLocating = false);
      return;
    }

    // ── الخطوة 2: تحديث الموقع على الـ API ────────────────────
    // ✅ FIX: يجب تحديث الموقع أولاً وإلا سيُعيد /hospitals/search خطأ 400
    if (position != null) {
      try {
        await ApiService.updateLocation(
            position.latitude, position.longitude);
      } catch (e) {
        if (!mounted) return;
        // ✅ FIX: إذا فشل تحديث الموقع نُوقف العملية كلياً
        // (لأن البحث عن المستشفيات بدون موقع سيفشل بـ 400)
        _showError(
            'تعذر تحديث الموقع الجغرافي\nيرجى التحقق من الاتصال والمحاولة مجدداً');
        setState(() => _isLocating = false);
        return;
      }
    }

    // ── الخطوة 3: البحث عن المستشفيات ─────────────────────────
    final caseLabel =
    caseTypes.firstWhere((c) => c['value'] == _caseType)['label'] as String;

    // ✅ FIX: title يُشتق من وصف المستخدم إن وُجد، وإلا من اسم نوع الحالة
    final title =
    _descController.text.isNotEmpty ? _descController.text : caseLabel;

    List<Hospital> hospitals;
    try {
      hospitals = await ApiService.searchHospitals(
          _caseType, _descController.text);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
      setState(() => _isLocating = false);
      return;
    }

    setState(() => _isLocating = false);
    if (!mounted) return;

    // ✅ FIX: تحذير عند عدم وجود مستشفيات بدلاً من الانتقال لشاشة فارغة
    if (hospitals.isEmpty) {
      _showError('لم يتم العثور على مستشفيات متاحة في منطقتك حالياً');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HospitalSelectionScreen(
          hospitals: hospitals,
          request: AmbulanceRequest(
            title: title,
            severity: _severity,
            hospitalId: 0, // يُحدَّث بعد الاختيار في HospitalSelectionScreen
            patientName: _nameController.text.isNotEmpty
                ? _nameController.text.trim()
                : null,
            patientAge: int.tryParse(_ageController.text),
            caseClassification: _caseType,
            description: _descController.text.isNotEmpty
                ? _descController.text.trim()
                : null,
            heartRate: int.tryParse(_heartRateController.text),
            oxygenSaturation: int.tryParse(_spo2Controller.text),
            bloodPressure: _bpController.text.isNotEmpty
                ? _bpController.text.trim()
                : null,
            bodyTemperature: double.tryParse(_tempController.text),
          ),
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        title: const Text('حالة جديدة 🚑',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── بيانات المريض ──────────────────────────────────
            _sectionTitle('بيانات المريض (اختياري)'),
            const SizedBox(height: 12),
            _buildTextField(_nameController, 'الاسم', Icons.person),
            const SizedBox(height: 12),
            _buildTextField(
              _ageController,
              'العمر',
              Icons.cake,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v != null && v.isNotEmpty) {
                  final age = int.tryParse(v);
                  // ✅ FIX: التحقق يتطابق مع الـ API (0–150)
                  if (age == null || age < 0 || age > 150) {
                    return 'عمر غير صالح (0 - 150)';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── نوع الحالة ──────────────────────────────────────
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
                  onTap: () =>
                      setState(() => _caseType = type['value'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFE53935)
                          : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFE53935)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(type['icon'] as IconData,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          type['label'] as String,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── درجة الخطورة ────────────────────────────────────
            _sectionTitle('درجة الخطورة *'),
            const SizedBox(height: 12),
            Row(
              children: severities.map((s) {
                final selected = _severity == s['value'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _severity = s['value'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? (s['color'] as Color).withOpacity(0.2)
                            : const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? s['color'] as Color
                              : Colors.white12,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        s['label'] as String,
                        style: TextStyle(
                          color: selected
                              ? s['color'] as Color
                              : Colors.white54,
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

            // ── وصف الحالة ──────────────────────────────────────
            _sectionTitle('وصف الحالة'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                  'اكتب وصفاً مختصراً للحالة...', Icons.description),
              validator: (v) {
                if (v != null && v.length > 1000) {
                  return 'وصف الحالة طويل جدًا (الحد 1000 حرف)';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── الإشارات الحيوية ────────────────────────────────
            _sectionTitle('الإشارات الحيوية (اختياري)'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _buildTextField(
                  _heartRateController,
                  'BPM ضربات القلب',
                  Icons.monitor_heart,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final bpm = int.tryParse(v);
                      // ✅ FIX: نطاق منطقي للنبض (20–250 BPM)
                      if (bpm == null || bpm < 20 || bpm > 250) {
                        return 'نبض غير صالح (20-250)';
                      }
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  _spo2Controller,
                  'SpO2 الأكسجين %',
                  Icons.air,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final spo2 = int.tryParse(v);
                      // ✅ FIX: الـ API يقبل 0–100 لـ oxygen_saturation
                      if (spo2 == null || spo2 < 0 || spo2 > 100) {
                        return 'نسبة الأكسجين (0-100)';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _buildTextField(
                  _bpController,
                  'ضغط الدم',
                  Icons.speed,
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      // ✅ FIX: الـ API يتوقع صيغة "120/80" — التحقق يطابق ذلك
                      if (!RegExp(r'^\d{2,3}\/\d{2,3}$').hasMatch(v)) {
                        return 'الصيغة: 120/80';
                      }
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  _tempController,
                  'درجة الحرارة °C',
                  Icons.thermostat,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final temp = double.tryParse(v);
                      // ✅ FIX: نطاق منطقي لدرجة الحرارة (30–45)
                      if (temp == null || temp < 30 || temp > 45) {
                        return 'حرارة غير منطقية (30-45)';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ]),
            const SizedBox(height: 32),

            // ── زر المتابعة ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isLocating ? null : _proceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isLocating
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.navigate_next_rounded, size: 28),
                label: Text(
                  _isLocating ? 'جارٍ المعالجة...' : 'اختيار المستشفى',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
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
    child: Text(title,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold)),
  );

  Widget _buildTextField(
      TextEditingController c,
      String label,
      IconData icon, {
        TextInputType? keyboardType,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: const Color(0xFF161B22),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}