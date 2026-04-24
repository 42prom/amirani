import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../design_system/tokens/app_tokens.dart';
import '../../data/models/food_models.dart';
import '../providers/food_provider.dart';

class FoodSearchPage extends ConsumerStatefulWidget {
  final String mealType;
  final String diaryDate;

  const FoodSearchPage({
    super.key,
    required this.mealType,
    required this.diaryDate,
  });

  @override
  ConsumerState<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends ConsumerState<FoodSearchPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _showScanner = false;
  MobileScannerController? _scannerController;
  bool _scannedThisSession = false;

  static const _mealTypes = ['BREAKFAST', 'LUNCH', 'DINNER', 'SNACK'];
  late String _selectedMealType;

  @override
  void initState() {
    super.initState();
    _selectedMealType = _mealTypes.contains(widget.mealType.toUpperCase())
        ? widget.mealType.toUpperCase()
        : 'SNACK';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _scannerController?.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(foodSearchProvider.notifier).search(q);
    });
  }

  void _startScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    setState(() {
      _showScanner = true;
      _scannedThisSession = false;
    });
  }

  void _stopScanner() {
    _scannerController?.dispose();
    _scannerController = null;
    setState(() => _showScanner = false);
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_scannedThisSession) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null) return;
    _scannedThisSession = true;
    HapticFeedback.mediumImpact();
    _stopScanner();

    final result = await ref.read(foodSearchProvider.notifier).lookupBarcode(barcode);
    if (!mounted) return;
    if (result != null) {
      _showAddFoodSheet(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No food found for that barcode'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showAddFoodSheet(FoodSearchResult food) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.colorBgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddFoodSheet(
        food: food,
        mealType: _selectedMealType,
        diaryDate: widget.diaryDate,
        onLogged: () {
          Navigator.pop(ctx);
          Navigator.pop(context, true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(foodSearchProvider);

    return Scaffold(
      backgroundColor: AppTokens.colorBgPrimary,
      appBar: AppBar(
        backgroundColor: AppTokens.colorBgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Log Food',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showScanner ? Icons.close : Icons.qr_code_scanner,
              color: AppTokens.colorBrand,
            ),
            onPressed: _showScanner ? _stopScanner : _startScanner,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMealTypeSelector(),
          _buildSearchBar(),
          if (_showScanner) _buildScanner() else Expanded(child: _buildResults(searchState)),
        ],
      ),
    );
  }

  Widget _buildMealTypeSelector() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _mealTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = _mealTypes[i];
          final selected = t == _selectedMealType;
          return GestureDetector(
            onTap: () => setState(() => _selectedMealType = t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppTokens.colorBrand
                    : AppTokens.colorBgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppTokens.colorBrand
                      : AppTokens.colorBorderSubtle,
                ),
              ),
              child: Text(
                _capitalize(t),
                style: TextStyle(
                  color: selected ? Colors.black : AppTokens.colorTextSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        autofocus: !_showScanner,
        style: const TextStyle(color: Colors.white),
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search food...',
          hintStyle: TextStyle(color: AppTokens.colorTextSecondary),
          prefixIcon: Icon(Icons.search, color: AppTokens.colorTextSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, color: AppTokens.colorTextSecondary, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(foodSearchProvider.notifier).clear();
                  },
                )
              : null,
          filled: true,
          fillColor: AppTokens.colorBgSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTokens.colorBorderSubtle),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTokens.colorBorderSubtle),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTokens.colorBrand),
          ),
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController!,
                onDetect: _onBarcodeDetected,
              ),
              Center(
                child: Container(
                  width: 240,
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTokens.colorBrand, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Text(
                  'Point camera at barcode',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(FoodSearchState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTokens.colorBrand),
      );
    }

    if (state.error != null) {
      return Center(
        child: Text(
          'Search failed. Please try again.',
          style: TextStyle(color: AppTokens.colorTextSecondary),
        ),
      );
    }

    if (state.query.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: AppTokens.colorTextSecondary),
            const SizedBox(height: 12),
            Text(
              'Search by name or scan a barcode',
              style: TextStyle(color: AppTokens.colorTextSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (state.results.isEmpty) {
      return Center(
        child: Text(
          'No results for "${state.query}"',
          style: TextStyle(color: AppTokens.colorTextSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: state.results.length,
      separatorBuilder: (_, __) => Divider(
        color: AppTokens.colorBorderSubtle,
        height: 1,
      ),
      itemBuilder: (_, i) => _FoodResultTile(
        food: state.results[i],
        onTap: () => _showAddFoodSheet(state.results[i]),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0] + s.substring(1).toLowerCase();
}

// ── Result tile ───────────────────────────────────────────────────────────────

class _FoodResultTile extends StatelessWidget {
  final FoodSearchResult food;
  final VoidCallback onTap;

  const _FoodResultTile({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      onTap: onTap,
      title: Text(
        food.name,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        'per 100g · ${food.calories.toStringAsFixed(0)} kcal  P${food.protein.toStringAsFixed(0)}g  C${food.carbs.toStringAsFixed(0)}g  F${food.fats.toStringAsFixed(0)}g',
        style: TextStyle(color: AppTokens.colorTextSecondary, fontSize: 12),
      ),
      trailing: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTokens.colorBrand.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.add, color: AppTokens.colorBrand, size: 18),
      ),
    );
  }
}

// ── Add food sheet ────────────────────────────────────────────────────────────

class _AddFoodSheet extends ConsumerStatefulWidget {
  final FoodSearchResult food;
  final String mealType;
  final String diaryDate;
  final VoidCallback onLogged;

  const _AddFoodSheet({
    required this.food,
    required this.mealType,
    required this.diaryDate,
    required this.onLogged,
  });

  @override
  ConsumerState<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends ConsumerState<_AddFoodSheet> {
  late TextEditingController _gramsCtrl;
  double _grams = 100;

  @override
  void initState() {
    super.initState();
    _grams = widget.food.servingGrams;
    _gramsCtrl = TextEditingController(text: _grams.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _gramsCtrl.dispose();
    super.dispose();
  }

  FoodSearchResult get _scaled => widget.food.copyWith(servingGrams: _grams);

  void _onGramsChanged(String v) {
    final parsed = double.tryParse(v);
    if (parsed != null && parsed > 0) {
      setState(() => _grams = parsed);
    }
  }

  Future<void> _log() async {
    final ok = await ref.read(foodLogProvider.notifier).logFood(
          food: widget.food,
          mealType: widget.mealType,
          grams: _grams,
          diaryDate: widget.diaryDate,
        );
    if (!mounted) return;
    if (ok) {
      widget.onLogged();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to log food'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logState = ref.watch(foodLogProvider);
    final isLogging = logState is AsyncLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.food.name,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _gramsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  onChanged: _onGramsChanged,
                  decoration: InputDecoration(
                    labelText: 'Grams',
                    labelStyle: TextStyle(color: AppTokens.colorTextSecondary),
                    suffix: Text('g', style: TextStyle(color: AppTokens.colorTextSecondary)),
                    filled: true,
                    fillColor: AppTokens.colorBgPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTokens.colorBorderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTokens.colorBrand),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTokens.colorBorderSubtle),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTokens.colorBgPrimary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTokens.colorBorderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroChip(label: 'Kcal', value: _scaled.scaledCalories, color: AppTokens.colorBrand),
                _MacroChip(label: 'Protein', value: _scaled.scaledProtein, color: const Color(0xFF4FC3F7)),
                _MacroChip(label: 'Carbs', value: _scaled.scaledCarbs, color: const Color(0xFFA5D6A7)),
                _MacroChip(label: 'Fat', value: _scaled.scaledFats, color: const Color(0xFFFFCC80)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLogging ? null : _log,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.colorBrand,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor: AppTokens.colorBrand.withValues(alpha: 0.4),
              ),
              child: isLogging
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Add to Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toStringAsFixed(0),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: AppTokens.colorTextSecondary, fontSize: 11)),
      ],
    );
  }
}
