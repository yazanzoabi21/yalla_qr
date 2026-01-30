import 'package:flutter/material.dart';
import '../services/theme_service.dart';

Future<void> showThemeSelector(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: const Text('Theme'),
        children: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.instance.modeNotifier,
            builder: (context, mode, _) {
              final current = ThemeService.instance.currentOption;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: AppThemeOption.values.map((option) {
                  final label = _labelFor(option);
                  return RadioListTile<AppThemeOption>(
                    value: option,
                    groupValue: current,
                    onChanged: (v) async {
                      if (v != null) {
                        await ThemeService.instance.setTheme(v);
                        Navigator.of(context).pop();
                      }
                    },
                    title: Text(label),
                    dense: true,
                  );
                }).toList(),
              );
            },
          ),
        ],
      );
    },
  );
}

String _labelFor(AppThemeOption option) {
  switch (option) {
    case AppThemeOption.dark:
      return 'Dark';
    case AppThemeOption.light:
      return 'Light';
    case AppThemeOption.system:
    default:
      return 'System';
  }
}
