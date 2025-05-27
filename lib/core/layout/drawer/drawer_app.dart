import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:diabetes_2/main.dart'; // Assuming supabase is initialized here
import 'package:diabetes_2/core/utils/icon_helper.dart';
import 'drawer_loader.dart'; //

// A simple data class for profile info for the drawer
class DrawerUserProfile {
  final String? name;
  final String? email;
  final String? avatarUrl;

  DrawerUserProfile({this.name, this.email, this.avatarUrl});
}

class DrawerApp extends StatefulWidget {
  const DrawerApp({super.key});

  @override
  State<DrawerApp> createState() => _DrawerAppState();
}

class _DrawerAppState extends State<DrawerApp> {
  Future<DrawerUserProfile?>? _userProfileFuture;

  @override
  void initState() {
    super.initState();
    _userProfileFuture = _fetchUserProfile();
  }

  Future<DrawerUserProfile?> _fetchUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final data = await supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', user.id)
          .single();

      return DrawerUserProfile(
        name: data['username'] as String?,
        email: user.email,
        avatarUrl: data['avatar_url'] as String?,
      );
    } catch (e) {
      debugPrint('Error fetching profile for drawer: $e');
      // Return current user's email even if profile fetch fails
      final user = supabase.auth.currentUser;
      return DrawerUserProfile(email: user?.email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: theme.colorScheme.surfaceContainerLowest, // Adjusted for Material 3
      child: Column(
        children: [
          FutureBuilder<DrawerUserProfile?>(
            future: _userProfileFuture,
            builder: (context, snapshot) {
              String displayName = 'Usuario';
              String displayEmail = 'Cargando...';
              Widget avatarWidget = CircleAvatar(
                backgroundColor: theme.colorScheme.tertiaryContainer, // Adjusted
                child: Text('U', style: TextStyle(fontSize: 20, color: theme.colorScheme.onTertiaryContainer)), // Adjusted
              );

              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
                final profile = snapshot.data!;
                final currentUser = supabase.auth.currentUser;
                displayName = profile.name ?? currentUser?.email?.split('@').first ?? 'Usuario';
                displayEmail = profile.email ?? 'No email';
                if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
                  avatarWidget = CircleAvatar(
                    backgroundImage: NetworkImage(profile.avatarUrl!),
                    backgroundColor: Colors.transparent,
                  );
                } else {
                  avatarWidget = CircleAvatar(
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U', style: TextStyle(fontSize: 20, color: theme.colorScheme.onTertiaryContainer)),
                  );
                }
              } else if (snapshot.hasError) {
                displayEmail = 'Error al cargar';
              }
              // Fallback for user if profile is null but auth user exists
              final user = supabase.auth.currentUser;
              if (displayName == 'Usuario' && user?.email != null) {
                displayName = user!.email!.split('@').first;
              }
              if (displayEmail == 'Cargando...' && user?.email != null) {
                displayEmail = user!.email!;
              }


              return UserAccountsDrawerHeader(
                accountName: Text(
                  displayName,
                  style: TextStyle(color: theme.colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold), // Adjusted
                ),
                accountEmail: Text(
                  displayEmail,
                  style: TextStyle(color: theme.colorScheme.onSecondaryContainer.withOpacity(0.8)), // Adjusted
                ),
                currentAccountPicture: avatarWidget,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer, // Adjusted
                ),
                otherAccountsPictures: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSecondaryContainer),
                    tooltip: 'Editar Perfil',
                    onPressed: () {
                      Navigator.of(context).pop(); // Close drawer
                      context.push('/account'); // Navigate to AccountPage (ensure this route exists)
                    },
                  ),
                ],
              );
            },
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DrawerLoader.loadDrawerItems(), //
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar el menú'));
                }

                final items = snapshot.data!;
                // Getting current route. Be cautious with ModalRoute.of(context)?.settings.name
                // when using GoRouter for nested navigation. It might not always give the top-most route name.
                // For GoRouter, you might need a different way to get the current location if this fails.
                final goRouter = GoRouter.of(context);
                final currentLocation = goRouter.routerDelegate.currentConfiguration.uri.toString();


                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item['type'] == 'divider') {
                      return Divider(
                        height: 1,
                        color: theme.dividerColor.withOpacity(0.5), // Adjusted
                      );
                    } else if (item['type'] == 'padding') {
                      return SizedBox(height: item['value'] as double? ?? 0.0); // Added null check
                    } else if (item['type'] == 'item') {
                      final label = item['label'] as String? ?? 'Unnamed Item'; // Added null check
                      final iconKey = item['icon'] as String? ?? 'default_icon'; // Added null check
                      final route = item['route'] as String? ?? '/'; // Added null check
                      final selected = currentLocation == route;

                      return ListTile(
                        leading: Icon(
                          IconHelper.getIcon(iconKey),
                          color: selected ? theme.colorScheme.primary : theme.iconTheme.color, // Adjusted
                        ),
                        title: Text(
                          label,
                          style: TextStyle(
                            color: selected ? theme.colorScheme.primary : null, // Adjusted
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        selected: selected,
                        selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.6), // Adjusted
                        onTap: () {
                          Navigator.of(context).pop(); // Close drawer
                          if (!selected) context.go(route);
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}