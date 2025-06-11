import 'package:gsheets/gsheets.dart';

class GSheetsService {
  static const _spreadsheetId = '1_eFa6KYA9f2qLImo_yvPJ6RLQbJyxHmj6usr5WEf2E0';
  static const _worksheetTitle = 'Hoja 1';

  final GSheets _gsheets;
  Worksheet? _worksheet;
  bool _isInitialized = false;

  GSheetsService(String credentialsJson)
      : _gsheets = GSheets(credentialsJson);

  /// Inicializa la conexión con Google Sheets
  Future<void> init() async {
    try {
      final spreadsheet = await _gsheets.spreadsheet(_spreadsheetId);

      // Intentar obtener la hoja por título
      _worksheet = spreadsheet.worksheetByTitle(_worksheetTitle);

      // Si no existe, crear una nueva hoja
      if (_worksheet == null) {
        _worksheet = await spreadsheet.addWorksheet(_worksheetTitle);
        if (_worksheet == null) {
          throw Exception('No se pudo crear la hoja "$_worksheetTitle".');
        }
      }

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      throw Exception('Error al inicializar Google Sheets: $e');
    }
  }

  /// Verifica si el servicio está inicializado
  void _checkInitialization() {
    if (!_isInitialized || _worksheet == null) {
      throw Exception('El servicio no está inicializado. Llama a init() primero.');
    }
  }

  /// Obtiene todas las filas de la hoja
  Future<List<List<String>>> getAllRows() async {
    _checkInitialization();

    try {
      final rows = await _worksheet!.values.allRows();

      // Si no hay datos, retornar una lista vacía
      if (rows.isEmpty) {
        return [];
      }

      // Normalizar las filas para que todas tengan la misma longitud
      final maxLength = rows.map((row) => row.length).reduce((a, b) => a > b ? a : b);

      return rows.map((row) {
        while (row.length < maxLength) {
          row.add('');
        }
        return row;
      }).toList();

    } catch (e) {
      throw Exception('Error al obtener las filas: $e');
    }
  }

  /// Inserta una nueva fila al final de la hoja
  Future<bool> insertRow(List<String> row) async {
    _checkInitialization();

    if (row.isEmpty) {
      throw Exception('La fila no puede estar vacía.');
    }

    try {
      // Limpiar valores vacíos o nulos
      final cleanRow = row.map((cell) => cell.trim()).toList();

      final success = await _worksheet!.values.appendRow(cleanRow);
      return success;
    } catch (e) {
      throw Exception('Error al insertar la fila: $e');
    }
  }

  /// Actualiza el valor de una celda específica
  Future<bool> updateCell({
    required int row,
    required int column,
    required String value,
  }) async {
    _checkInitialization();

    if (row < 0 || column < 0) {
      throw Exception('Los índices de fila y columna deben ser mayor o igual a 0.');
    }

    try {
      final success = await _worksheet!.values.insertValue(
        value.trim(),
        column: column + 1, // GSheets usa índices basados en 1
        row: row + 1,
      );
      return success;
    } catch (e) {
      throw Exception('Error al actualizar la celda: $e');
    }
  }

  /// Elimina una fila específica
  Future<bool> deleteRow(int rowIndex) async {
    _checkInitialization();

    if (rowIndex < 0) {
      throw Exception('El índice de la fila debe ser mayor o igual a 0.');
    }

    try {
      // Verificar que la fila existe antes de eliminarla
      final allRows = await getAllRows();
      if (rowIndex >= allRows.length) {
        throw Exception('La fila especificada no existe.');
      }

      final success = await _worksheet!.deleteRow(rowIndex + 1); // GSheets usa índices basados en 1
      return success;
    } catch (e) {
      throw Exception('Error al eliminar la fila: $e');
    }
  }

  /// Inserta múltiples filas de una vez
  Future<bool> insertMultipleRows(List<List<String>> rows) async {
    _checkInitialization();

    if (rows.isEmpty) {
      throw Exception('La lista de filas no puede estar vacía.');
    }

    try {
      for (final row in rows) {
        final success = await insertRow(row);
        if (!success) {
          return false;
        }
      }
      return true;
    } catch (e) {
      throw Exception('Error al insertar múltiples filas: $e');
    }
  }

  /// Actualiza múltiples celdas de una vez
  Future<bool> updateRange({
    required int startRow,
    required int startColumn,
    required List<List<String>> values,
  }) async {
    _checkInitialization();

    if (startRow < 0 || startColumn < 0) {
      throw Exception('Los índices de inicio deben ser mayor o igual a 0.');
    }

    if (values.isEmpty) {
      throw Exception('Los valores no pueden estar vacíos.');
    }

    try {
      // Actualizar cada celda individualmente
      for (int rowOffset = 0; rowOffset < values.length; rowOffset++) {
        for (int colOffset = 0; colOffset < values[rowOffset].length; colOffset++) {
          final success = await _worksheet!.values.insertValue(
            values[rowOffset][colOffset],
            column: startColumn + colOffset + 1, // GSheets usa índices basados en 1
            row: startRow + rowOffset + 1,
          );
          if (!success) {
            throw Exception('Error al actualizar celda en fila ${startRow + rowOffset}, columna ${startColumn + colOffset}');
          }
        }
      }
      return true;
    } catch (e) {
      throw Exception('Error al actualizar el rango: $e');
    }
  }

  /// Añade una fila con múltiples columnas
  Future<bool> addRowWithMultipleColumns(List<String> rowData) async {
    _checkInitialization();

    if (rowData.isEmpty) {
      throw Exception('Los datos de la fila no pueden estar vacíos.');
    }

    try {
      final cleanData = rowData.map((cell) => cell.trim()).toList();
      return await _worksheet!.values.appendRow(cleanData);
    } catch (e) {
      throw Exception('Error al añadir la fila: $e');
    }
  }

  /// Obtiene una fila específica
  Future<List<String>> getRow(int rowIndex) async {
    _checkInitialization();

    if (rowIndex < 0) {
      throw Exception('El índice de la fila debe ser mayor o igual a 0.');
    }

    try {
      final allRows = await getAllRows();
      if (rowIndex >= allRows.length) {
        throw Exception('La fila especificada no existe.');
      }

      return allRows[rowIndex];
    } catch (e) {
      throw Exception('Error al obtener la fila: $e');
    }
  }

  /// Obtiene una columna específica
  Future<List<String>> getColumn(int columnIndex) async {
    _checkInitialization();

    if (columnIndex < 0) {
      throw Exception('El índice de la columna debe ser mayor o igual a 0.');
    }

    try {
      final allRows = await getAllRows();
      if (allRows.isEmpty) {
        return [];
      }

      // Verificar que la columna existe
      if (columnIndex >= allRows[0].length) {
        throw Exception('La columna especificada no existe.');
      }

      return allRows.map((row) =>
      columnIndex < row.length ? row[columnIndex] : ''
      ).toList();
    } catch (e) {
      throw Exception('Error al obtener la columna: $e');
    }
  }

  /// Limpia todo el contenido de la hoja
  Future<bool> clearAll() async {
    _checkInitialization();

    try {
      final success = await _worksheet!.clear();
      return success;
    } catch (e) {
      throw Exception('Error al limpiar la hoja: $e');
    }
  }

  /// Obtiene información básica sobre la hoja
  Future<Map<String, dynamic>> getWorksheetInfo() async {
    _checkInitialization();

    try {
      final allRows = await getAllRows();

      return {
        'title': _worksheet!.title,
        'id': _worksheet!.id,
        'rowCount': allRows.length,
        'columnCount': allRows.isNotEmpty ? allRows[0].length : 0,
        'lastUpdate': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Error al obtener información de la hoja: $e');
    }
  }

  /// Getter para verificar si está inicializado
  bool get isInitialized => _isInitialized;

  /// Getter para obtener el título de la hoja
  String? get worksheetTitle => _worksheet?.title;
}