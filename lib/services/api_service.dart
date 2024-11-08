import 'package:excel/excel.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../models/item.dart';
import '../models/location.dart';

class ApiService {
  static final String baseUrl =
      dotenv.env['API_URL'] ?? 'http://localhost:3000/api';

  Future<List<Item>> fetchItems() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/export/csv'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['labels'] as List)
            .map((item) => Item.fromJson(item))
            .toList();
      } else {
        throw Exception('Failed to load items: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching items: $e');
    }
  }

  Future<bool> updateItemStatus(String labelId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/items/$labelId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error updating status: $e');
    }
  }

  Future<bool> updateItemLocation(String labelId, String locationId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/items/$labelId/location'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'location_id': locationId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error updating location: $e');
    }
  }

  Future<List<Location>> fetchLocations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/locations'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          return (data['data'] as List)
              .map((item) => Location.fromJson(item))
              .toList();
        }
        return [];
      } else {
        throw Exception('Failed to load locations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching locations: $e');
    }
  }

  Future<bool> createLocation(String locationId, String typeName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/locations'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'location_id': locationId,
          'type_name': typeName,
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      throw Exception('Error creating location: $e');
    }
  }

  Future<void> exportToCSV() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/export/csv'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Create a new Excel workbook
        var excel = Excel.createExcel();

        // Remove default Sheet1
        excel.delete('Sheet1');

        // Create Item sheet
        var itemSheet = excel['Item'];
        // Add headers
        var itemHeaders = [
          'Label ID',
          'Label Type',
          'Location',
          'Status',
          'Last Scan Time'
        ];
        for (var i = 0; i < itemHeaders.length; i++) {
          itemSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
              .value = TextCellValue(itemHeaders[i]);
        }

        // Add item data
        var row = 1; // Start from row 1 since headers are at row 0
        for (var item in data['labels'] ?? []) {
          itemSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
              .value = TextCellValue(item['labelId'] ?? '');
          itemSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
              .value = TextCellValue(item['labelType'] ?? '');
          itemSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
              .value = TextCellValue(item['location'] ?? '');
          itemSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
              .value = TextCellValue(item['status'] ?? '');
          itemSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
              .value = TextCellValue(item['lastScanTime'] ?? '');
          row++;
        }

        // Remove default Sheet1
        excel.delete('Sheet1');

        // Create Roll sheet
        var rollSheet = excel['Roll'];
        // Add headers
        var rollHeaders = [
          'Label ID',
          'Code',
          'Name',
          'Size (mm)',
          'Status',
          'Last Scan Time'
        ];
        for (var i = 0; i < rollHeaders.length; i++) {
          rollSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
              .value = TextCellValue(rollHeaders[i]);
        }

        // Add roll data
        row = 1; // Reset row counter
        for (var roll in data['rolls'] ?? []) {
          rollSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
              .value = TextCellValue(roll['labelId'] ?? '');
          rollSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
              .value = TextCellValue(roll['code'] ?? '');
          rollSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
              .value = TextCellValue(roll['name'] ?? '');
          rollSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
              .value = TextCellValue(roll['size']?.toString() ?? '');
          rollSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
              .value = TextCellValue(roll['status'] ?? '');
          rollSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
              .value = TextCellValue(roll['lastScanTime'] ?? '');
          row++;
        }

        // Remove default Sheet1
        excel.delete('Sheet1');

        // Create FG Pallet sheet
        var palletSheet = excel['FG Pallet'];
        // Add headers
        var palletHeaders = [
          'Label ID',
          'PLT',
          'Quantity (pcs)',
          'Work Order ID',
          'Total (pcs)',
          'Status',
          'Last Scan Time'
        ];
        for (var i = 0; i < palletHeaders.length; i++) {
          palletSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
              .value = TextCellValue(palletHeaders[i]);
        }

        // Add pallet data
        row = 1; // Reset row counter
        for (var pallet in data['pallets'] ?? []) {
          palletSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
              .value = TextCellValue(pallet['labelId'] ?? '');
          palletSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
              .value = TextCellValue(pallet['pltNumber']?.toString() ?? '');
          palletSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
              .value = TextCellValue(pallet['quantity']?.toString() ?? '');
          palletSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
              .value = TextCellValue(pallet['workOrderId'] ?? '');
          palletSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
              .value = TextCellValue(pallet['totalPieces']?.toString() ?? '');
          palletSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
              .value = TextCellValue(pallet['status'] ?? '');
          palletSheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
              .value = TextCellValue(pallet['lastScanTime'] ?? '');
          row++;
        }

        // Set Item as default sheet
        excel.setDefaultSheet('Item');

        // Get the application documents directory and save
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'CPS_Data_$timestamp.xlsx';
        final filePath = '${directory.path}/$fileName';

        // Save and get bytes
        var fileBytes = excel.save(fileName: fileName);

        if (fileBytes != null) {
          // Create physical file
          final file = File(filePath);
          await file.writeAsBytes(fileBytes);

          // Share the file
          await Share.shareXFiles(
            [XFile(filePath)],
            subject: 'CPS Data',
            text: 'CPS Inventory Data Export',
          );

          // Clean up
          await file.delete();
        } else {
          throw Exception('Failed to generate Excel file');
        }
      } else {
        throw Exception('Failed to export data: ${response.statusCode}');
      }
    } catch (e) {
      print('Export error details: $e'); // Debug print
      throw Exception('Error exporting data: $e');
    }
  }
}
