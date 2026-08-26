import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_manager/models/tenant.dart';

void main() {
  group('Tenant model', () {
    test('serializes and deserializes ID card URL fields', () {
      final tenant = Tenant(
        id: 'abc-123',
        name: 'Ahmed Ali',
        phone: '01234567890',
        gender: 'male',
        roomId: 201,
        status: 'active',
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
        buildingId: 1,
        hasCar: false,
        idFrontUrl: 'https://example.com/front.png',
        idBackUrl: 'https://example.com/back.png',
      );

      final json = tenant.toJson();
      expect(json['id_front_url'], 'https://example.com/front.png');
      expect(json['id_back_url'], 'https://example.com/back.png');

      final decoded = Tenant.fromJson(json);
      expect(decoded.idFrontUrl, 'https://example.com/front.png');
      expect(decoded.idBackUrl, 'https://example.com/back.png');
    });

    test('ID card fields default to null when absent', () {
      final json = {
        'id': 'abc',
        'name': 'Sara',
        'phone': '01111111111',
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
      };
      final tenant = Tenant.fromJson(json);
      expect(tenant.idFrontUrl, isNull);
      expect(tenant.idBackUrl, isNull);
    });

    test('copyWith preserves existing back URL when only front changes', () {
      final tenant = Tenant(
        id: 'abc',
        name: 'Sara',
        phone: '01111111111',
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
        idFrontUrl: 'front.png',
        idBackUrl: 'back.png',
      );

      final updated = tenant.copyWith(idFrontUrl: 'new-front.png');
      expect(updated.idFrontUrl, 'new-front.png');
      expect(updated.idBackUrl, 'back.png');
    });
  });
}