import 'dart:async';
import 'package:flutter/material.dart';
import '../models/ambulance_request.dart';
import '../services/api_service.dart';

class CaseSentScreen extends StatefulWidget {
  final String hospitalName;
  final String requestId;
  final String? hospitalPhone;

  const CaseSentScreen({
    super.key,
    required this.hospitalName,
    required this.requestId,
    this.hospitalPhone,
  });

  @override
  State<CaseSentScreen> createState() => _CaseSentScreenState();
}

class _CaseSentScreenState extends State<CaseSentScreen> {
  RequestStatus? _currentRequest;
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    // Poll every 3 seconds for quick responsiveness
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      final reqs = await ApiService.getMyRequests();
      final intId = int.tryParse(widget.requestId);
      if (intId != null) {
        RequestStatus? foundReq;
        for (final r in reqs) {
          if (r.id == intId) {
            foundReq = r;
            break;
          }
        }
        if (foundReq != null && mounted) {
          setState(() {
            _currentRequest = foundReq;
            _isLoading = false;
          });
          // Stop polling if request is completed or rejected
          if (foundReq.status == 'completed' || foundReq.status == 'rejected') {
            _timer?.cancel();
          }
        }
      }
    } catch (_) {
      // Fail silently for background updates, but ensure we mark not loading initially
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStatusWidget() {
    final status = _currentRequest?.status ?? 'pending';

    switch (status) {
      case 'accepted':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1B5E20).withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF43A047).withOpacity(0.4)),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'تم قبول الطلب! المستشفى جاهزة ✅',
                    style: TextStyle(
                        color: Color(0xFF81C784),
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.check_circle, color: Color(0xFF43A047), size: 20),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'تم تأكيد استقبال الحالة وتجهيز الكادر الطبي من قبل المستشفى.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.right,
              ),
              if (_currentRequest?.estimatedArrivalTime != null) ...[
                const SizedBox(height: 10),
                Text(
                  '⏱ وقت الوصول المتوقع: ${_currentRequest!.estimatedArrivalTime} دقيقة',
                  style: const TextStyle(
                      color: Color(0xFF80CBC4),
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  textAlign: TextAlign.right,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'رقم الطلب: #${widget.requestId}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        );

      case 'completed':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0D47A1).withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.4)),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'تم وصول الحالة - مكتمل 🏁',
                    style: TextStyle(
                        color: Color(0xFF90CAF9),
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.flag_rounded, color: Color(0xFF1976D2), size: 20),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'تم وصول الحالة بنجاح إلى المستشفى واكتمال الطلب.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 10),
              Text(
                'رقم الطلب: #${widget.requestId}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        );

      case 'rejected':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFB71C1C).withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE53935).withOpacity(0.4)),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'تم رفض الطلب من المستشفى ❌',
                    style: TextStyle(
                        color: Color(0xFFEF9A9A),
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.cancel, color: Color(0xFFE53935), size: 20),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'نعتذر، تم رفض استقبال الحالة من قبل المستشفى.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 10),
              Text(
                'رقم الطلب: #${widget.requestId}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        );

      default: // pending
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'في انتظار تأكيد المستشفى...',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 10),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE53935)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'رقم الطلب: #${widget.requestId}',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 10),
              const Text(
                'تابع حالة الطلب من تبويب "طلباتي" 📋',
                style: TextStyle(
                    color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: PopScope(
        canPop: false,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── أيقونة النجاح ──────────────────────────
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF43A047).withOpacity(0.15),
                      border:
                      Border.all(color: const Color(0xFF43A047), width: 3),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Color(0xFF43A047), size: 64),
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    'تم إرسال الحالة!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'تم إرسال الطلب إلى\n${widget.hospitalName}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                        height: 1.6),
                    textAlign: TextAlign.center,
                  ),

                  if (widget.hospitalPhone != null && widget.hospitalPhone!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.hospitalPhone!,
                          style: const TextStyle(
                              color: Color(0xFF80CBC4),
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.phone,
                            color: Color(0xFF80CBC4), size: 16),
                      ],
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── بانر انتظار التأكيد ─────────────────────
                  _buildStatusWidget(),

                  const SizedBox(height: 32),

                  // ── زر العودة ──────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('العودة للرئيسية',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}