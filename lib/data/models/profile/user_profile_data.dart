// lib/data/models/profile/user_profile_data.dart
import 'package:hive/hive.dart';

part 'user_profile_data.g.dart'; // Será generado por build_runner

@HiveType(typeId: 2) // El typeId se mantiene
class UserProfileData extends HiveObject {
  @HiveField(0)
  String? username;

  @HiveField(1)
  String? email;

  @HiveField(2)
  String? avatarCacheKey;

  @HiveField(3) // Nuevo índice para el nuevo campo
  String? gender; // Nuevo campo

  UserProfileData({
    this.username,
    this.email,
    this.avatarCacheKey,
    this.gender, // Añadir al constructor
  });
}