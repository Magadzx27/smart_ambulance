import 'package:flutter/material.dart';

class CaseSentScreen extends StatelessWidget {
  final String hospitalName;
  final String requestId;

  const CaseSentScreen({super.key, required this.hospitalName, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success animation circle
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF43A047).withOpacity(0.15),
                    border: Border.all(color: const Color(0xFF43A047), width: 3),
                  ),
                  child: const Icon(Icons.check_rounded, color: Color(0xFF43A047), size: 64),
                ),
                const SizedBox(height: 28),
                const Text(
                  'تم إرسال الحالة!',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'تم إرسال الطلب إلى\n$hospitalName',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // Awaiting confirmation box
                Container(
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
                          Text('في انتظار تأكيد المستشفى...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          SizedBox(width: 10),
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE53935))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('رقم الطلب: #$requestId', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('العودة للرئيسية', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}