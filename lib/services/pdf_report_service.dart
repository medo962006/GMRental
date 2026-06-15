// lib/services/pdf_report_service.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/tenant.dart';
import '../models/room.dart';
import '../models/masareef.dart';
import '../models/operational_cost.dart';

class PdfReportService {
  static Future<void> generateAndPrint({
    required Map<String, dynamic> dashboardStats,
    required List<Tenant> tenants,
    required List<Room> rooms,
    required List<Masareef> expenses,
    required List<OperationalCost> opCosts,
  }) async {
    final pdf = pw.Document();

    final totalExpected = _toDouble(dashboardStats['totalRentExpected']);
    final totalExpenses = _toDouble(dashboardStats['totalExpenses']);
    final totalOpCosts = _toDouble(dashboardStats['totalOpCosts']);
    final netBalanceVal = _toDouble(dashboardStats['netBalance']);
    final paidCount = dashboardStats['paidTenants'] as int? ?? 0;
    final unpaidCount = dashboardStats['unpaidTenants'] as int? ?? 0;

    double collected = 0, due = 0;
    final roomMap = {for (var r in rooms) r.id: r.monthlyRent};
    for (final t in tenants) {
      if (!t.isActive) continue;
      final rent = t.roomId != null ? (roomMap[t.roomId] ?? 0) : 0;
      if (t.isPaid) {
        collected += rent;
      } else {
        due += rent;
      }
    }

    final salaryCosts =
        opCosts.where((c) => c.isSalary).fold(0.0, (s, c) => s + c.amount);
    final adCosts =
        opCosts.where((c) => c.isAdSpend).fold(0.0, (s, c) => s + c.amount);
    final subCosts = opCosts
        .where((c) => c.isSubscription)
        .fold(0.0, (s, c) => s + c.amount);
    final allCosts = totalExpenses + totalOpCosts;
    final now = DateTime.now();
    final occupiedCount = rooms.where((r) => r.isOccupied).length;
    final voidCount = rooms.where((r) => r.isVoid).length;
    final activeTenants = tenants.where((t) => t.isActive).length;

    final children = <pw.Widget>[
      pw.Header(
        level: 0,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Hostel Management - Financial Summary',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Generated: ${now.day}/${now.month}/${now.year}',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            pw.Divider(thickness: 2),
          ],
        ),
      ),
      pw.SizedBox(height: 16),
      pw.Text('Income Overview',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        children: [
          _makeHRow(['Metric', 'Amount (LE)', 'Notes']),
          _makeDRow([
            'Total Rent Expected',
            _fmt(totalExpected),
            '$occupiedCount occupied rooms'
          ]),
          _makeDRow(
              ['Rent Collected', _fmt(collected), '$paidCount paid tenants']),
          _makeDRow(
              ['Rent Outstanding', _fmt(due), '$unpaidCount unpaid tenants']),
        ],
      ),
      pw.SizedBox(height: 20),
      pw.Text('Expenditures',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        children: [
          _makeHRow(['Category', 'Amount (LE)']),
          _makeDRow(['Daily Masareef', _fmt(totalExpenses)]),
          _makeDRow(['Salaries', _fmt(salaryCosts)]),
          _makeDRow(['Ad Spend', _fmt(adCosts)]),
          _makeDRow(['Subscriptions', _fmt(subCosts)]),
          _makeDRow(['Total Costs', _fmt(allCosts)]),
        ],
      ),
      pw.SizedBox(height: 20),
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: netBalanceVal >= 0 ? PdfColors.green50 : PdfColors.red50,
          border: pw.Border.all(
            color: netBalanceVal >= 0 ? PdfColors.green : PdfColors.red,
            width: 2,
          ),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Net Cash Position',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('${_fmt(netBalanceVal)} LE',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color:
                      netBalanceVal >= 0 ? PdfColors.green800 : PdfColors.red800,
                )),
          ],
        ),
      ),
      pw.SizedBox(height: 20),
      pw.Text('Occupancy',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        children: [
          _makeHRow(['Status', 'Count']),
          _makeDRow(['Occupied Rooms', '$occupiedCount']),
          _makeDRow(['Void Rooms', '$voidCount']),
          _makeDRow(['Active Tenants', '$activeTenants']),
        ],
      ),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => children,
      ),
    );

    // ── Web: download via browser ──
    if (kIsWeb) {
      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'hostel_report_${now.year}-${now.month}-${now.day}.pdf',
      );
      return;
    }

    // ── Mobile/Desktop: native print dialog ──
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;

  static pw.TableRow _makeHRow(List<String> cells) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: cells
          .map((c) => pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(c,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ))
          .toList(),
    );
  }

  static pw.TableRow _makeDRow(List<String> cells) {
    return pw.TableRow(
      children: cells
          .map((c) => pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(c, style: const pw.TextStyle(fontSize: 10)),
              ))
          .toList(),
    );
  }

  static String _fmt(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString();
    return val.toStringAsFixed(2);
  }
}
