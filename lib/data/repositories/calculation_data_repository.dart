// lib/data/repositories/calculation_data_repository.dart
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart';

abstract class CalculationDataRepository {
  Future<DailyCalculationData?> getDailyCalculation(String dateKey); // dateKey es 'yyyy-MM-dd'
  Future<void> saveDailyCalculation(String dateKey, DailyCalculationData data);
  Future<List<DailyCalculationData>> getDailyCalculationsInDateRange(DateTime startDate, DateTime endDate);
// Podrías añadir más métodos si los necesitas, como deleteAll, etc.
}