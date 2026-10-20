import 'package:flutter/material.dart';

import '../models/town.dart';
import '../services/database_helper.dart';
import '../utils/provinces.dart';

/// Result of the edit/add form: either a saved [town], or [deleted] if
/// the user removed a user-added town, or neither if cancelled (in
/// which case the whole result is null).
class TownEditResult {
  final Town? town;
  final bool deleted;
  const TownEditResult.saved(this.town) : deleted = false;
  const TownEditResult.deleted() : town = null, deleted = true;
}

/// Opens a form to record or edit the old (previous) name on
/// an [existingTown]. Returns a [TownEditResult] on save/delete, or null
/// if the user cancelled.
Future<TownEditResult?> showEditRenameSheet(BuildContext context, {required Town existingTown}) {
  return showModalBottomSheet<TownEditResult?>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) => _TownEditForm(existingTown: existingTown),
  );
}

/// Opens a form to add a brand-new town at [latitude]/[longitude] (e.g.
/// dropped by a long-press on the map). Returns the newly created [Town]
/// on save, or null if the user cancelled.
Future<Town?> showAddNewTownSheet(BuildContext context, {required double latitude, required double longitude}) {
  return showModalBottomSheet<TownEditResult?>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) => _TownEditForm(newLocation: (latitude, longitude)),
  ).then((r) => r?.town);
}

class _TownEditForm extends StatefulWidget {
  const _TownEditForm({this.existingTown, this.newLocation})
      : assert(existingTown != null || newLocation != null);

  final Town? existingTown;
  final (double, double)? newLocation;

  @override
  State<_TownEditForm> createState() => _TownEditFormState();
}

class _TownEditFormState extends State<_TownEditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _currentNameController;
  late final TextEditingController _oldNameController;
  late final TextEditingController _yearController;
  late final TextEditingController _notesController;
  late String _province;
  bool _reverted = false;
  bool _saving = false;

  /// The old-name value we filled in automatically when the current name
  /// was changed - so we can keep it in sync, but never overwrite
  /// something the person typed themselves.
  String? _autoFilledOldName;
  bool _autoFilledYear = false;

  bool get _isNewTown => widget.existingTown == null;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTown;
    _currentNameController = TextEditingController(text: t?.currentName ?? '');
    _oldNameController = TextEditingController(text: t?.hasKnownRename == true ? t!.oldName : '');
    _yearController = TextEditingController(text: t?.renamedYear?.toString() ?? '');
    _notesController = TextEditingController(text: t?.notes ?? '');
    _province = t?.province ?? saProvinces.first;
    _reverted = t?.reverted ?? false;
    if (t != null) _currentNameController.addListener(_onCurrentNameChanged);
  }

  /// Recording a new rename: when the person types a new current name
  /// for an existing town, the name it had until now becomes the old
  /// name (unless they've already entered an old name of their own).
  void _onCurrentNameChanged() {
    final original = widget.existingTown!.currentName;
    final typed = _currentNameController.text.trim();
    final oldText = _oldNameController.text.trim();
    final oldIsOurs = oldText.isEmpty || oldText == _autoFilledOldName;
    if (!oldIsOurs) return;

    final renamed = typed.isNotEmpty && typed.toLowerCase() != original.toLowerCase();
    final wanted = renamed ? original : (widget.existingTown!.hasKnownRename ? widget.existingTown!.oldName : '');
    if (_oldNameController.text != wanted) {
      _oldNameController.text = wanted;
      _autoFilledOldName = renamed ? original : null;
    }
    // Suggest this year for a new rename; take the suggestion back if the
    // name is changed back to the original.
    if (renamed && _yearController.text.trim().isEmpty) {
      _yearController.text = '${DateTime.now().year}';
      _autoFilledYear = true;
    } else if (!renamed && _autoFilledYear) {
      _yearController.text = widget.existingTown!.renamedYear?.toString() ?? '';
      _autoFilledYear = false;
    }
  }

  @override
  void dispose() {
    _currentNameController.dispose();
    _oldNameController.dispose();
    _yearController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showError(String action, Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not $action: $e')));
    setState(() => _saving = false);
  }

  Future<bool> _confirm({required String title, required String message, required String action}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final currentName = _currentNameController.text.trim();
    final oldName = _oldNameController.text.trim();
    final year = int.tryParse(_yearController.text.trim());
    final notes = _notesController.text.trim();
    final db = DatabaseHelper.instance;

    try {
      Town result;
      if (_isNewTown) {
        final (lat, lon) = widget.newLocation!;
        result = await db.addUserTown(Town(
          currentName: currentName,
          oldName: oldName.isEmpty ? currentName : oldName,
          hasKnownRename: oldName.isNotEmpty,
          province: _province,
          latitude: lat,
          longitude: lon,
          renamedYear: year,
          reverted: _reverted,
          notes: notes.isEmpty ? null : notes,
        ));
      } else {
        result = await db.updateTown(
          id: widget.existingTown!.id!,
          currentName: currentName,
          oldName: oldName,
          province: _province,
          renamedYear: year,
          reverted: _reverted,
          notes: notes.isEmpty ? null : notes,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(TownEditResult.saved(result));
    } catch (e) {
      _showError('save', e);
    }
  }

  Future<void> _clearRename() async {
    final t = widget.existingTown;
    if (t == null || t.id == null) return;
    final ok = await _confirm(
      title: 'Clear name change?',
      message: '${t.currentName} will be shown with no old name on record. '
          'The old name, year and notes for it will be removed.',
      action: 'Clear',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      final result = await DatabaseHelper.instance.clearTownRename(t.id!);
      if (!mounted) return;
      Navigator.of(context).pop(TownEditResult.saved(result));
    } catch (e) {
      _showError('clear the name change', e);
    }
  }

  Future<void> _delete() async {
    final t = widget.existingTown;
    if (t == null || t.id == null || !t.isUserAdded) return;
    final ok = await _confirm(
      title: 'Delete ${t.currentName}?',
      message: 'This removes the town you added from the map. It can\'t be undone.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await DatabaseHelper.instance.deleteUserTown(t.id!);
      if (!mounted) return;
      Navigator.of(context).pop(const TownEditResult.deleted());
    } catch (e) {
      _showError('delete', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isNewTown ? 'Add a new town' : 'Edit town / record a name change',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _isNewTown
                    ? 'Dropped at the point you long-pressed on the map.'
                    : 'Renamed recently? Type the new name as the current name - '
                        'the previous one moves to the old name automatically.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Current name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _oldNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: _isNewTown ? 'Previous name (optional)' : 'Previous name',
                  border: const OutlineInputBorder(),
                  helperText: _isNewTown ? null : 'The name before the change',
                  errorMaxLines: 2,
                ),
                validator: (v) {
                  if (_isNewTown) return null;
                  if (v == null || v.trim().isEmpty) return 'Required';
                  // A reverted rename (e.g. Louis Trichardt) legitimately has
                  // the same previous and current name.
                  if (!_reverted && v.trim().toLowerCase() == _currentNameController.text.trim().toLowerCase()) {
                    return 'Old name should differ from the current name (tick Reverted if it changed back)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _province,
                decoration: const InputDecoration(labelText: 'Province', border: OutlineInputBorder()),
                items: saProvinces.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setState(() => _province = v ?? _province),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Year renamed (optional)', border: OutlineInputBorder()),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 1900 || n > DateTime.now().year + 1) return 'Enter a valid year';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reverted', style: TextStyle(fontSize: 13)),
                      value: _reverted,
                      onChanged: (v) => setState(() => _reverted = v ?? false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (!_isNewTown && widget.existingTown!.hasKnownRename)
                    TextButton.icon(
                      onPressed: _saving ? null : _clearRename,
                      icon: const Icon(Icons.undo),
                      label: const Text('Clear rename'),
                    ),
                  if (!_isNewTown && widget.existingTown!.isUserAdded) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
