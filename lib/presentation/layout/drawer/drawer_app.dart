import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'drawer_loader.dart';
import '../../../utils/icon_helper.dart';

class DrawerApp extends StatelessWidget {
  const DrawerApp({super.key});


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: theme.colorScheme.tertiaryFixed,
      child: Column(
        children: [
          // Polished header
          UserAccountsDrawerHeader(
            accountName: Text('Marcos Plaza Piqueras', style: TextStyle(color: theme.colorScheme.primaryFixed)),
            accountEmail: Text('loquesea@example.com', style: TextStyle(color: theme.colorScheme.primaryFixed)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.colorScheme.tertiaryFixed,
              child: Text('MP', style: TextStyle(fontSize: 20, color: theme.colorScheme.onTertiaryFixed)),
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimaryFixedVariant,
            ),
          ),

          // Menu items loaded from JSON
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DrawerLoader.loadDrawerItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Failed to load menu'));
                }

                final items = snapshot.data!;
                final currentRoute = ModalRoute.of(context)?.settings.name;

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item['type'] == 'divider') {
                      return Divider(
                        height: 1,
                        color: theme.dividerColor,
                      );
                    } else if (item['type'] == 'padding') {
                      return SizedBox(height: item['value'] as double);
                    } else if (item['type'] == 'item') {
                      final label = item['label'] as String;
                      final iconKey = item['icon'] as String;
                      final route = item['route'] as String;
                      final selected = currentRoute == route;

                      return ListTile(
                        leading: Icon(
                          IconHelper.getIcon(iconKey),
                          color: selected ? theme.colorScheme.onTertiary : theme.iconTheme.color,
                        ),
                        title: Text(
                          label,
                          style: TextStyle(
                            color: selected ? theme.colorScheme.onTertiary : null,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        selected: selected,
                        selectedTileColor: theme.colorScheme.tertiaryFixedDim.withValues(alpha: 0.8),
                        onTap: () {
                          Navigator.of(context).pop();
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