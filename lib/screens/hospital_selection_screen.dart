import 'package:flutter/material.dart';
import '../models/ambulance_request.dart';
import '../services/api_service.dart';
import 'case_sent_screen.dart';

class HospitalSelectionScreen extends StatefulWidget {
  final List<Hospital> hospitals;
  final AmbulanceRequest request;

  const HospitalSelectionScreen({
    super.key,
    required this.hospitals,
    required this.request,
  });

  @override
  State<HospitalSelectionScreen> createState() => _HospitalSelectionScreenState();
}

class _HospitalSelectionScreenState extends State<HospitalSelectionScreen> {
  int? _selectedId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.hospitals.isNotEmpty) {
      _selectedId = widget.hospitals.first.id;
    }
  }

  Future<void> _sendCase() async {
    if (_selectedId == null) return;
    setState(() => _isSending = true);

    try {
      final finalRequest = AmbulanceRequest(
        title: widget.request.title,
        severity: widget.request.severity,
        hospitalId: _selectedId!,
        patientName: widget.request.patientName,
        patientAge: widget.request.patientAge,
        caseClassification: widget.request.caseClassification,
        description: widget.request.description,
        heartRate: widget.request.heartRate,
        oxygenSaturation: widget.request.oxygenSaturation,
        bloodPressure: widget.request.bloodPressure,
        bodyTemperature: widget.request.bodyTemperature,
        estimatedArrivalTime: widget.hospitals.firstWhere((h) => h.id == _selectedId).estimatedDrivingTimeMins,
      );
      
      final response = await ApiService.sendRequest(finalRequest);
      if (!mounted) return;
      
      final selectedHospital = widget.hospitals.firstWhere((h) => h.id == _selectedId);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => CaseSentScreen(
          hospitalName: selectedHospital.name,
          requestId: response['request']?['id']?.toString() ?? '---',
        )),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString(), style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red),
      );
    }
  }

  Color _getOccupancyColor(String load) {
    if (load == 'high') return Colors.red;
    if (load == 'low') return Colors.green;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        title: const Text('اختيار المستشفى 🏥', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Smart selection banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00897B).withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF00897B), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تم اختيار المستشفيات تلقائياً بناءً على الموقع ونوع الحالة',
                    style: TextStyle(color: Color(0xFF80CBC4), fontSize: 13),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: widget.hospitals.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, color: Colors.white24, size: 60),
                  SizedBox(height: 16),
                  Text('لا توجد مستشفيات متاحة', style: TextStyle(color: Colors.white38, fontSize: 16)),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.hospitals.length,
              itemBuilder: (_, i) {
                final h = widget.hospitals[i];
                final isSelected = _selectedId == h.id;
                final isBest = i == 0;
                final occColor = _getOccupancyColor(h.occupancyLoad);

                return GestureDetector(
                  onTap: () => setState(() => _selectedId = h.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE53935).withOpacity(0.1)
                          : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFE53935) : Colors.white12,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Radio<int>(
                              value: h.id,
                              groupValue: _selectedId,
                              onChanged: (v) => setState(() => _selectedId = v),
                              activeColor: const Color(0xFFE53935),
                            ),
                            const Spacer(),
                            if (isBest) Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00897B),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('الأنسب ✓', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Text(h.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            const Icon(Icons.local_hospital, color: Color(0xFFE53935), size: 22),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${h.drivingDistance.toStringAsFixed(1)} كم | ~${h.estimatedDrivingTimeMins} دقيقة',
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.directions_car, color: Colors.white38, size: 16),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: occColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: occColor.withOpacity(0.4)),
                              ),
                              child: Text(
                                h.occupancyLoadAr.isNotEmpty ? h.occupancyLoadAr : h.occupancyLoad,
                                style: TextStyle(color: occColor, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'حالات نشطة: ${h.activeCasesCount} | التوافق: ${h.matchScore}',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                        if (h.treatments != null && h.treatments!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 6),
                          Text(
                            h.treatments!,
                            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Send Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: (_selectedId == null || _isSending) ? null : _sendCase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isSending
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 26),
                label: Text(
                  _isSending ? 'جارٍ الإرسال...' : 'إرسال الحالة فوراً 🚨',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}