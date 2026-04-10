// lib/ui/widgets/process_modal/mention_text_field.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ici_process/models/user_model.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSubmit;
  final Function(List<String> mentionedUserIds) onMentionsChanged;
  final int maxLines;

  const MentionTextField({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onMentionsChanged,
    this.hintText = "Escribe una actualización o nota...",
    this.maxLines = 1,
  });

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  final Set<String> _mentionedUserIds = {};
  String _currentMentionQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _removeOverlay();
    super.dispose();
  }

  Future<void> _loadUsers() async {
  final snapshot = await FirebaseFirestore.instance.collection('users').get();
    if (mounted) {
      setState(() {
        _allUsers = snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList();
      });
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;

    if (cursorPos < 0 || cursorPos > text.length) {
      _removeOverlay();
      return;
    }

    // Buscar el último '@' antes del cursor
    final textBeforeCursor = text.substring(0, cursorPos);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex == -1) {
      _removeOverlay();
      return;
    }

    // Verificar que no haya espacio entre @ y el cursor (excepto en el query)
    final query = textBeforeCursor.substring(lastAtIndex + 1);

    // Si hay un espacio después del query completo, cerrar
    if (query.contains('\n')) {
      _removeOverlay();
      return;
    }

    _currentMentionQuery = query.toLowerCase();

    final filtered = _allUsers
        .where((u) =>
            u.name.toLowerCase().contains(_currentMentionQuery) ||
            u.email.toLowerCase().contains(_currentMentionQuery))
        .take(5)
        .toList();

    if (filtered.isEmpty) {
      _removeOverlay();
      return;
    }

    setState(() => _filteredUsers = filtered);
    _showOverlay();
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 300,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -8),
          followerAnchor: Alignment.bottomLeft,
          targetAnchor: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            shadowColor: Colors.black.withOpacity(0.15),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (ctx, index) {
                    final user = _filteredUsers[index];
                    final initials = user.name
                        .trim()
                        .split(' ')
                        .take(2)
                        .map((w) => w[0].toUpperCase())
                        .join();

                    return InkWell(
                      onTap: () => _selectUser(user),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    user.email,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _selectUser(UserModel user) {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex == -1) return;

    final before = text.substring(0, lastAtIndex);
    final after = text.substring(cursorPos);
    final mention = '@${user.name} ';

    widget.controller.text = '$before$mention$after';
    widget.controller.selection = TextSelection.collapsed(
      offset: before.length + mention.length,
    );

    _mentionedUserIds.add(user.id);
    widget.onMentionsChanged(_mentionedUserIds.toList());
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        onSubmitted: (_) => widget.onSubmit(),
        maxLines: widget.maxLines,
        style: const TextStyle(
            fontSize: 14, color: Color(0xFF1E293B), height: 1.4),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  // Insertar @ en la posición actual
                  final pos = widget.controller.selection.baseOffset;
                  final text = widget.controller.text;
                  if (pos >= 0) {
                    widget.controller.text =
                        '${text.substring(0, pos)}@${text.substring(pos)}';
                    widget.controller.selection =
                        TextSelection.collapsed(offset: pos + 1);
                  }
                },
                icon: const Icon(LucideIcons.atSign,
                    color: Color(0xFF94A3B8), size: 18),
                tooltip: "Mencionar usuario",
              ),
              IconButton(
                onPressed: widget.onSubmit,
                icon: const Icon(LucideIcons.send,
                    color: Color(0xFF2563EB), size: 18),
                tooltip: "Enviar",
              ),
            ],
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF2563EB), width: 1.5),
          ),
        ),
      ),
    );
  }
}