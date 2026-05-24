import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/ambulance_request.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'case_sent_screen.dart';

class HospitalSelectionScreen extends StatefulWidget {
  final List<Hospital> hospitals;
  final AmbulanceRequest request;
  final double paramedicLat;
  final double paramedicLng;

  const HospitalSelectionScreen({
    super.key,
    required this.hospitals,
    required this.request,
    required this.paramedicLat,
    required this.paramedicLng,
  });

  @override
  State<HospitalSelectionScreen> createState() =>
      _HospitalSelectionScreenState();
}

class _HospitalSelectionScreenState extends State<HospitalSelectionScreen>
    with TickerProviderStateMixin {
  int? _selectedId;
  bool _isSending = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // ✅ الاختيار الافتراضي هو المستشفى الأول (الأنسب حسب الخوارزمية)
    if (widget.hospitals.isNotEmpty) {
      _selectedId = widget.hospitals.first.id;
    }
  }

  // ── حساب حدود الخريطة لتشمل جميع النقاط ──────────────────
  LatLngBounds _calculateBounds() {
    final points = <LatLng>[
      LatLng(widget.paramedicLat, widget.paramedicLng),
      ...widget.hospitals.map((h) => LatLng(h.lat, h.lng)),
    ];

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // إضافة padding للحدود
    const pad = 0.01;
    return LatLngBounds(
      LatLng(minLat - pad, minLng - pad),
      LatLng(maxLat + pad, maxLng + pad),
    );
  }

  // ── تحريك الخريطة نحو مستشفى محدد ──────────────────────────
  void _animateToHospital(Hospital hospital) {
    _mapController.move(
      LatLng(hospital.lat, hospital.lng),
      14.0,
    );
  }

  Future<void> _sendCase() async {
    if (_selectedId == null) return;
    setState(() => _isSending = true);

    try {
      final selectedHospital =
          widget.hospitals.firstWhere((h) => h.id == _selectedId);

      // إعادة تحديث موقع المسعف قبل الإرسال
      try {
        await ApiService.updateLocation(
            widget.paramedicLat, widget.paramedicLng);
      } catch (_) {
        try {
          final pos = await LocationService.getCurrentPosition();
          if (pos != null) {
            await ApiService.updateLocation(pos.latitude, pos.longitude);
          }
        } catch (_) {}
      }

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
        estimatedArrivalTime: selectedHospital.estimatedDrivingTimeMins,
      );

      final response = await ApiService.sendRequest(finalRequest);
      if (!mounted) return;

      final requestId =
          response['request']?['id']?.toString() ?? '---';

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => CaseSentScreen(
            hospitalName: selectedHospital.name,
            requestId: requestId,
            hospitalPhone: selectedHospital.phone,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Color _getOccupancyColor(String load) {
    switch (load) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  // ── بناء markers المستشفيات ─────────────────────────────────
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Marker موقع المسعف
    markers.add(
      Marker(
        point: LatLng(widget.paramedicLat, widget.paramedicLng),
        width: 50,
        height: 50,
        child: const _PulsingDot(),
      ),
    );

    // Markers المستشفيات
    for (int i = 0; i < widget.hospitals.length; i++) {
      final h = widget.hospitals[i];
      final isSelected = _selectedId == h.id;
      final isBest = i == 0;

      markers.add(
        Marker(
          point: LatLng(h.lat, h.lng),
          width: isSelected ? 180 : 160,
          height: isSelected ? 75 : 65,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedId = h.id);
              _animateToHospital(h);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE53935)
                        : isBest
                            ? const Color(0xFF00897B)
                            : const Color(0xFF1E1E2E).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected || isBest ? Colors.transparent : Colors.white24,
                      width: 1,
                    ),
                    boxShadow: [
                      if (isSelected || isBest)
                        BoxShadow(
                          color: isSelected
                              ? const Color(0xFFE53935).withValues(alpha: 0.5)
                              : const Color(0xFF00897B).withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: Text(
                    isBest ? '⭐ ${h.name}' : h.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Icon(
                  Icons.location_on,
                  color: isSelected
                      ? const Color(0xFFE53935)
                      : isBest
                          ? const Color(0xFF00897B)
                          : Colors.white70,
                  size: isSelected ? 36 : 28,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: const Color(0xFF161B22).withValues(alpha: 0.8),
            child: const BackButton(color: Colors.white),
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── 1. الخريطة (Full Screen) ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: _calculateBounds(),
                // padding لحساب المساحة السفلية (للبطاقة أو القائمة)
                padding: const EdgeInsets.only(top: 150, bottom: 350, left: 40, right: 40),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (_, __) => setState(() => _selectedId = null),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.smartambulance.app',
              ),
              if (_selectedId != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        LatLng(widget.paramedicLat, widget.paramedicLng),
                        LatLng(
                          widget.hospitals
                              .firstWhere((h) => h.id == _selectedId)
                              .lat,
                          widget.hospitals
                              .firstWhere((h) => h.id == _selectedId)
                              .lng,
                        ),
                      ],
                      color: const Color(0xFFE53935).withValues(alpha: 0.6),
                      strokeWidth: 2.5,
                      pattern: const StrokePattern.dotted(),
                    ),
                  ],
                ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // ── 2. البانر الذكي العائم ──
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 10,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00897B).withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF00897B), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'المستشفيات مرتبة آلياً حسب الازدحام ومسافة الطريق للحالة',
                      style: TextStyle(
                        color: Color(0xFF80CBC4),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. أزرار التحكم بالخريطة (يمين) ──
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 90,
            right: 16,
            child: Column(
              children: [
                _buildMapBtn(
                  icon: Icons.my_location,
                  onTap: () {
                    _mapController.move(
                        LatLng(widget.paramedicLat, widget.paramedicLng), 15);
                  },
                ),
                const SizedBox(height: 12),
                _buildMapBtn(
                  icon: Icons.fit_screen_rounded,
                  onTap: () {
                    _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: _calculateBounds(),
                        padding: const EdgeInsets.only(
                            top: 150, bottom: 350, left: 40, right: 40),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── 4. البطاقة العائمة أو قائمة المستشفيات ──
          if (_selectedId != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _buildSelectedHospitalCard(),
            )
          else
            DraggableScrollableSheet(
              initialChildSize: 0.35,
              minChildSize: 0.15,
              maxChildSize: 0.65,
              builder: (context, scrollController) =>
                  _buildHospitalListSheet(scrollController),
            ),
        ],
      ),
    );
  }

  // ── زر تحكم الخريطة ──
  Widget _buildMapBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF161B22).withValues(alpha: 0.95),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  // ── بناء بطاقة المستشفى المحدد (التي تحتوي زر الإرسال) ──
  Widget _buildSelectedHospitalCard() {
    final h = widget.hospitals.firstWhere((e) => e.id == _selectedId);
    final occColor = _getOccupancyColor(h.occupancyLoad);
    final isBest = widget.hospitals.first.id == h.id;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // الهيدر مع زر الإغلاق
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedId = null),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white54, size: 18),
                ),
              ),
              const Spacer(),
              if (isBest)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'الأنسب ✓',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              Flexible(
                child: Text(
                  h.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_hospital,
                    color: Color(0xFFE53935), size: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // معلومات المستشفى (مسافة + ازدحام)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildInfoPill(
                icon: Icons.directions_car,
                text: '${h.drivingDistance.toStringAsFixed(1)} كم | ~${h.estimatedDrivingTimeMins} د',
                color: Colors.white70,
                bgColor: Colors.white10,
              ),
              const SizedBox(width: 8),
              _buildInfoPill(
                icon: Icons.group,
                text: h.occupancyLoadAr.isNotEmpty ? h.occupancyLoadAr : h.occupancyLoad,
                color: occColor,
                bgColor: occColor.withValues(alpha: 0.15),
              ),
            ],
          ),
          if (h.treatments != null && h.treatments!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              h.treatments!,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 11, height: 1.4),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),

          // زر الإرسال
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendCase,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 22),
              label: Text(
                _isSending ? 'جارٍ الإرسال...' : 'إرسال الحالة فوراً 🚨',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String text,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: color),
        ],
      ),
    );
  }

  // ── بناء قائمة المستشفيات (Bottom Sheet) ──
  Widget _buildHospitalListSheet(ScrollController scrollController) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // مقبض السحب (Handle)
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          // عنوان القائمة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.hospitals.length}',
                    style: const TextStyle(
                      color: Color(0xFF80CBC4),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'المستشفيات المتاحة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          // القائمة
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: widget.hospitals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final h = widget.hospitals[i];
                final occColor = _getOccupancyColor(h.occupancyLoad);
                final isBest = i == 0;

                return InkWell(
                  onTap: () {
                    setState(() => _selectedId = h.id);
                    _animateToHospital(h);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        // أيقونة الحالة
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: occColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.local_hospital,
                                  color: occColor, size: 20),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              h.occupancyLoadAr.isNotEmpty
                                  ? h.occupancyLoadAr
                                  : h.occupancyLoad,
                              style: TextStyle(
                                  color: occColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // التفاصيل
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (isBest)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00897B),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text('الأنسب',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      h.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${h.drivingDistance.toStringAsFixed(1)} كم | ~${h.estimatedDrivingTimeMins} دقيقة',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.directions_car,
                                      color: Colors.white38, size: 14),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ── نقطة نابضة (موقع المسعف) ────────────────────────────────
// ══════════════════════════════════════════════════════════════
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacityAnim = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // الحلقة النابضة
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.scale(
            scale: _scaleAnim.value,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF42A5F5)
                    .withValues(alpha: _opacityAnim.value * 0.4),
                border: Border.all(
                  color: const Color(0xFF42A5F5)
                      .withValues(alpha: _opacityAnim.value),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        // النقطة الثابتة
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF1E88E5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E88E5).withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── AnimatedBuilder replacement (Flutter compat) ──────────────
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}