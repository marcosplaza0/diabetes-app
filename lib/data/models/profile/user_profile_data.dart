import 'package:hive/hive.dart';

part 'user_profile_data.g.dart'; // Será generado por build_runner

@HiveType(typeId: 2) // Usa un typeId único (0 y 1 ya están por tus logs)
class UserProfileData extends HiveObject {
  @HiveField(0)
  String? username;

  @HiveField(1)
  String? email;

  @HiveField(2)
  String? avatarCacheKey; // Será el filePath usado como clave en ImageCacheService

  UserProfileData({this.username, this.email, this.avatarCacheKey});
}