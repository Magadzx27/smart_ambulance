import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}

class LocationService {
  static Future<Position?> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw LocationException('يرجى تفعيل خدمة الموقع');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw LocationException('تم رفض صلاحية الموقع');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw LocationException('تم رفض صلاحية الموقع');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } on LocationException {
      rethrow;
    } catch (_) {
      throw LocationException('تعذر تحديد الموقع الحالي');
    }
  }

  static String calculateETA(double distanceKm) {
    double minutes = (distanceKm / 60) * 60;
    if (minutes < 1) return 'أقل من دقيقة';
    return '${minutes.toStringAsFixed(0)} دقيقة';
  }
}