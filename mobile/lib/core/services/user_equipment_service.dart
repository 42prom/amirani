import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/workout/domain/entities/workout_preferences_entity.dart';
import '../providers/storage_providers.dart';

/// Service for managing user-owned equipment (home workouts)
/// Equipment is stored locally and can be dynamically added/removed
class UserEquipmentService {
  static const String _equipmentKey = 'user_owned_equipment';
  static const String _lastUpdatedKey = 'equipment_last_updated';

  final SharedPreferences _prefs;

  UserEquipmentService(this._prefs);

  /// Get all equipment owned by the user
  List<Equipment> getOwnedEquipment() {
    final jsonStr = _prefs.getString(_equipmentKey);
    if (jsonStr == null) {
      // Default: bodyweight only
      return [Equipment.bodyweightOnly];
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonStr);
      return jsonList
          .map((e) => _parseEquipment(e as String))
          .whereType<Equipment>()
          .toList();
    } catch (e) {
      return [Equipment.bodyweightOnly];
    }
  }

  /// Add equipment to user's collection
  Future<void> addEquipment(Equipment equipment) async {
    final current = getOwnedEquipment();
    if (!current.contains(equipment)) {
      current.add(equipment);
      // Remove bodyweight only if adding real equipment
      if (equipment != Equipment.bodyweightOnly && current.contains(Equipment.bodyweightOnly)) {
        // Keep bodyweight, it's always available
      }
      await _saveEquipment(current);
    }
  }

  /// Remove equipment from user's collection
  Future<void> removeEquipment(Equipment equipment) async {
    final current = getOwnedEquipment();
    current.remove(equipment);
    // Always keep at least bodyweight
    if (current.isEmpty) {
      current.add(Equipment.bodyweightOnly);
    }
    await _saveEquipment(current);
  }

  /// Set all equipment at once
  Future<void> setEquipment(List<Equipment> equipment) async {
    final toSave = equipment.isEmpty ? [Equipment.bodyweightOnly] : equipment;
    await _saveEquipment(toSave);
  }

  /// Check if user owns specific equipment
  bool hasEquipment(Equipment equipment) {
    return getOwnedEquipment().contains(equipment);
  }

  /// Clear all equipment (reset to bodyweight only)
  Future<void> clearEquipment() async {
    await _saveEquipment([Equipment.bodyweightOnly]);
  }

  /// Get last updated timestamp
  DateTime? getLastUpdated() {
    final millis = _prefs.getInt(_lastUpdatedKey);
    return millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
  }

  Future<void> _saveEquipment(List<Equipment> equipment) async {
    final jsonList = equipment.map((e) => e.name).toList();
    await _prefs.setString(_equipmentKey, json.encode(jsonList));
    await _prefs.setInt(_lastUpdatedKey, DateTime.now().millisecondsSinceEpoch);
  }

  Equipment? _parseEquipment(String name) {
    try {
      return Equipment.values.firstWhere(
        (e) => e.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
}

/// Equipment display information
class EquipmentInfo {
  final Equipment equipment;
  final String displayName;
  final String description;
  final String emoji;
  final bool isHomeCommon;
  final bool isGymOnly;

  const EquipmentInfo({
    required this.equipment,
    required this.displayName,
    required this.description,
    required this.emoji,
    this.isHomeCommon = false,
    this.isGymOnly = false,
  });

  /// Get display info for all equipment
  static List<EquipmentInfo> get all => [
    const EquipmentInfo(
      equipment: Equipment.bodyweightOnly,
      displayName: 'Bodyweight',
      description: 'No equipment needed',
      emoji: '🧍',
      isHomeCommon: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.dumbbells,
      displayName: 'Dumbbells',
      description: 'Adjustable or fixed weight dumbbells',
      emoji: '🏋️',
      isHomeCommon: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.resistanceBands,
      displayName: 'Resistance Bands',
      description: 'Elastic bands for resistance training',
      emoji: '🎗️',
      isHomeCommon: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.pullUpBar,
      displayName: 'Pull-up Bar',
      description: 'Door-mounted or wall-mounted bar',
      emoji: '🔩',
      isHomeCommon: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.jumpRope,
      displayName: 'Jump Rope',
      description: 'Great for cardio and conditioning',
      emoji: '⭕',
      isHomeCommon: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.kettlebell,
      displayName: 'Kettlebell',
      description: 'Cast iron weight for dynamic exercises',
      emoji: '🔔',
      isHomeCommon: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.yogaMat,
      displayName: 'Yoga Mat',
      description: 'For floor exercises and stretching',
      emoji: '🧘',
      isHomeCommon: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.bench,
      displayName: 'Workout Bench',
      description: 'Flat or adjustable bench',
      emoji: '🛋️',
      isHomeCommon: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.stabilityBall,
      displayName: 'Stability Ball',
      description: 'For core and balance training',
      emoji: '⚽',
      isHomeCommon: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.medicineBall,
      displayName: 'Medicine Ball',
      description: 'Weighted ball for power training',
      emoji: '🏀',
      isHomeCommon: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.foamRoller,
      displayName: 'Foam Roller',
      description: 'For muscle recovery and mobility',
      emoji: '🧱',
      isHomeCommon: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.abWheel,
      displayName: 'Ab Wheel',
      description: 'For core strengthening exercises',
      emoji: '🎡',
      isHomeCommon: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.trxStraps,
      displayName: 'TRX/Suspension',
      description: 'Suspension training straps',
      emoji: '🪢',
      isHomeCommon: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.parallelBars,
      displayName: 'Parallel Bars',
      description: 'For dips and upper body exercises',
      emoji: '🤸',
      isHomeCommon: false,
    ),
    const EquipmentInfo(
      equipment: Equipment.weightedVest,
      displayName: 'Weighted Vest',
      description: 'Add resistance to bodyweight exercises',
      emoji: '🦺',
      isHomeCommon: false,
    ),
    const EquipmentInfo(
      equipment: Equipment.ankleWeights,
      displayName: 'Ankle Weights',
      description: 'Wearable weights for legs',
      emoji: '⚓',
      isHomeCommon: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.battleRopes,
      displayName: 'Battle Ropes',
      description: 'Heavy ropes for HIIT training',
      emoji: '🪢',
      isHomeCommon: false,
    ),
    const EquipmentInfo(
      equipment: Equipment.barbell,
      displayName: 'Barbell',
      description: 'Olympic or standard barbell',
      emoji: '🏋️‍♂️',
      isGymOnly: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.machines,
      displayName: 'Gym Machines',
      description: 'Cable machines, leg press, etc.',
      emoji: '🎰',
      isGymOnly: true,
    ),
    const EquipmentInfo(
      equipment: Equipment.cables,
      displayName: 'Cable System',
      description: 'Cable crossover and pulley systems',
      emoji: '🔗',
      isGymOnly: true,
    ),
  ];

  /// Get info for specific equipment
  static EquipmentInfo? getInfo(Equipment equipment) {
    try {
      return all.firstWhere((e) => e.equipment == equipment);
    } catch (e) {
      return null;
    }
  }

  /// Get common home equipment options
  static List<EquipmentInfo> get homeEquipment =>
      all.where((e) => e.isHomeCommon && !e.isGymOnly).toList();

  /// Get gym-only equipment
  static List<EquipmentInfo> get gymEquipment =>
      all.where((e) => e.isGymOnly).toList();
}

/// State for user equipment
class UserEquipmentState {
  final List<Equipment> ownedEquipment;
  final bool isLoading;
  final DateTime? lastUpdated;

  const UserEquipmentState({
    this.ownedEquipment = const [Equipment.bodyweightOnly],
    this.isLoading = false,
    this.lastUpdated,
  });

  UserEquipmentState copyWith({
    List<Equipment>? ownedEquipment,
    bool? isLoading,
    DateTime? lastUpdated,
  }) {
    return UserEquipmentState(
      ownedEquipment: ownedEquipment ?? this.ownedEquipment,
      isLoading: isLoading ?? this.isLoading,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  bool hasEquipment(Equipment equipment) => ownedEquipment.contains(equipment);
}

final userEquipmentServiceProvider = Provider<UserEquipmentService?>((ref) {
  return UserEquipmentService(ref.watch(sharedPreferencesProvider));
});

/// StateNotifier for managing user equipment (in-memory by default)
class UserEquipmentNotifier extends StateNotifier<UserEquipmentState> {
  final UserEquipmentService? _service;

  UserEquipmentNotifier([this._service]) : super(const UserEquipmentState()) {
    _loadEquipment();
  }

  void _loadEquipment() {
    if (_service == null) {
      // Default state - bodyweight only
      state = const UserEquipmentState(
        ownedEquipment: [Equipment.bodyweightOnly],
        isLoading: false,
      );
      return;
    }
    state = state.copyWith(isLoading: true);
    final equipment = _service.getOwnedEquipment();
    final lastUpdated = _service.getLastUpdated();
    state = UserEquipmentState(
      ownedEquipment: equipment,
      isLoading: false,
      lastUpdated: lastUpdated,
    );
  }

  Future<void> addEquipment(Equipment equipment) async {
    if (_service != null) {
      await _service.addEquipment(equipment);
      _loadEquipment();
    } else {
      // In-memory update
      final newList = [...state.ownedEquipment];
      if (!newList.contains(equipment)) {
        newList.add(equipment);
      }
      state = state.copyWith(ownedEquipment: newList);
    }
  }

  Future<void> removeEquipment(Equipment equipment) async {
    if (_service != null) {
      await _service.removeEquipment(equipment);
      _loadEquipment();
    } else {
      // In-memory update
      final newList = state.ownedEquipment.where((e) => e != equipment).toList();
      if (newList.isEmpty) newList.add(Equipment.bodyweightOnly);
      state = state.copyWith(ownedEquipment: newList);
    }
  }

  Future<void> setEquipment(List<Equipment> equipment) async {
    if (_service != null) {
      await _service.setEquipment(equipment);
      _loadEquipment();
    } else {
      // In-memory update
      final toSave = equipment.isEmpty ? [Equipment.bodyweightOnly] : equipment;
      state = state.copyWith(ownedEquipment: toSave);
    }
  }

  Future<void> toggleEquipment(Equipment equipment) async {
    if (state.hasEquipment(equipment)) {
      await removeEquipment(equipment);
    } else {
      await addEquipment(equipment);
    }
  }

  Future<void> clearAll() async {
    if (_service != null) {
      await _service.clearEquipment();
      _loadEquipment();
    } else {
      state = state.copyWith(ownedEquipment: [Equipment.bodyweightOnly]);
    }
  }
}

/// Provider for UserEquipmentNotifier
final userEquipmentProvider =
    StateNotifierProvider<UserEquipmentNotifier, UserEquipmentState>((ref) {
  final service = ref.watch(userEquipmentServiceProvider);
  return UserEquipmentNotifier(service);
});
