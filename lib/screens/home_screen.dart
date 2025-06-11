import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/gsheet_services.dart';

class HomeScreen extends StatefulWidget {
  final GSheetsService gsheetsService;

  const HomeScreen(this.gsheetsService, {Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<List<String>> _data = [];
  bool _isLoading = true;
  bool _isAddingRow = false;
  bool _isLoadingMore = false;
  final _controller = TextEditingController();
  final _editingController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _horizontalScrollController = ScrollController();

  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 50; // Mostrar 50 filas por página
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Añadir listener para scroll infinito
    _scrollController.addListener(_onScroll);

    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    _editingController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _horizontalScrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
    });
    try {
      final data = await widget.gsheetsService.getAllRows();
      setState(() {
        _data = data;
      });
      _animationController.forward();
    } catch (e) {
      _showSnackbar('Error al cargar los datos: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore) return;

    final filteredData = _filteredData;
    final totalPages = (filteredData.length / _itemsPerPage).ceil();

    if (_currentPage >= totalPages - 1) return; // No hay más datos

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    // Simular delay para mostrar loading
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isLoadingMore = false;
    });
  }

  Future<void> _addRow() async {
    if (_controller.text.trim().isEmpty) {
      _showSnackbar('Por favor ingrese un valor válido.', isError: true);
      return;
    }

    setState(() {
      _isAddingRow = true;
    });

    final newRow = [_controller.text.trim()];
    try {
      final success = await widget.gsheetsService.insertRow(newRow);
      if (success) {
        _controller.clear();
        await _loadData();
        _showSnackbar('Fila añadida con éxito.', icon: Icons.check_circle);
        HapticFeedback.lightImpact();
      } else {
        _showSnackbar('Error al añadir la fila.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Error: $e', isError: true);
    } finally {
      setState(() {
        _isAddingRow = false;
      });
    }
  }

  void _showSnackbar(String message, {bool isError = false, IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon ?? (isError ? Icons.error_outline : Icons.info_outline),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: isError ? 4 : 2),
        action: SnackBarAction(
          label: 'Cerrar',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _editCell(int rowIndex, int columnIndex, String currentValue) async {
    _editingController.text = currentValue;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.edit, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('Editar celda'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _editingController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nuevo valor',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.text_fields),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context, value.trim());
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Valor actual: "$currentValue"',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (_editingController.text.trim().isNotEmpty) {
                Navigator.pop(context, _editingController.text.trim());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != null && result != currentValue) {
      try {
        final success = await widget.gsheetsService.updateCell(
          row: rowIndex,
          column: columnIndex,
          value: result,
        );

        if (success) {
          await _loadData();
          _showSnackbar('Celda actualizada con éxito.', icon: Icons.check_circle);
          HapticFeedback.lightImpact();
        } else {
          _showSnackbar('Error al actualizar la celda.', isError: true);
        }
      } catch (e) {
        _showSnackbar('Error: $e', isError: true);
      }
    }
  }

  Future<void> _deleteRow(int rowIndex) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Confirmar eliminación'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Está seguro de que desea eliminar esta fila?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: const Text(
                'Esta acción no se puede deshacer.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red[600],
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final success = await widget.gsheetsService.deleteRow(rowIndex);
        if (success) {
          await _loadData();
          _showSnackbar('Fila eliminada con éxito.', icon: Icons.delete_outline);
          HapticFeedback.mediumImpact();
        } else {
          _showSnackbar('Error al eliminar la fila.', isError: true);
        }
      } catch (e) {
        _showSnackbar('Error: $e', isError: true);
      }
    }
  }

  List<List<String>> get _filteredData {
    if (_searchQuery.isEmpty || _data.isEmpty) return _data;

    return _data.where((row) {
      return row.any((cell) =>
          cell.toLowerCase().contains(_searchQuery.toLowerCase())
      );
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.table_chart_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No hay datos disponibles',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Añade tu primera fila para comenzar',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar en los datos...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _currentPage = 0; // Resetear paginación al buscar
          });
        },
      ),
    );
  }

  Widget _buildDataTable() {
    final filteredData = _filteredData;

    if (filteredData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No se encontraron resultados',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            ),
            columns: filteredData.isNotEmpty
                ? filteredData[0]
                .asMap()
                .entries
                .map((entry) => DataColumn(
              label: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  entry.value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ))
                .toList()
                : [],
            rows: filteredData
                .skip(1)
                .toList()
                .asMap()
                .entries
                .map((entry) {
              final rowIndex = _data.indexOf(entry.value);
              final row = entry.value;

              // Asegurar que cada fila tenga el mismo número de celdas
              while (row.length < filteredData[0].length) {
                row.add("");
              }

              return DataRow(
                color: MaterialStateProperty.resolveWith<Color?>(
                      (Set<MaterialState> states) {
                    if (entry.key % 2 == 0) {
                      return Theme.of(context).colorScheme.surface;
                    }
                    return null;
                  },
                ),
                cells: row
                    .asMap()
                    .entries
                    .map((cellEntry) => DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      cellEntry.value,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  onTap: () => _editCell(rowIndex, cellEntry.key, cellEntry.value),
                ))
                    .toList(),
                onLongPress: () => _deleteRow(rowIndex),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Añadir nueva fila',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ingresa el contenido...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.add_box_outlined),
                      ),
                      onSubmitted: (_) => _addRow(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isAddingRow ? null : _addRow,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isAddingRow
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Toca una celda para editarla, mantén presionada una fila para eliminarla',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),

              // Controles de navegación para grandes datasets
              if (_filteredData.length > _itemsPerPage) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _currentPage > 0
                            ? () {
                          setState(() {
                            _currentPage = 0;
                          });
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                            : null,
                        icon: const Icon(Icons.first_page, size: 18),
                        label: const Text('Inicio', style: TextStyle(fontSize: 12)),
                      ),

                      Text(
                        'Total: ${_filteredData.length - 1} filas',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      TextButton.icon(
                        onPressed: () {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                        label: const Text('Más', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Google Sheets App',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando datos...'),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadData,
        child: _data.isEmpty
            ? _buildEmptyState()
            : Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildDataTable()),
            _buildInputSection(),
          ],
        ),
      ),
    );
  }
}