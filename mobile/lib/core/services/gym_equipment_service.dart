import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../features/workout/domain/entities/workout_preferences_entity.dart';
import '../network/dio_provider.dart';

/// Represents equipment available at a specific gym
class GymEquipmentInventory {
  final String gymId;
  final String gymName;
  final List<GymEquipmentItem> equipment;
  final DateTime lastUpdated;

  const GymEquipmentInventory({
    required this.gymId,
    required this.gymName,
    required this.equipment,
    required this.lastUpdated,
  });

  factory GymEquipmentInventory.fromJson(Map<String, dynamic> json) {
    return GymEquipmentInventory(
      gymId: json['gymId']?.toString() ?? '',
      gymName: json['gymName']?.toString() ?? '',
      lastUpdated: DateTime.tryParse(json['lastUpdated']?.toString() ?? '') ?? DateTime.now(),
      equipment: ((json['equipment'] as List<dynamic>?) ?? [])
          .map((e) => GymEquipmentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Get list of Equipment enums available at this gym
  List<Equipment> get availableEquipment =>
      equipment.where((e) => e.isAvailable).map((e) => e.type).toList();

  /// Get list of display names for out-of-order equipment
  List<String> get outOfOrderMachines =>
      equipment.where((e) => !e.isAvailable).map((e) => e.displayName).toList();

  /// Check if specific equipment is available
  bool hasEquipment(Equipment type) =>
      equipment.any((e) => e.type == type && e.isAvailable);
}

/// Individual equipment item in a gym
class GymEquipmentItem {
  final Equipment type;
  final String displayName;
  final int quantity;
  final bool isAvailable;
  final String? notes;
  final String? location; // e.g., "Floor 2", "Free Weights Section"

  const GymEquipmentItem({
    required this.type,
    required this.displayName,
    this.quantity = 1,
    this.isAvailable = true,
    this.notes,
    this.location,
  });

  factory GymEquipmentItem.fromJson(Map<String, dynamic> json) {
    return GymEquipmentItem(
      type: Equipment.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => Equipment.machines,
      ),
      displayName: json['displayName']?.toString() ?? '',
      quantity: json['quantity'] as int? ?? 1,
      isAvailable: json['isAvailable'] as bool? ?? true,
      notes: json['notes'] as String?,
      location: json['location'] as String?,
    );
  }
}

/// Service for managing gym equipment inventory
class GymEquipmentService {
  final Dio _dio;
  final Logger _logger = Logger();

  GymEquipmentService({required Dio dio}) : _dio = dio;

  /// Get equipment inventory for a specific gym
  Future<GymEquipmentInventory?> getGymEquipment(String gymId) async {
    final allGyms = await getUserGymEquipment('current_user'); // ID is ignored by API
    try {
      return allGyms.firstWhere((g) => g.gymId == gymId);
    } catch (_) {
      return null;
    }
  }

  /// Get equipment for user's joined gyms
  Future<List<GymEquipmentInventory>> getUserGymEquipment(String userId) async {
    try {
      final response = await _dio.get('/sync/equipment');
      if (response.statusCode == 200) {
        final data = response.data['data'] as List<dynamic>;
        return data.map((json) => GymEquipmentInventory.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('Failed to load gym equipment: $e');
      return [];
    }
  }


  /// Combine equipment from multiple gyms
  List<Equipment> getCombinedEquipment(List<GymEquipmentInventory> gyms) {
    final combined = <Equipment>{};
    for (final gym in gyms) {
      combined.addAll(gym.availableEquipment);
    }
    return combined.toList();
  }
}

/// State for gym equipment
class GymEquipmentState {
  final List<GymEquipmentInventory> joinedGyms;
  final GymEquipmentInventory? selectedGym;
  final bool isLoading;
  final String? error;

  const GymEquipmentState({
    this.joinedGyms = const [],
    this.selectedGym,
    this.isLoading = false,
    this.error,
  });

  GymEquipmentState copyWith({
    List<GymEquipmentInventory>? joinedGyms,
    GymEquipmentInventory? selectedGym,
    bool? isLoading,
    String? error,
  }) {
    return GymEquipmentState(
      joinedGyms: joinedGyms ?? this.joinedGyms,
      selectedGym: selectedGym ?? this.selectedGym,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Get all available equipment from selected gym or all joined gyms
  List<Equipment> get availableEquipment {
    if (selectedGym != null) {
      return selectedGym!.availableEquipment;
    }
    // Combine from all gyms
    final combined = <Equipment>{Equipment.bodyweightOnly};
    for (final gym in joinedGyms) {
      combined.addAll(gym.availableEquipment);
    }
    return combined.toList();
  }

  /// Get all out-of-order equipment names from selected gym or all joined gyms
  List<String> get outOfOrderMachines {
    if (selectedGym != null) {
      return selectedGym!.outOfOrderMachines;
    }
    // Combine from all gyms
    final combined = <String>{};
    for (final gym in joinedGyms) {
      combined.addAll(gym.outOfOrderMachines);
    }
    return combined.toList();
  }
}

/// Notifier for gym equipment state
class GymEquipmentNotifier extends StateNotifier<GymEquipmentState> {
  final GymEquipmentService _service;

  GymEquipmentNotifier(this._service) : super(const GymEquipmentState());

  Future<void> loadUserGyms(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final gyms = await _service.getUserGymEquipment(userId);
      state = state.copyWith(
        joinedGyms: gyms,
        isLoading: false,
        selectedGym: gyms.isNotEmpty ? gyms.first : null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadGymEquipment(String gymId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final gym = await _service.getGymEquipment(gymId);
      if (gym != null) {
        final updatedGyms = [...state.joinedGyms];
        final existingIndex = updatedGyms.indexWhere((g) => g.gymId == gymId);
        if (existingIndex >= 0) {
          updatedGyms[existingIndex] = gym;
        } else {
          updatedGyms.add(gym);
        }
        state = state.copyWith(
          joinedGyms: updatedGyms,
          selectedGym: gym,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void selectGym(String gymId) {
    final gym = state.joinedGyms.firstWhere(
      (g) => g.gymId == gymId,
      orElse: () => state.joinedGyms.first,
    );
    state = state.copyWith(selectedGym: gym);
  }

  void clearSelection() {
    state = state.copyWith(selectedGym: null);
  }
}

/// Provider for gym equipment service
final gymEquipmentServiceProvider = Provider<GymEquipmentService>((ref) {
  return GymEquipmentService(dio: ref.watch(dioProvider));
});

/// Provider for gym equipment state
final gymEquipmentProvider =
    StateNotifierProvider<GymEquipmentNotifier, GymEquipmentState>((ref) {
  final service = ref.watch(gymEquipmentServiceProvider);
  return GymEquipmentNotifier(service);
});
