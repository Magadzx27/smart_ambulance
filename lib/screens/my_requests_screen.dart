import 'package:flutter/material.dart';
import '../models/ambulance_request.dart';
import '../services/api_service.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});
  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  List<RequestStatus> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final reqs = await ApiService.getMyRequests();
      if (mounted) {
        setState(() {
          // ✅ FIX: ترتيب الطلبات — الأحدث أولاً (ترتيب تنازلي حسب الـ ID)
          reqs.sort((a, b) => b.id.compareTo(a.id));
          _requests = reqs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Color _statusColor(String status) {
    // ✅ FIX: القيم تطابق ما يعيده الـ API: pending / accepted / rejected / completed
    switch (status) {
      case 'accepted':
        return const Color(0xFF43A047);
      case 'completed':
        return const Color(0xFF1976D2);
      case 'rejected':
        return const Color(0xFFE53935);
      default: // pending
        return const Color(0xFFF9A825);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return '✅ مقبول - المستشفى جاهزة';
      case 'completed':
        return '🏁 تم الوصول - مكتمل';
      case 'rejected':
        return '❌ مرفوض';
      default:
        return '⏳ بانتظار الموافقة';
    }
  }

  Color _severityColor(String severity) {
    // ✅ FIX: القيم تطابق ما يعيده الـ API: high / medium / low
    switch (severity) {
      case 'high':
        return const Color(0xFFE53935);
      case 'medium':
        return const Color(0xFFF9A825);
      default: // low
        return const Color(0xFF43A047);
    }
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'high':
        return 'حرجة';
      case 'medium':
        return 'متوسطة';
      default:
        return 'خفيفة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        title: const Text('طلباتي',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadRequests),
        ],
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : _requests.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_rounded,
                color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text('لا توجد طلبات بعد',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 16)),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadRequests,
        color: const Color(0xFFE53935),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _requests.length,
          itemBuilder: (_, i) {
            final r = _requests[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withOpacity(0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ── الخطورة والعنوان ──────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _severityColor(r.severity)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _severityColor(r.severity)
                                  .withOpacity(0.4)),
                        ),
                        child: Text(
                          _severityLabel(r.severity),
                          style: TextStyle(
                              color: _severityColor(r.severity),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      Text(r.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),

                  // ── اسم المستشفى ──────────────
                  const SizedBox(height: 8),
                  Text('🏥 ${r.hospitalName}',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 14)),

                  // ✅ FIX: عرض phone المستشفى إن وُجد
                  if (r.hospitalPhone != null &&
                      r.hospitalPhone!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(r.hospitalPhone!,
                            style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12)),
                        const SizedBox(width: 4),
                        const Icon(Icons.phone,
                            color: Colors.white24, size: 13),
                      ],
                    ),
                  ],

                  // ── الحالة ───────────────────
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor(r.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(r.status),
                      style: TextStyle(
                          color: _statusColor(r.status),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),

                  // ✅ FIX: رسالة التأكيد تطابق نص الـ API docs
                  // "تم تأكيد استقبال الحالة وتجهيز الكادر الطبي"
                  if (r.isAccepted) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF43A047)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF43A047)
                                .withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'تم تأكيد استقبال الحالة وتجهيز الكادر الطبي من قبل المستشفى! ✅',
                            style: TextStyle(
                                color: Color(0xFF81C784),
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                          ),
                          if (r.acknowledgedAt != null) ...[
                            const SizedBox(height: 6),
                            // ✅ FIX: تنسيق أفضل لوقت التأكيد
                            Text(
                              'وقت التأكيد: ${_formatDate(r.acknowledgedAt!)}',
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (r.status == 'completed') ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF1976D2).withOpacity(0.3)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'تم وصول الحالة بنجاح إلى المستشفى! 🏁',
                            style: TextStyle(
                                color: Color(0xFF90CAF9),
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ✅ FIX: عرض وقت الوصول المتوقع إن وُجد
                  if (r.estimatedArrivalTime != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '⏱ وقت الوصول المتوقع: ${r.estimatedArrivalTime} دقيقة',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ✅ FIX: helper لتنسيق تاريخ التأكيد بشكل مقروء
  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}'
          ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}