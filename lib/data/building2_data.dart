// lib/data/building2_data.dart
// Second building — static data for 3 floors.
import '../models/room.dart';
import '../models/tenant.dart';

class Building2Data {
  static const buildingId = 2;
  static const buildingName = 'Baraka';

  static List<Room> get rooms {
    final list = <Room>[];
    int id = 1000;

    // Ground floor: 1-13
    for (int i = 1; i <= 13; i++) {
      final isVoid = (i == 3); // 3 is void per data (shows "متاحة")
      list.add(Room(
        id: id++,
        roomNumber: '$i',
        status: isVoid ? 'void' : 'occupied',
        monthlyRent: _groundRent(i),
      ));
    }

    // First floor: 1-- to 15--
    for (int i = 1; i <= 15; i++) {
      final isVoid = (i == 3 || i == 7 || i == 9 || i == 14);
      list.add(Room(
        id: id++,
        roomNumber: '$i--',
        status: isVoid ? 'void' : 'occupied',
        monthlyRent: isVoid ? 0 : _firstRent(i),
      ));
    }

    // Second floor: 1--- to 4---
    for (int i = 1; i <= 4; i++) {
      final isVoid = (i == 3 || i == 4);
      list.add(Room(
        id: id++,
        roomNumber: '$i---',
        status: isVoid ? 'void' : 'occupied',
        monthlyRent: isVoid ? 0 : _secondRent(i),
      ));
    }

    return list;
  }

  static List<Tenant> get tenants {
    final list = <Tenant>[];
    int tid = 2000;
    final now = DateTime.now();

    // ── Ground Floor ──
    list.add(_mk(tid++, 'حازم ناصر محمد (السويدي)', '201040003307', 1001, 10000, 8, 'مصري', 1, true));
    list.add(_mk(tid++, 'Ibrahim', '', 1002, 0, null, null, null, true));
    list.add(_mk(tid++, 'نادين طارق', '201102808005', 1003, 9500, 5, 'مصري', 1, true));
    list.add(_mk(tid++, 'السودانية', '', 1004, 12500, 6, 'سودان', 5, false));
    list.add(_mk(tid++, 'احمد بسيوني', '201270051555', 1005, 10500, 22, 'مصري', 12, true));
    list.add(_mk(tid++, 'محمد فرحات', '201032767078', 1006, 9500, 1, 'مصري', 1, true));
    list.add(_mk(tid++, 'احمد رمضان', '201279995585', 1007, 8000, 22, 'مصري', 12, true));
    list.add(_mk(tid++, 'سلمى', '+201099752032', 1008, 9500, 6, 'مصرية', 6, true));
    list.add(_mk(tid++, 'منال السودانية', '+201140843990', 1009, 10500, 18, 'سودان', 5, true));
    list.add(_mk(tid++, 'ابراهيم محمد صلاح', '201010010169', 1010, 12500, 29, 'مصري', 12, true));
    list.add(_mk(tid++, 'انس نبيل', '201093247363', 1011, 8000, 1, 'مصري', 12, true));
    list.add(_mk(tid++, 'عمر وليد سعيد', '201093247363', 1012, 8000, 3, 'مصري', 1, true));
    list.add(_mk(tid++, 'ملك', '', 1013, 9500, 4, 'مصرية', 6, true));

    // ── First Floor ──
    list.add(_mk(tid++, 'محمد محمد عقل', '201220022855', 1101, 12000, 1, 'مصري', 1, true));
    list.add(_mk(tid++, 'دكتور محمد الماهي', '201010840842', 1102, 10000, 6, 'مصري', 1, true));
    // 1103 void
    list.add(_mk(tid++, 'ابراهيم كمال', '201100230038', 1104, 7000, 24, 'مصري', 12, true));
    list.add(_mk(tid++, 'ادهم حازم', '+201118388599', 1105, 9000, 22, 'مصري', 2, true));
    list.add(_mk(tid++, 'زياد محمد جابر', '+201013795155', 1106, 9500, 25, 'مصري', 5, true));
    // 1107 void
    list.add(_mk(tid++, 'نور', '+201066571668', 1108, 8000, 1, 'مصري', 6, true));
    // 1109 void
    list.add(_mk(tid++, 'جمانه مروان شاهين (غزه)', '201080083589', 1110, 10000, 1, 'مصري', 3, true));
    list.add(_mk(tid++, 'يارا', '', 1111, 11000, 16, 'مصرية', 5, true));
    list.add(_mk(tid++, 'ساجي وليد', '201018919666', 1112, 10000, 10, 'مصري', 1, true));
    list.add(_mk(tid++, 'اسلام فؤاد', '201092205125', 1113, 10000, 12, 'مصري', 1, false));
    // 1114 void
    list.add(_mk(tid++, 'علي', '', 1115, 10000, 1, 'مصري', 6, true));

    // ── Second Floor ──
    list.add(_mk(tid++, 'احمد محروس سعودي', '201055442159', 1201, 13500, 22, 'مصري', 1, true));
    list.add(_mk(tid++, 'سلوى', '', 1202, 13000, 2, 'امريكية', 6, true));
    // 1203, 1204 void
    list.add(_mk(tid++, 'حسام محمد مصطفى موسى', '201007210279', 1205, 9000, 14, 'مصري', 2, false));
    // 1206 void
    list.add(_mk(tid++, 'حسام حنفي', '201024114040', 1207, 9000, 26, 'مصري', 1, true));
    list.add(_mk(tid++, 'عبد الرحمن احمد عبدالرسول', '201013692231', 1208, 9000, 30, 'مصري', 1, true));
    // 1209-1211 void
    list.add(_mk(tid++, 'محمد جمال حسن و أشرف جمال حسن (التوأم)', '+201028322797', 1212, 13000, 31, 'مصري', 1, true));
    list.add(_mk(tid++, 'احمد مصطفى علي جعيطر (Designer)', '+201004382844', 1213, 12000, 1, 'مصري', 2, true));
    // 1214 void

    // ── Third section (1--- to 4---) ──
    list.add(_mk(tid++, 'العقيد ايمن', '', 1301, 10000, 1, 'مصري', 3, false));
    list.add(_mk(tid++, 'عقيد ايمن فرغلي', '+201003607360', 1302, 10000, 1, 'مصري', 3, false));
    // 1303 void
    list.add(_mk(tid++, 'اسامه فرج محمد الامام', '+201105178123', 1304, 12500, 2, 'مصري', 4, true));

    return list;
  }

  static Tenant _mk(int id, String name, String phone, int roomId, double rent,
      int? paymentDay, String? nationality, int? entryMonth, bool isPaid) {
    return Tenant(
      id: 'b2_t$id',
      name: name,
      phone: phone,
      roomId: roomId,
      status: 'active',
      insuranceAmount: rent,
      paymentStatus: isPaid ? 'paid' : 'unpaid',
      dueDate: paymentDay != null
          ? DateTime(DateTime.now().year, DateTime.now().month, paymentDay)
          : null,
      leaseStartDate: entryMonth != null
          ? DateTime(DateTime.now().year, entryMonth, 1)
          : DateTime.now(),
      createdAt: DateTime.now(),
      gender: null,
      insuranceReturned: false,
    );
  }

  static double _groundRent(int room) {
    const rents = {1: 10000, 3: 9500, 4: 12500, 5: 10500, 6: 9500, 7: 8000, 8: 9500, 9: 10500, 10: 12500, 11: 8000, 12: 8000, 13: 9500};
    return rents[room]?.toDouble() ?? 0;
  }

  static double _firstRent(int room) {
    const rents = {1: 12000, 2: 10000, 4: 7000, 5: 9000, 6: 9500, 8: 8000, 10: 10000, 11: 11000, 12: 10000, 13: 10000, 15: 10000};
    return rents[room]?.toDouble() ?? 0;
  }

  static double _secondRent(int room) {
    const rents = {1: 13500, 2: 13000, 5: 9000, 7: 9000, 8: 9000, 12: 13000, 13: 12000, 4: 12500};
    return rents[room]?.toDouble() ?? 0;
  }
}
