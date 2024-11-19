import 'package:gsheets/gsheets.dart';

class GSheetsService {
  static const _spreadsheetId = '1_eFa6KYA9f2qLImo_yvPJ6RLQbJyxHmj6usr5WEf2E0';
  final GSheets _gsheets;
  Worksheet? _worksheet;

  GSheetsService(String credentialsJson)
      : _gsheets = GSheets(credentialsJson);

  Future<void> init() async {
    try {
      final spreadsheet = await _gsheets.spreadsheet(_spreadsheetId);
      _worksheet = spreadsheet.worksheetByTitle('Hoja 1');
      if (_worksheet == null) {
        throw Exception('No se encontró la hoja con el título "Hoja1".');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<List<String>>> getAllRows() async {
    if (_worksheet == null) throw Exception('Worksheet no inicializada');
    return await _worksheet!.values.allRows();
  }

  Future<bool> insertRow(List<String> row) async {
    if (_worksheet == null) throw Exception('Worksheet no inicializada');
    return await _worksheet!.values.appendRow(row);
  }
  Future<bool> updateCell({
    required int row,
    required int column,
    required String value,
  }) async {
    if (_worksheet == null) throw Exception('Worksheet no inicializada');
    return await _worksheet!.values.insertValue(
      value,
      column: column + 1, // GSheets usa índices basados en 1
      row: row + 1,
    );
  }

  // Nuevo método para eliminar una fila
  Future<bool> deleteRow(int rowIndex) async {
    if (_worksheet == null) throw Exception('Worksheet no inicializada');
    return await _worksheet!.deleteRow(rowIndex + 1); // GSheets usa índices basados en 1
  }
}
