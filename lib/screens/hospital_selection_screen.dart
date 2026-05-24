import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../models/ambulance_request.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'case_sent_screen.dart';

// ── ألوان التطبيق ──────────────────────────────────────────────
class _C {
  static const bg           = Color(0xFF080D17);
  static const surface      = Color(0xFF101623);
  static const card         = Color(0xFF161E2E);
  static const border       = Color(0xFF1E2D45);
  static const primary      = Color(0xFFE53935);
  static const teal         = Color(0xFF00BFA5);
  static const blue         = Color(0xFF1E88E5);
  static const white        = Colors.white;
  static const textSub      = Color(0xFF90A4AE);
  static const textFaint    = Color(0xFF546E7A);
}

// ══════════════════════════════════════════════════════════════
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
  bool _isLoadingRoute = false;

  List<LatLng> _routePoints = [];
  double? _routeDistanceKm;
  int?    _routeDurationMin;

  final MapController _mapController = MapController();
  late AnimationController _cardCtrl;
  late Animation<Offset>   _cardSlide;
  late Animation<double>   _cardFade;

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));
    _cardFade = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);

    if (widget.hospitals.isNotEmpty) {
      _selectHospital(widget.hospitals.first.id, animate: false);
    }
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    super.dispose();
  }

  // ── اختيار مستشفى + جلب المسار الحقيقي ──────────────────────
  Future<void> _selectHospital(int id, {bool animate = true}) async {
    final h = widget.hospitals.firstWhere((x) => x.id == id);
    setState(() {
      _selectedId = id;
      _isLoadingRoute = true;
      _routePoints = [];
      _routeDistanceKm = null;
      _routeDurationMin = null;
    });

    if (animate) {
      _cardCtrl.forward(from: 0);
      _mapController.move(LatLng(h.lat, h.lng), 14.0);
    }

    try {
      final route = await _fetchOSRMRoute(
        LatLng(widget.paramedicLat, widget.paramedicLng),
        LatLng(h.lat, h.lng),
      );
      if (mounted && _selectedId == id) {
        setState(() {
          _routePoints      = route.points;
          _routeDistanceKm  = route.distanceKm;
          _routeDurationMin = route.durationMin;
          _isLoadingRoute   = false;
        });
        // ملاءمة الخريطة للمسار
        if (route.points.isNotEmpty) {
          _fitRouteBounds(route.points);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  // ── OSRM: جلب المسار الحقيقي على الطرق ──────────────────────
  Future<_RouteResult> _fetchOSRMRoute(LatLng from, LatLng to) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
          '\${from.longitude},\${from.latitude};\${to.longitude},\${to.latitude}'
          '?overview=full&geometries=geojson&steps=false',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('OSRM error');

    final data = json.decode(response.body);
    if (data['code'] != 'Ok') throw Exception('No route found');

    final route   = data['routes'][0];
    final coords  = route['geometry']['coordinates'] as List;
    final points  = coords
        .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    final distanceKm  = (route['distance'] as num).toDouble() / 1000.0;
    final durationMin = ((route['duration'] as num).toDouble() / 60).ceil();

    return _RouteResult(
        points: points, distanceKm: distanceKm, durationMin: durationMin);
  }

  // ── ملاءمة الخريطة لحدود المسار ──────────────────────────────
  void _fitRouteBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    const pad = 0.005;
    _mapController.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds(
        LatLng(minLat - pad, minLng - pad),
        LatLng(maxLat + pad, maxLng + pad),
      ),
      padding: const EdgeInsets.only(
          top: 160, bottom: 320, left: 50, right: 50),
    ));
  }

  LatLngBounds _allBounds() {
    final pts = <LatLng>[
      LatLng(widget.paramedicLat, widget.paramedicLng),
      ...widget.hospitals.map((h) => LatLng(h.lat, h.lng)),
    ];
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    const pad = 0.015;
    return LatLngBounds(
      LatLng(minLat - pad, minLng - pad),
      LatLng(maxLat + pad, maxLng + pad),
    );
  }

  Color _occColor(String load) {
    switch (load) {
      case 'high': return Colors.redAccent;
      case 'low':  return _C.teal;
      default:     return Colors.orangeAccent;
    }
  }

  Future<void> _sendCase() async {
    if (_selectedId == null) return;
    setState(() => _isSending = true);
    try {
      final h = widget.hospitals.firstWhere((x) => x.id == _selectedId);
      try { await ApiService.updateLocation(widget.paramedicLat, widget.paramedicLng); }
      catch (_) {
        try {
          final pos = await LocationService.getCurrentPosition();
          if (pos != null)
            await ApiService.updateLocation(pos.latitude, pos.longitude);
        } catch (_) {}
      }

      // استخدام المسافة والوقت الحقيقي من OSRM إذا توفّر
      final realDuration = _routeDurationMin ?? h.estimatedDrivingTimeMins;

      final req = AmbulanceRequest(
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
        estimatedArrivalTime: realDuration,
      );
      final res = await ApiService.sendRequest(req);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => CaseSentScreen(
            hospitalName: h.name,
            requestId: res['request']?['id']?.toString() ?? '---',
            hospitalPhone: h.phone,
          ),
        ),
            (r) => r.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _C.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }

  // ── Markers ──────────────────────────────────────────────────
  List<Marker> _buildMarkers() {
    final list = <Marker>[];

    // موقع المسعف
    list.add(Marker(
      point: LatLng(widget.paramedicLat, widget.paramedicLng),
      width: 70, height: 90,
      child: _ParamedicMarker(),
    ));

    for (int i = 0; i < widget.hospitals.length; i++) {
      final h = widget.hospitals[i];
      final sel    = _selectedId == h.id;
      final isBest = i == 0;
      list.add(Marker(
        point: LatLng(h.lat, h.lng),
        width: sel ? 200 : 180,
        height: sel ? 80 : 68,
        child: GestureDetector(
          onTap: () => _selectHospital(h.id),
          child: _HospitalPin(
              name: h.name, isSelected: sel, isBest: isBest),
        ),
      ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      body: Stack(children: [
        // ── الخريطة ──────────────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: _allBounds(),
              padding: EdgeInsets.only(
                  top: topPad + 140, bottom: 380, left: 50, right: 50),
            ),
            interactionOptions:
            const InteractionOptions(flags: InteractiveFlag.all),
            onTap: (_, __) => setState(() {
              _selectedId = null;
              _routePoints = [];
            }),
          ),
          children: [
            // خريطة داكنة نظيفة
            TileLayer(
              urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_matter_no_labels/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.smartambulance.app',
            ),
            // طبقة النصوص فوقها
            TileLayer(
              urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_only_labels/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.smartambulance.app',
            ),
            // مسار OSRM
            if (_routePoints.isNotEmpty)
              PolylineLayer(polylines: [
                // توهج خارجي
                Polyline(
                  points: _routePoints,
                  color: _C.primary.withValues(alpha: 0.20),
                  strokeWidth: 14,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
                // الخط الرئيسي
                Polyline(
                  points: _routePoints,
                  color: _C.primary.withValues(alpha: 0.95),
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
                // خط أبيض داخلي رفيع
                Polyline(
                  points: _routePoints,
                  color: Colors.white.withValues(alpha: 0.30),
                  strokeWidth: 1.5,
                  strokeCap: StrokeCap.round,
                ),
              ]),
            MarkerLayer(markers: _buildMarkers()),
          ],
        ),

        // ── تدرج علوي ────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          height: topPad + kToolbarHeight + 100,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _C.bg.withValues(alpha: 0.90),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── تدرج سفلي ────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: 160,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [_C.bg.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
            ),
          ),
        ),

        // ── AppBar مخصص ──────────────────────────────────────
        Positioned(
          top: topPad + 8,
          left: 16, right: 16,
          child: Row(children: [
            _RoundBtn(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(child: _TopBanner()),
          ]),
        ),

        // ── مؤشر تحميل المسار ────────────────────────────────
        if (_isLoadingRoute)
          Positioned(
            top: topPad + 70,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _C.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _C.teal),
                    ),
                    SizedBox(width: 8),
                    Text('جارٍ حساب المسار...',
                        style: TextStyle(
                            color: _C.teal, fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),

        // ── أزرار التحكم (يمين) ──────────────────────────────
        Positioned(
          bottom: _selectedId != null ? 230 : 310,
          right: 14,
          child: Column(children: [
            _RoundBtn(
              onTap: () => _mapController.move(
                  LatLng(widget.paramedicLat, widget.paramedicLng), 15),
              tooltip: 'موقعي',
              child: const Icon(Icons.my_location_rounded,
                  color: _C.blue, size: 20),
            ),
            const SizedBox(height: 10),
            _RoundBtn(
              onTap: () {
                if (_routePoints.isNotEmpty)
                  _fitRouteBounds(_routePoints);
                else
                  _mapController.fitCamera(CameraFit.bounds(
                    bounds: _allBounds(),
                    padding: const EdgeInsets.only(
                        top: 150, bottom: 350, left: 50, right: 50),
                  ));
              },
              tooltip: 'عرض الكل',
              child: const Icon(Icons.fit_screen_rounded,
                  color: _C.textSub, size: 20),
            ),
          ]),
        ),

        // ── البطاقة أو القائمة ────────────────────────────────
        if (_selectedId != null)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SlideTransition(
              position: _cardSlide,
              child: FadeTransition(
                opacity: _cardFade,
                child: _buildSelectedCard(),
              ),
            ),
          )
        else
          DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.15,
            maxChildSize: 0.68,
            builder: (_, ctrl) => _buildListSheet(ctrl),
          ),
      ]),
    );
  }

  // ── بطاقة المستشفى المحدد ──────────────────────────────────
  Widget _buildSelectedCard() {
    final h       = widget.hospitals.firstWhere((e) => e.id == _selectedId);
    final occ     = _occColor(h.occupancyLoad);
    final isBest  = widget.hospitals.first.id == h.id;

    // استخدام بيانات OSRM الحقيقية إذا توفرت
    final distTxt = _routeDistanceKm != null
        ? '\${_routeDistanceKm!.toStringAsFixed(1)} كم'
        : '\${h.drivingDistance.toStringAsFixed(1)} كم';
    final timeTxt = _routeDurationMin != null
        ? '~\${_routeDurationMin} د'
        : '~\${h.estimatedDrivingTimeMins} د';

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30, offset: const Offset(0, -6)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // handle
        Container(
          margin: const EdgeInsets.only(top: 10),
          width: 38, height: 4,
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(4)),
        ),
        // شريط الازدحام
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          height: 2.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              occ.withValues(alpha: 0), occ, occ.withValues(alpha: 0)
            ]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // هيدر
            Row(children: [
              _RoundBtn(
                size: 34,
                onTap: () => setState(() {
                  _selectedId = null;
                  _routePoints = [];
                }),
                child: const Icon(Icons.close, color: Colors.white54, size: 16),
              ),
              const Spacer(),
              if (isBest)
                _Badge(
                  label: 'الأنسب',
                  icon: Icons.verified_rounded,
                  color: _C.teal,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(h.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _C.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.primary.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.local_hospital_rounded,
                    color: _C.primary, size: 20),
              ),
            ]),

            const SizedBox(height: 14),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),

            // معلومات المسار (من OSRM)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (_isLoadingRoute)
                _LoadingPill()
              else
                _InfoPill(
                  icon: Icons.directions_car_rounded,
                  text: '\$distTxt  •  \$timeTxt',
                  color: Colors.white70,
                  bg: Colors.white.withValues(alpha: 0.07),
                ),
              const SizedBox(width: 8),
              _InfoPill(
                icon: Icons.group_rounded,
                text: h.occupancyLoadAr.isNotEmpty
                    ? h.occupancyLoadAr
                    : h.occupancyLoad,
                color: occ,
                bg: occ.withValues(alpha: 0.12),
                border: occ.withValues(alpha: 0.3),
              ),
            ]),

            // إشارة OSRM
            if (_routeDistanceKm != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Icon(Icons.route_rounded, size: 12, color: _C.teal),
                    SizedBox(width: 4),
                    Text('مسار حقيقي على الطرق',
                        style: TextStyle(
                            color: _C.teal, fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),

            if (h.treatments != null && h.treatments!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(h.treatments!,
                  style: const TextStyle(
                      color: _C.textFaint, fontSize: 12, height: 1.5),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],

            const SizedBox(height: 16),

            // زر الإرسال
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendCase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary,
                  disabledBackgroundColor: _C.primary.withValues(alpha: 0.4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: _isSending
                    ? const Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('جارٍ الإرسال...',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ])
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('إرسال الحالة الآن 🚨',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(Icons.send_rounded, size: 20),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── قائمة المستشفيات ──────────────────────────────────────
  Widget _buildListSheet(ScrollController ctrl) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24, offset: const Offset(0, -4))
        ],
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          width: 38, height: 4,
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(4)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            _Badge(
              label: '\${widget.hospitals.length}',
              color: _C.teal,
              compact: true,
            ),
            const Spacer(),
            const Text('المستشفيات المتاحة',
                style: TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
        ),
        const Divider(color: Colors.white10, height: 1),
        Expanded(
          child: ListView.separated(
            controller: ctrl,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            itemCount: widget.hospitals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final h      = widget.hospitals[i];
              final occ    = _occColor(h.occupancyLoad);
              final isBest = i == 0;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _selectHospital(h.id),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _C.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isBest
                            ? _C.teal.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(children: [
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: occ.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: occ.withValues(alpha: 0.3)),
                          ),
                          child: Icon(Icons.local_hospital_rounded,
                              color: occ, size: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          h.occupancyLoadAr.isNotEmpty
                              ? h.occupancyLoadAr
                              : h.occupancyLoad,
                          style: TextStyle(
                              color: occ, fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (isBest) ...[
                                      _Badge(
                                          label: 'الأنسب',
                                          icon: Icons.verified_rounded,
                                          color: _C.teal,
                                          compact: true),
                                      const SizedBox(width: 6),
                                    ],
                                    Flexible(
                                      child: Text(h.name,
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 15,
                                              fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ]),
                              const SizedBox(height: 5),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\${h.drivingDistance.toStringAsFixed(1)} كم  •  ~\${h.estimatedDrivingTimeMins} د',
                                      style: const TextStyle(
                                          color: _C.textFaint, fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.directions_car_rounded,
                                        color: _C.textFaint, size: 13),
                                  ]),
                            ]),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_back_ios_rounded,
                          color: Colors.white24, size: 13),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ── نتيجة OSRM
// ══════════════════════════════════════════════════════════════
class _RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMin;
  const _RouteResult(
      {required this.points,
        required this.distanceKm,
        required this.durationMin});
}

// ══════════════════════════════════════════════════════════════
// ── Marker المسعف (واضح ومميز)
// ══════════════════════════════════════════════════════════════
class _ParamedicMarker extends StatefulWidget {
  @override
  State<_ParamedicMarker> createState() => _ParamedicMarkerState();
}

class _ParamedicMarkerState extends State<_ParamedicMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _scale   = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.8, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Label المسعف
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _C.blue,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: _C.blue.withValues(alpha: 0.5),
                blurRadius: 8, spreadRadius: 1),
          ],
        ),
        child: const Text('🚑 المسعف',
            style: TextStyle(
                color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 4),
      // نقطة نابضة
      SizedBox(
        width: 50, height: 50,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.blue.withValues(alpha: _opacity.value * 0.25),
                  border: Border.all(
                    color: _C.blue.withValues(alpha: _opacity.value),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: _C.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(color: _C.blue.withValues(alpha: 0.7),
                    blurRadius: 12, spreadRadius: 3),
              ],
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// ── Marker المستشفى
// ══════════════════════════════════════════════════════════════
class _HospitalPin extends StatelessWidget {
  final String name;
  final bool isSelected, isBest;
  const _HospitalPin(
      {required this.name,
        required this.isSelected,
        required this.isBest});

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? _C.primary : isBest ? _C.teal : const Color(0xFF1C2A40);
    final glow = isSelected
        ? _C.primary.withValues(alpha: 0.35)
        : isBest
        ? _C.teal.withValues(alpha: 0.30)
        : Colors.transparent;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected || isBest ? Colors.transparent : Colors.white24,
          ),
          boxShadow: isSelected || isBest
              ? [BoxShadow(color: glow, blurRadius: 14, spreadRadius: 2)]
              : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isBest)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.verified_rounded,
                  size: 11, color: Colors.white),
            ),
          Flexible(
            child: Text(name,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
      const SizedBox(height: 2),
      Icon(Icons.location_on_rounded,
          color: isSelected ? _C.primary : isBest ? _C.teal : Colors.white60,
          size: isSelected ? 34 : 26),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// ── Widgets مساعدة
// ══════════════════════════════════════════════════════════════
class _RoundBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final String? tooltip;
  final double size;

  const _RoundBtn(
      {required this.onTap,
        required this.child,
        this.tooltip,
        this.size = 44});

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: _C.surface.withValues(alpha: 0.93),
          shape: BoxShape.circle,
          border: Border.all(color: _C.border),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10,
                offset: Offset(0, 3))
          ],
        ),
        child: child,
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _TopBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.teal.withValues(alpha: 0.28)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Row(children: const [
        SizedBox(width: 4),
        Icon(Icons.auto_awesome_rounded, color: _C.teal, size: 17),
        SizedBox(width: 8),
        Expanded(
          child: Text('مرتبة آلياً • مسارات حقيقية على الطريق',
              style: TextStyle(
                  color: Color(0xFF80CBC4), fontSize: 12,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.right),
        ),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool compact;
  const _Badge(
      {required this.label,
        this.icon,
        required this.color,
        this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(compact ? 8 : 20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color, bg;
  final Color? border;
  const _InfoPill(
      {required this.icon,
        required this.text,
        required this.color,
        required this.bg,
        this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: border ?? Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Icon(icon, size: 14, color: color),
      ]),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: const [
        SizedBox(width: 12, height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: _C.teal)),
        SizedBox(width: 8),
        Text('جارٍ الحساب...',
            style: TextStyle(color: _C.teal, fontSize: 12,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// AnimatedBuilder
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  const AnimatedBuilder(
      {super.key,
        required Animation<double> animation,
        required this.builder})
      : super(listenable: animation);
  @override
  Widget build(BuildContext context) => builder(context, null);
}