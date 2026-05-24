import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/ambulance_request.dart';
import '../services/api_service.dart';
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

    // ── Marker موقع المسعف (أزرق) ──
    markers.add(
      Marker(
        point: LatLng(widget.paramedicLat, widget.paramedicLng),
        width: 50,
        height: 50,
        child: const _PulsingDot(),
      ),
    );

    // ── Markers المستشفيات ──
    for (int i = 0; i < widget.hospitals.length; i++) {
      final h = widget.hospitals[i];
      final isSelected = _selectedId == h.id;
      final isBest = i == 0;

      markers.add(
        Marker(
          point: LatLng(h.lat, h.lng),
          width: 160,
          height: 65,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedId = h.id);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // اسم المستشفى فوق الـ marker
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE53935)
                        : isBest
                            ? const Color(0xFF00897B)
                            : const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    isBest ? '⭐ ${h.name}' : h.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                // أيقونة الـ pin
                Icon(
                  Icons.location_on,
                  color: isSelected
                      ? const Color(0xFFE53935)
                      : isBest
                          ? const Color(0xFF00897B)
                          : Colors.white70,
                  size: isSelected ? 32 : 26,
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        title: const Text('اختيار المستشفى 🏥',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ══════════════════════════════════════════════════════
          // ── الخريطة التفاعلية ──────────────────────────────
          // ══════════════════════════════════════════════════════
          Container(
            height: MediaQuery.of(context).size.height * 0.32,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFE53935).withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: _calculateBounds(),
                      padding: const EdgeInsets.all(40),
                    ),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    // ── طبقة الخريطة (Dark theme) ──
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.smartambulance.app',
                    ),
                    // ── خط بين المسعف والمستشفى المختار ──
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
                            color:
                                const Color(0xFFE53935).withOpacity(0.6),
                            strokeWidth: 2.5,
                            pattern: const StrokePattern.dotted(),
                          ),
                        ],
                      ),
                    // ── Markers ──
                    MarkerLayer(markers: _buildMarkers()),
                  ],
                ),

                // ── بادج "موقعي" ──
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('موقعي',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(Icons.my_location, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),

                // ── زر إعادة التوسيط ──
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () {
                      _mapController.fitCamera(
                        CameraFit.bounds(
                          bounds: _calculateBounds(),
                          padding: const EdgeInsets.all(40),
                        ),
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.fit_screen_rounded,
                          color: Colors.white70, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── بانر الاختيار الذكي ─────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF00897B).withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF00897B), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'رُتِّبت المستشفيات تلقائياً حسب الموقع والازدحام ونوع الحالة',
                    style: TextStyle(color: Color(0xFF80CBC4), fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // ══════════════════════════════════════════════════════
          // ── قائمة المستشفيات ────────────────────────────────
          // ══════════════════════════════════════════════════════
          Expanded(
            child: widget.hospitals.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, color: Colors.white24, size: 60),
                        SizedBox(height: 16),
                        Text('لا توجد مستشفيات متاحة',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: widget.hospitals.length,
                    itemBuilder: (_, i) {
                      final h = widget.hospitals[i];
                      final isSelected = _selectedId == h.id;
                      final isBest = i == 0;
                      final occColor = _getOccupancyColor(h.occupancyLoad);

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedId = h.id);
                          _animateToHospital(h);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFE53935).withOpacity(0.1)
                                : const Color(0xFF161B22),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFE53935)
                                  : Colors.white12,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // ── اسم المستشفى ──────────────
                              Row(
                                children: [
                                  Radio<int>(
                                    value: h.id,
                                    groupValue: _selectedId,
                                    onChanged: (v) {
                                      setState(() => _selectedId = v);
                                      _animateToHospital(h);
                                    },
                                    activeColor: const Color(0xFFE53935),
                                  ),
                                  const Spacer(),
                                  if (isBest)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00897B),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: const Text('الأنسب ✓',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(h.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.local_hospital,
                                      color: Color(0xFFE53935), size: 20),
                                ],
                              ),

                              // ── المسافة والوقت ────────────
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
                                      color: Colors.white38, size: 15),
                                ],
                              ),

                              // ── الازدحام والتوافق ──────────
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: occColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: occColor.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      h.occupancyLoadAr.isNotEmpty
                                          ? h.occupancyLoadAr
                                          : h.occupancyLoad,
                                      style: TextStyle(
                                          color: occColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'حالات: ${h.activeCasesCount} | التوافق: ${h.matchScore}',
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 11),
                                  ),
                                ],
                              ),

                              // ── التخصصات ──────────────────
                              if (h.treatments != null &&
                                  h.treatments!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Divider(color: Colors.white12),
                                const SizedBox(height: 4),
                                Text(
                                  h.treatments!,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      height: 1.4),
                                  textAlign: TextAlign.right,
                                ),
                              ],

                              // ── هاتف المستشفى ──────────────
                              if (h.phone != null &&
                                  h.phone!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(h.phone!,
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.phone,
                                        color: Colors.white38, size: 13),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ── زر الإرسال ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed:
                    (_selectedId == null || _isSending) ? null : _sendCase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isSending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 24),
                label: Text(
                  _isSending ? 'جارٍ الإرسال...' : 'إرسال الحالة فوراً 🚨',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
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
                    .withOpacity(_opacityAnim.value * 0.4),
                border: Border.all(
                  color: const Color(0xFF42A5F5)
                      .withOpacity(_opacityAnim.value),
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
                color: const Color(0xFF1E88E5).withOpacity(0.5),
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