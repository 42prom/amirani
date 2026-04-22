import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/data/exercise_database.dart';
import '../../../../core/services/workout_plan_storage_service.dart';
import '../../domain/entities/monthly_workout_plan_entity.dart';

class ExerciseSearchModal extends ConsumerStatefulWidget {
  final PlannedExerciseEntity oldExercise;
  final DateTime date;

  const ExerciseSearchModal({
    super.key,
    required this.oldExercise,
    required this.date,
  });

  @override
  ConsumerState<ExerciseSearchModal> createState() => _ExerciseSearchModalState();
}

class _ExerciseSearchModalState extends ConsumerState<ExerciseSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  List<ExerciseData> _searchResults = [];

  @override
  void initState() {
    super.initState();
    // Initialize with all exercises or a subset
    _searchResults = ExerciseDatabase.instance.allExercises.take(10).toList();
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchResults = ExerciseDatabase.instance.allExercises.take(10).toList();
      } else {
        _searchResults = ExerciseDatabase.instance.search(query);
      }
    });
  }

  Future<void> _performSwap(ExerciseData newExData) async {
    final storage = ref.read(workoutPlanStorageProvider);
    
    // Create new PlannedExerciseEntity from ExerciseData
    final newPlannedExercise = PlannedExerciseEntity(
      id: newExData.id,
      name: newExData.name,
      description: newExData.description,
      targetMuscles: newExData.primaryMuscles,
      difficulty: newExData.difficulty,
      sets: widget.oldExercise.sets.map((s) => s.copyWith(isCompleted: false)).toList(),
      requiredEquipment: newExData.requiredEquipment,
      videoUrl: newExData.videoUrl,
      imageUrl: newExData.imageUrl,
      instructions: newExData.instructions.join('\n'),
    );

    final success = await storage.swapExercise(
      date: widget.date,
      oldExerciseId: widget.oldExercise.id,
      newExercise: newPlannedExercise,
    );

    if (success && mounted) {
      ref.invalidate(savedWorkoutPlanProvider);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text(
                  "Swap Exercise",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(24),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search exercises...",
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBrand),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          
          // Results
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final ex = _searchResults[index];
                return _buildExerciseResultCard(ex);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseResultCard(ExerciseData ex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryBrand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fitness_center, color: AppTheme.primaryBrand, size: 20),
          ),
          title: Text(
            ex.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            ex.primaryMuscles.map((m) => m.name[0].toUpperCase() + m.name.substring(1)).join(', '),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  // The requested 250x250 media preview
                  _buildMediaPreview(ex.videoUrl),
                  const SizedBox(height: 16),
                  Text(
                    ex.description,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _performSwap(ex),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBrand,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text("Select Exercise", style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(String? url) {
    return Container(
      height: 250,
      width: 250,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBrand.withValues(alpha: 0.1),
            blurRadius: 15,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.videocam_off_outlined, color: Colors.white24, size: 40),
                ),
              )
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off_outlined, color: Colors.white24, size: 40),
                    SizedBox(height: 8),
                    Text("No animation available", style: TextStyle(color: Colors.white24, fontSize: 10)),
                  ],
                ),
              ),
      ),
    );
  }
}
