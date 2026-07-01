// lib/widgets/search_filter_bar.dart
import 'package:flutter/material.dart';

/// Barra de búsqueda reutilizable con filtros opcionales.
class SearchFilterBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final List<FilterChipData>? filterChips;
  final ValueChanged<String?>? onFilterChanged;
  final String? selectedFilter;

  const SearchFilterBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.filterChips,
    this.onFilterChanged,
    this.selectedFilter,
  });

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    final hasFilters = widget.filterChips != null && widget.filterChips!.isNotEmpty;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              // ── BUSCADOR ──
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  onChanged: widget.onChanged,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: widget.controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              widget.controller.clear();
                              widget.onChanged('');
                              widget.onClear?.call();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              if (hasFilters) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() => _showFilters = !_showFilters);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _showFilters
                          ? Colors.amber.shade400
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune,
                      color: _showFilters ? Colors.white : Colors.grey.shade700,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // ── CHIPS DE FILTRO (colapsable) ──
          if (hasFilters && _showFilters) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildChip(
                    label: 'Todos',
                    value: null,
                    selected: widget.selectedFilter == null,
                  ),
                  ...widget.filterChips!.map((chip) {
                    return _buildChip(
                      label: chip.label,
                      value: chip.value,
                      selected: widget.selectedFilter == chip.value,
                      color: chip.color,
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required String? value,
    required bool selected,
    Color? color,
  }) {
    final activeColor = color ?? Colors.amber;
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: activeColor.withOpacity(0.2),
      checkmarkColor: activeColor,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: selected ? activeColor : Colors.grey.shade300,
      ),
      onSelected: (_) {
        widget.onFilterChanged?.call(value);
      },
    );
  }
}

class FilterChipData {
  final String label;
  final String? value;
  final Color? color;

  const FilterChipData({
    required this.label,
    this.value,
    this.color,
  });
}
