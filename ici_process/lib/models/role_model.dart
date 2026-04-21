import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RoleModel {
  final String id;
  final String displayName;
  final String colorHex;
  final String iconKey;

  const RoleModel({
    required this.id,
    required this.displayName,
    required this.colorHex,
    required this.iconKey,
  });

  bool get isSuperAdmin => id == 'superAdmin';

  Color get color {
    final hex = colorHex.replaceAll('#', '');
    final value = int.tryParse(hex, radix: 16) ?? 0xFF64748B;
    return Color(hex.length == 6 ? 0xFF000000 | value : value);
  }

  IconData get icon => roleIconFromKey(iconKey);

  factory RoleModel.fromMap(Map<String, dynamic> data, String documentId) {
    return RoleModel(
      id: documentId,
      displayName: data['displayName'] ?? documentId,
      colorHex: data['colorHex'] ?? '#64748B',
      iconKey: data['iconKey'] ?? 'user',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'colorHex': colorHex,
      'iconKey': iconKey,
    };
  }

  RoleModel copyWith({
    String? id,
    String? displayName,
    String? colorHex,
    String? iconKey,
  }) {
    return RoleModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      colorHex: colorHex ?? this.colorHex,
      iconKey: iconKey ?? this.iconKey,
    );
  }
}

const Map<String, IconData> kRoleIconOptions = {
  'shield': LucideIcons.shield,
  'shieldAlert': LucideIcons.shieldAlert,
  'shieldCheck': LucideIcons.shieldCheck,
  'briefcase': LucideIcons.briefcase,
  'wrench': LucideIcons.wrench,
  'shoppingCart': LucideIcons.shoppingCart,
  'dollarSign': LucideIcons.dollarSign,
  'user': LucideIcons.user,
  'users': LucideIcons.users,
  'star': LucideIcons.star,
  'crown': LucideIcons.crown,
  'hardHat': LucideIcons.hardHat,
  'clipboardList': LucideIcons.clipboardList,
  'truck': LucideIcons.truck,
  'key': LucideIcons.key,
};

IconData roleIconFromKey(String key) {
  return kRoleIconOptions[key] ?? LucideIcons.user;
}

const List<String> kRoleColorPalette = [
  '#312E81',
  '#1E40AF',
  '#0369A1',
  '#0D9488',
  '#B45309',
  '#059669',
  '#7E22CE',
  '#BE185D',
  '#DC2626',
  '#475569',
];
