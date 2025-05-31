// lib/data/repositories/calculation_data_repository_impl.dart
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart';
import 'package:diabetes_2/data/repositories/calculation_data_repository.dart';
import 'package:diabetes_2/core/services/supabase_log_sync_service.dart';
import 'package:diabetes_2/main.dart' show supabase; // Para supabase.auth.currentUser
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

// Usaremos la misma clave que definimos en LogRepositoryImpl o en un lugar central.
// Por consistencia, la definiré aquí de nuevo, pero idealmente sería una constante global.
const String cloudSavePreferenceKeyFromCalcRepo = 'saveToCloudEnabled';

class CalculationDataRepositoryImpl implements CalculationDataRepository {
  final Box<DailyCalculationData> _dailyCalculationsBox;
  final SupabaseLogSyncService _supabaseLogSyncService;
  final SharedPreferences _sharedPreferences;

  CalculationDataRepositoryImpl({
    required Box<DailyCalculationData> dailyCalculationsBox,
    required SupabaseLogSyncService supabaseLogSyncService,
    required SharedPreferences sharedPreferences,
  })  : _dailyCalculationsBox = dailyCalculationsBox,
        _supabaseLogSyncService = supabaseLogSyncService,
        _sharedPreferences = sharedPreferences;

  @override
  Future<DailyCalculationData?> getDailyCalculation(String dateKey) async {
    return _dailyCalculationsBox.get(dateKey);
  }

  @override
  Future<void> saveDailyCalculation(String dateKey, DailyCalculationData data) async {
    await _dailyCalculationsBox.put(dateKey, data);
    debugPrint("CalculationDataRepository: DailyCalculationData para '$dateKey' guardado en Hive.");

    final bool cloudSaveEnabled = _sharedPreferences.getBool(cloudSavePreferenceKeyFromCalcRepo) ?? false;
    final bool isLoggedIn = supabase.auth.currentUser != null;

    if (cloudSaveEnabled && isLoggedIn) {
      try {
        await _supabaseLogSyncService.syncDailyCalculation(data);
        debugPrint("CalculationDataRepository: DailyCalculationData para '$dateKey' sincronizado con Supabase.");
      } catch (e) {
        debugPrint("CalculationDataRepository: Error sincronizando DailyCalculationData para '$dateKey': $e");
        // Considera no relanzar para no fallar la operación de guardado local.
      }
    } else {
      String reason = !cloudSaveEnabled ? "guardado en la nube desactivado" : "usuario no logueado";
      debugPrint("CalculationDataRepository: DailyCalculationData para '$dateKey' NO sincronizado ($reason).");
    }
  }

  @override
  Future<List<DailyCalculationData>> getDailyCalculationsInDateRange(DateTime startDate, DateTime endDate) async {
    return _dailyCalculationsBox.values.where((calc) {
      // Asegurarse de que las comparaciones de fechas sean solo a nivel de día
      final calcDate = DateTime(calc.date.year, calc.date.month, calc.date.day);
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      return !calcDate.isBefore(start) && !calcDate.isAfter(end);
    }).toList();
  }
}