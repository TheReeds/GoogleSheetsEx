import 'package:flutter/material.dart';
import '../services/gsheet_services.dart';

class HomeScreen extends StatefulWidget {
  final GSheetsService gsheetsService;

  const HomeScreen(this.gsheetsService, {Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<List<String>> _data = [];
  bool _isLoading = true;
  final _controller = TextEditingController();
  final _editingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await widget.gsheetsService.getAllRows();
      setState(() {
        _data = data;
      });
    } catch (e) {
      _showSnackbar('Error al cargar los datos: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addRow() async {
    if (_controller.text.isEmpty) {
      _showSnackbar('Por favor ingrese un valor válido.');
      return;
    }
    final newRow = [_controller.text];
    try {
      final success = await widget.gsheetsService.insertRow(newRow);
      if (success) {
        _controller.clear();
        await _loadData();
        _showSnackbar('Fila añadida con éxito.');
      } else {
        _showSnackbar('Error al añadir la fila.');
      }
    } catch (e) {
      _showSnackbar('Error: $e');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  Future<void> _editCell(int rowIndex, int columnIndex, String currentValue) async {
    _editingController.text = currentValue;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar celda'),
        content: TextField(
          controller: _editingController,
          decoration: InputDecoration(
            labelText: 'Nuevo valor',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_editingController.text.isEmpty) {
                _showSnackbar('Por favor ingrese un valor válido.');
                return;
              }

              try {
                final success = await widget.gsheetsService.updateCell(
                  row: rowIndex,
                  column: columnIndex,
                  value: _editingController.text,
                );

                if (success) {
                  Navigator.pop(context);
                  await _loadData();
                  _showSnackbar('Celda actualizada con éxito.');
                } else {
                  _showSnackbar('Error al actualizar la celda.');
                }
              } catch (e) {
                _showSnackbar('Error: $e');
              }
            },
            child: Text('Guardar'),
          ),
        ],
      ),
    );
  }
  Future<void> _deleteRow(int rowIndex) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar eliminación'),
        content: Text('¿Está seguro de que desea eliminar esta fila?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final success = await widget.gsheetsService.deleteRow(rowIndex);
        if (success) {
          await _loadData();
          _showSnackbar('Fila eliminada con éxito.');
        } else {
          _showSnackbar('Error al eliminar la fila.');
        }
      } catch (e) {
        _showSnackbar('Error: $e');
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.table_chart, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No hay datos disponibles.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: _data.isNotEmpty
            ? _data[0]
            .map((header) => DataColumn(
          label: Text(
            header,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ))
            .toList()
            : [],
        rows: _data
            .skip(1) // Omitimos la primera fila si es encabezado
            .toList()
            .asMap()
            .entries
            .map((entry) {
          final rowIndex = entry.key + 1; // +1 porque saltamos la primera fila
          final row = entry.value;

          // Aseguramos que cada fila tenga el mismo número de celdas que las columnas
          while (row.length < _data[0].length) {
            row.add(""); // Rellenamos las celdas faltantes con una cadena vacía
          }

          return DataRow(
            cells: row
                .asMap()
                .entries
                .map((cellEntry) => DataCell(
              Text(cellEntry.value),
              onTap: () => _editCell(rowIndex, cellEntry.key, cellEntry.value),
            ))
                .toList(),
            onLongPress: () => _deleteRow(rowIndex),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Sheets App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: _data.isEmpty
            ? _buildEmptyState()
            : Column(
          children: [
            Expanded(child: _buildDataTable()),
            _buildInputSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Añadir nueva fila',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addRow,
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
