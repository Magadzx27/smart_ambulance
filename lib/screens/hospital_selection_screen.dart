import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/ambulance_request.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'case_sent_screen.dart';

// ── ثوابت الألوان والتصميم ─────────────────────────────────────
class _AppColors {
  static const background    = Color(0xFF0A0E1A);
  static const surface       = Color(0xFF121826);
  static const surfaceCard   = Color(0xFF1A2233);
  static const surfaceBorder = Color(0xFF243048);

  static const primary       = Color(0xFFE53935);
  static const primaryGlow   = Color(0x33E53935);
  static const teal          = Color(0xFF00BFA5);
  static const tealGlow      = Color(0x2200BFA5);
  static const blue          = Color(0xFF2196F3);
  static const blueGlow      = Color(0x332196F3);

  static const textPrimary   = Colors.white;
  static const textSecondary = Color(0xFFB0BEC5);
  static const textMuted     = Color(0xFF607D8B);

  static const routeLine     = Color(0xFFFF5252);
}

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
  late AnimationController _cardAnimCtrl;
  late Animation<Offset> _cardSlide;
  late Animation<double>  _cardFade;

  @override
  void initState() {
    super.initState();
    if (widget.hospitals.isNotEmpty) {
      _selectedId = widget.hospitals.first.id;
    }

    _cardAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardAnimCtrl, curve: Curves.easeOutCubic));
    _cardFade = CurvedAnimation(parent: _cardAnimCtrl, curve: Curves.easeOut);

    if (_selectedId != null) _cardAnimCtrl.forward();
  }

  @override
  void dispose() {
    _cardAnimCtrl.dispose();
    super.dispose();
  }

  LatLngBounds _calculateBounds() {
    final points = <LatLng>[
      LatLng(widget.paramedicLat, widget.paramedicLng),
      ...widget.hospitals.map((h) => LatLng(h.lat, h.lng)),
    ];
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    const pad = 0.012;
    return LatLngBounds(
      LatLng(minLat - pad, minLng - pad),
      LatLng(maxLat + pad, maxLng + pad),
    );
  }

  void _animateToHospital(Hospital h) =>
      _mapController.move(LatLng(h.lat, h.lng), 14.5);

  void _selectHospital(int id) {
    setState(() => _selectedId = id);
    _cardAnimCtrl.forward(from: 0);
  }

  Future<void> _sendCase() async {
    if (_selectedId == null) return;
    setState(() => _isSending = true);
    try {
      final selectedHospital =
      widget.hospitals.firstWhere((h) => h.id == _selectedId);
      try {
        await ApiService.updateLocation(
            widget.paramedicLat, widget.paramedicLng);
      } catch (_) {
        try {
          final pos = await LocationService.getCurrentPosition();
          if (pos != null)
            await ApiService.updateLocation(pos.latitude, pos.longitude);
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
      final requestId = response['request']?['id']?.toString() ?? '---';
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
        backgroundColor: _AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }

  Color _getOccupancyColor(String load) {
    switch (load) {
      case 'high':   return Colors.redAccent;
      case 'low':    return _AppColors.teal;
      default:       return Colors.orangeAccent;
    }
  }

  List<Polyline> _buildRoute() {
    if (_selectedId == null) return [];
    final h = widget.hospitals.firstWhere((h) => h.id == _selectedId);
    final start = LatLng(widget.paramedicLat, widget.paramedicLng);
    final end   = LatLng(h.lat, h.lng);

    final midLat = (start.latitude  + end.latitude)  / 2;
    final midLng = (start.longitude + end.longitude) / 2;
    final dLat   = end.latitude  - start.latitude;
    final dLng   = end.longitude - start.longitude;
    final len    = math.sqrt(dLat * dLat + dLng * dLng);
    final offset = len * 0.15;

    final ctrlLat = midLat - (dLng / len) * offset;
    final ctrlLng = midLng + (dLat / len) * offset;

    final curve = <LatLng>[];
    for (int i = 0; i <= 30; i++) {
      final t = i / 30.0;
      final lat = (1 - t) * (1 - t) * start.latitude  +
          2 * (1 - t) * t * ctrlLat +
          t * t * end.latitude;
      final lng = (1 - t) * (1 - t) * start.longitude +
          2 * (1 - t) * t * ctrlLng +
          t * t * end.longitude;
      curve.add(LatLng(lat, lng));
    }

    return [
      Polyline(
        points: curve,
        color: _AppColors.routeLine.withValues(alpha: 0.18),
        strokeWidth: 10,
      ),
      Polyline(
        points: curve,
        color: _AppColors.routeLine.withValues(alpha: 0.9),
        strokeWidth: 3.5,
      ),
      Polyline(
        points: curve,
        color: Colors.white.withValues(alpha: 0.25),
        strokeWidth: 1.5,
        pattern: StrokePattern.dashed(segments: [10, 8]),
      ),
    ];
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    markers.add(Marker(
      point: LatLng(widget.paramedicLat, widget.paramedicLng),
      width: 56, height: 56,
      child: const _PulsingDot(),
    ));

    for (int i = 0; i < widget.hospitals.length; i++) {
      final h = widget.hospitals[i];
      final isSelected = _selectedId == h.id;
      final isBest     = i == 0;

      markers.add(Marker(
        point: LatLng(h.lat, h.lng),
        width: isSelected ? 190 : 170,
        height: isSelected ? 82 : 70,
        child: GestureDetector(
          onTap: () {
            _selectHospital(h.id);
            _animateToHospital(h);
          },
          child: _HospitalMarker(
            name: h.name,
            isSelected: isSelected,
            isBest: isBest,
          ),
        ),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _AppColors.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: _calculateBounds(),
                padding: EdgeInsets.only(
                  top: topPad + kToolbarHeight + 100,
                  bottom: 360,
                  left: 40,
                  right: 40,
                ),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (_, __) {
                setState(() => _selectedId = null);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.smartambulance.app',
              ),
              PolylineLayer(polylines: _buildRoute()),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // تدرج علوي
          Positioned(
            top: 0, left: 0, right: 0,
            height: topPad + kToolbarHeight + 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _AppColors.background.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // AppBar مخصص
          Positioned(
            top: topPad + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _GlassButton(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: _InfoBanner(count: widget.hospitals.length)),
              ],
            ),
          ),

          // أزرار التحكم بالخريطة
          Positioned(
            bottom: _selectedId != null ? 220 : 300,
            right: 16,
            child: Column(
              children: [
                _GlassButton(
                  onTap: () => _mapController.move(
                      LatLng(widget.paramedicLat, widget.paramedicLng), 15),
                  tooltip: 'موقعي',
                  child: const Icon(Icons.my_location_rounded,
                      color: _AppColors.blue, size: 20),
                ),
                const SizedBox(height: 10),
                _GlassButton(
                  onTap: () => _mapController.fitCamera(CameraFit.bounds(
                    bounds: _calculateBounds(),
                    padding: const EdgeInsets.only(
                        top: 150, bottom: 350, left: 40, right: 40),
                  )),
                  tooltip: 'عرض الكل',
                  child: const Icon(Icons.fit_screen_rounded,
                      color: _AppColors.textSecondary, size: 20),
                ),
              ],
            ),
          ),

          // البطاقة أو القائمة
          if (_selectedId != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SlideTransition(
                position: _cardSlide,
                child: FadeTransition(
                  opacity: _cardFade,
                  child: _buildSelectedHospitalCard(),
                ),
              ),
            )
          else
            DraggableScrollableSheet(
              initialChildSize: 0.38,
              minChildSize: 0.16,
              maxChildSize: 0.68,
              builder: (_, ctrl) => _buildHospitalListSheet(ctrl),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedHospitalCard() {
    final h = widget.hospitals.firstWhere((e) => e.id == _selectedId);
    final occColor = _getOccupancyColor(h.occupancyLoad);
    final isBest   = widget.hospitals.first.id == h.id;

    return Container(
      decoration: const BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [occColor.withValues(alpha: 0.0), occColor, occColor.withValues(alpha: 0.0)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _selectedId = null),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close, color: Colors.white54, size: 16),
                      ),
                    ),
                    const Spacer(),
                    if (isBest)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _AppColors.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _AppColors.teal.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.verified_rounded,
                                color: _AppColors.teal, size: 13),
                            SizedBox(width: 4),
                            Text('الأنسب',
                                style: TextStyle(
                                    color: _AppColors.teal,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        h.name,
                        style: const TextStyle(
                            color: _AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.local_hospital_rounded,
                          color: _AppColors.primary, size: 20),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _InfoPill(
                      icon: Icons.directions_car_rounded,
                      text: '${h.drivingDistance.toStringAsFixed(1)} كم  •  ~${h.estimatedDrivingTimeMins} د',
                      color: Colors.white70,
                      bg: Colors.white.withValues(alpha: 0.07),
                    ),
                    const SizedBox(width: 8),
                    _InfoPill(
                      icon: Icons.group_rounded,
                      text: h.occupancyLoadAr.isNotEmpty
                          ? h.occupancyLoadAr
                          : h.occupancyLoad,
                      color: occColor,
                      bg: occColor.withValues(alpha: 0.12),
                      borderColor: occColor.withValues(alpha: 0.3),
                    ),
                  ],
                ),

                if (h.treatments != null && h.treatments!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    h.treatments!,
                    style: const TextStyle(
                        color: _AppColors.textMuted,
                        fontSize: 12,
                        height: 1.5),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _sendCase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AppColors.primary,
                      disabledBackgroundColor:
                      _AppColors.primary.withValues(alpha: 0.5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child: _isSending
                        ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('جارٍ الإرسال...',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                      ],
                    )
                        : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('إرسال الحالة الآن',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.send_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalListSheet(ScrollController scrollController) {
    return Container(
      decoration: const BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 0),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _AppColors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _AppColors.teal.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${widget.hospitals.length}',
                    style: const TextStyle(
                        color: _AppColors.teal,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                const Text(
                  'المستشفيات المتاحة',
                  style: TextStyle(
                      color: _AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: widget.hospitals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _buildHospitalTile(i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalTile(int i) {
    final h = widget.hospitals[i];
    final occColor = _getOccupancyColor(h.occupancyLoad);
    final isBest   = i == 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _selectHospital(h.id);
          _animateToHospital(h);
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isBest
                  ? _AppColors.teal.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: occColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: occColor.withValues(alpha: 0.25)),
                    ),
                    child: Icon(Icons.local_hospital_rounded, color: occColor, size: 20),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    h.occupancyLoadAr.isNotEmpty ? h.occupancyLoadAr : h.occupancyLoad,
                    style: TextStyle(
                        color: occColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isBest) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _AppColors.teal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: _AppColors.teal.withValues(alpha: 0.3)),
                            ),
                            child: const Text('الأنسب',
                                style: TextStyle(
                                    color: _AppColors.teal,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            h.name,
                            style: const TextStyle(
                                color: _AppColors.textPrimary,
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
                          '${h.drivingDistance.toStringAsFixed(1)} كم  •  ~${h.estimatedDrivingTimeMins} دقيقة',
                          style: const TextStyle(
                              color: _AppColors.textMuted, fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.directions_car_rounded,
                            color: _AppColors.textMuted, size: 13),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_back_ios_rounded, color: Colors.white24, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ── Marker المستشفى
// ══════════════════════════════════════════════════════════════
class _HospitalMarker extends StatelessWidget {
  final String name;
  final bool isSelected;
  final bool isBest;

  const _HospitalMarker({
    required this.name,
    required this.isSelected,
    required this.isBest,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? _AppColors.primary
        : isBest
        ? _AppColors.teal
        : const Color(0xFF1E2A3D);

    final glowColor = isSelected
        ? _AppColors.primaryGlow
        : isBest
        ? _AppColors.tealGlow
        : Colors.transparent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected || isBest ? Colors.transparent : Colors.white24,
            ),
            boxShadow: [
              if (isSelected || isBest)
                BoxShadow(color: glowColor, blurRadius: 12, spreadRadius: 2),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBest)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                ),
              Flexible(
                child: Text(
                  name,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          child: Icon(
            Icons.location_on_rounded,
            color: isSelected
                ? _AppColors.primary
                : isBest
                ? _AppColors.teal
                : Colors.white60,
            size: isSelected ? 36 : 28,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ── Glass Button
// ══════════════════════════════════════════════════════════════
class _GlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final String? tooltip;

  const _GlassButton({required this.onTap, required this.child, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _AppColors.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: _AppColors.surfaceBorder),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: child,
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

// ══════════════════════════════════════════════════════════════
// ── Info Banner
// ══════════════════════════════════════════════════════════════
class _InfoBanner extends StatelessWidget {
  final int count;
  const _InfoBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AppColors.teal.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: const [
          SizedBox(width: 4),
          Icon(Icons.auto_awesome_rounded, color: _AppColors.teal, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'مرتبة آلياً حسب الازدحام ومسافة الطريق',
              style: TextStyle(
                  color: Color(0xFF80CBC4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ── Info Pill
// ══════════════════════════════════════════════════════════════
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color bg;
  final Color? borderColor;

  const _InfoPill({
    required this.icon,
    required this.text,
    required this.color,
    required this.bg,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: color),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ── نقطة نابضة (موقع المسعف)
// ══════════════════════════════════════════════════════════════
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _scale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.7, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _AppColors.blue.withValues(alpha: _opacity.value * 0.3),
                border: Border.all(
                  color: _AppColors.blue.withValues(alpha: _opacity.value),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: _AppColors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: _AppColors.blue.withValues(alpha: 0.6),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── AnimatedBuilder
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) => builder(context, null);
}