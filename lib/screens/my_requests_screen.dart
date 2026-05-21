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
          _requests = reqs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString(), style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted': return const Color(0xFF43A047);
      case 'rejected': return const Color(0xFFE53935);
      default: return const Color(0xFFF9A825);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted': return '✅ مقبول - المستشفى جاهزة';
      case 'rejected': return '❌ مرفوض';
      default: return '⏳ بانتظار الموافقة';
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'high': return const Color(0xFFE53935);
      case 'medium': return const Color(0xFFF9A825);
      default: return const Color(0xFF43A047);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        title: const Text('طلباتي', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRequests),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : _requests.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text('لا توجد طلبات بعد', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
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
            final isAccepted = r.status == 'accepted';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _severityColor(r.severity).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _severityColor(r.severity).withOpacity(0.4)),
                        ),
                        child: Text(
                          r.severity == 'high' ? 'حرجة' : r.severity == 'medium' ? 'متوسطة' : 'خفيفة',
                          style: TextStyle(color: _severityColor(r.severity), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      Text(r.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('🏥 ${r.hospitalName}', style: const TextStyle(color: Colors.white60, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor(r.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(r.status),
                      style: TextStyle(color: _statusColor(r.status), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (isAccepted) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF43A047).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF43A047).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'تم تأكيد استقبال الحالة وتجهيز الكادر الطبي من قبل المستشفى! ✅',
                            style: TextStyle(color: Color(0xFF81C784), fontSize: 13, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                          ),
                          if (r.acknowledgedAt != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'وقت التأكيد: ${r.acknowledgedAt}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
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
}