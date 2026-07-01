import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:open_filex/open_filex.dart';

class ExcelExportService {
  Future<File> exportPrestamos(List<dynamic> prestamos) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Prestamos';

    final headers = [
      'ID',
      'Cliente',
      'Telefono',
      'Ruta',
      'Cobrador',
      'Monto Prestado',
      'Monto Total',
      'Saldo Pendiente',
      'Cuota Diaria',
      'Fecha Inicio',
      'Fecha Fin',
      'Estado',
    ];

    for (int i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
    }

    for (int i = 0; i < prestamos.length; i++) {
      final p = prestamos[i] as Map;
      final fila = i + 2;

      sheet
          .getRangeByIndex(fila, 1)
          .setNumber(double.tryParse('${p['id']}') ?? 0);
      sheet
          .getRangeByIndex(fila, 2)
          .setText('${p['cliente_nombre'] ?? p['clientenombre'] ?? ''}');
      sheet
          .getRangeByIndex(fila, 3)
          .setText('${p['cliente_telefono'] ?? p['clientetelefono'] ?? ''}');
      sheet
          .getRangeByIndex(fila, 4)
          .setText('${p['ruta_nombre'] ?? p['rutanombre'] ?? ''}');
      sheet
          .getRangeByIndex(fila, 5)
          .setText('${p['cobrador_nombre'] ?? p['cobradornombre'] ?? ''}');
      sheet.getRangeByIndex(fila, 6).setNumber(
            (p['monto_prestado'] as num?)?.toDouble() ??
                (p['montoprestado'] as num?)?.toDouble() ??
                0,
          );
      sheet.getRangeByIndex(fila, 7).setNumber(
            (p['monto_total'] as num?)?.toDouble() ??
                (p['montototal'] as num?)?.toDouble() ??
                0,
          );
      sheet.getRangeByIndex(fila, 8).setNumber(
            (p['saldo_pendiente'] as num?)?.toDouble() ??
                (p['saldopendiente'] as num?)?.toDouble() ??
                0,
          );
      sheet.getRangeByIndex(fila, 9).setNumber(
            (p['cuota_diaria'] as num?)?.toDouble() ??
                (p['cuotadiaria'] as num?)?.toDouble() ??
                0,
          );
      sheet
          .getRangeByIndex(fila, 10)
          .setText('${p['fecha_inicio'] ?? p['fechainicio'] ?? ''}');
      sheet
          .getRangeByIndex(fila, 11)
          .setText('${p['fecha_fin'] ?? p['fechafin'] ?? ''}');
      sheet.getRangeByIndex(fila, 12).setText('${p['estado'] ?? ''}');
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/prestamos_export.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> openFile(File file) async {
    await OpenFilex.open(file.path);
  }
}