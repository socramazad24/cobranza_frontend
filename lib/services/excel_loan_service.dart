import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class ExcelLoanService {
  Future<File?> pickExcelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result == null || result.files.single.path == null) return null;
    return File(result.files.single.path!);
  }

  Future<List<Map<String, dynamic>>> readLoansFromExcel(File file) async {
    final bytes = file.readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) return [];

    final sheet = excel.tables.values.first;
    final rows = sheet.rows;
    if (rows.isEmpty) return [];

    final headers = rows.first
        .map((e) => (e?.value?.toString() ?? '').trim().toLowerCase())
        .toList();

    final data = <Map<String, dynamic>>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final vacia = row.every(
        (c) => (c?.value?.toString() ?? '').trim().isEmpty,
      );
      if (vacia) continue;

      final map = <String, dynamic>{};

      for (int j = 0; j < headers.length; j++) {
        final key = headers[j];
        final value = j < row.length ? row[j]?.value?.toString().trim() : '';
        map[key] = value;
      }

      data.add({
        'fila': i + 1,
        'clienteNombre': map['clientenombre'] ?? '',
        'clienteTelefono': map['clientetelefono'] ?? map['telefono'] ?? '',
        'clienteDireccion': map['clientedireccion'] ?? map['direccion'] ?? '',
        'montoPrestado': double.tryParse('${map['montoprestado'] ?? ''}') ?? 0,
        'montoTotal': double.tryParse('${map['montototal'] ?? ''}') ?? 0,
        'diasPlazo': int.tryParse('${map['diasplazo'] ?? ''}') ?? 30,
        'cobradorId': map['cobradorid'],
        'rutaId': int.tryParse('${map['rutaid'] ?? ''}'),
        'rutaNombre': map['rutanombre'],
      });
    }

    return data;
  }

  Future<Map<String, dynamic>> importarPrestamos(
    List<Map<String, dynamic>> prestamos,
  ) async {
    final payload = prestamos.map((p) {
      return {
        'fila': p['fila'],
        'clientenombre': p['clienteNombre'],
        'clientetelefono': p['clienteTelefono'],
        'clientedireccion': p['clienteDireccion'],
        'montoprestado': p['montoPrestado'],
        'montototal': p['montoTotal'],
        'diasplazo': p['diasPlazo'],
        'cobradorid': p['cobradorId'],
        'rutaid': p['rutaId'],
        'rutanombre': p['rutaNombre'],
      };
    }).toList();

    final response = await ApiClient.post(
      '${Constants.apiUrl}/api/loans/importar',
      payload as Map<String, dynamic>,
    );

    if (response == null) {
      return {'ok': false, 'error': 'Sin respuesta del servidor'};
    }

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'ok': true, 'data': body};
    }

    return {
      'ok': false,
      'error': body['error']?.toString() ?? 'Error importando préstamos',
    };
  }
}