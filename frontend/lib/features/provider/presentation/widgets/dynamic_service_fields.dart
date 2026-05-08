import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'service_form_configs.dart';

/// Renders the extra fields for a given [category] dynamically.
///
/// [category]       – current service category key (e.g. 'sand_trolley')
/// [initialValues]  – pre-populated values when editing an existing service
/// [onChanged]      – called with the full updated map whenever any field changes
/// [formKey]        – optional outer Form key; the widget adds its own validators
///
/// The widget is self-contained with its own [StatefulWidget]; just drop it
/// inside the parent form tree and it will manage its state internally while
/// pushing changes up via [onChanged].
class DynamicServiceFields extends StatefulWidget {
  final String category;
  final Map<String, dynamic> initialValues;
  final void Function(Map<String, dynamic> values) onChanged;

  const DynamicServiceFields({
    super.key,
    required this.category,
    required this.initialValues,
    required this.onChanged,
  });

  @override
  State<DynamicServiceFields> createState() => _DynamicServiceFieldsState();
}

class _DynamicServiceFieldsState extends State<DynamicServiceFields> {
  late Map<String, dynamic> _values;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  @override
  void didUpdateWidget(DynamicServiceFields old) {
    super.didUpdateWidget(old);
    if (old.category != widget.category) {
      // Dispose old controllers and reinitialise for new category.
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();
      _initValues();
    }
  }

  void _initValues() {
    final sections = getServiceFormSections(widget.category) ?? [];
    _values = Map<String, dynamic>.from(widget.initialValues);

    // Seed defaults for any field not yet in initialValues.
    for (final section in sections) {
      for (final field in section.fields) {
        if (!_values.containsKey(field.key)) {
          _values[field.key] = field.defaultValue ??
              _defaultForType(field.type, field.radioOptions);
        }
      }
    }
  }

  dynamic _defaultForType(ServiceFieldType type, List<RadioOption>? radioOptions) {
    switch (type) {
      case ServiceFieldType.toggle:
        return false;
      case ServiceFieldType.multiSelect:
        return <String>[];
      case ServiceFieldType.radio:
        return radioOptions?.first.value ?? '';
      default:
        return null;
    }
  }

  void _update(String key, dynamic value) {
    setState(() => _values[key] = value);
    widget.onChanged(Map<String, dynamic>.from(_values));
  }

  bool _isVisible(ServiceFieldConfig field) {
    if (field.showWhen == null) return true;
    return _values[field.showWhen] == field.showWhenValue;
  }

  TextEditingController _controllerFor(ServiceFieldConfig field) {
    return _controllers.putIfAbsent(field.key, () {
      final initial = _values[field.key];
      return TextEditingController(
        text: initial != null && initial != '' ? initial.toString() : '',
      );
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = getServiceFormSections(widget.category);
    if (sections == null || sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionDivider(label: 'Service-Specific Details'),
        ...sections.map((section) => _buildSection(context, section)),
      ],
    );
  }

  Widget _buildSection(BuildContext context, ServiceFormSection section) {
    final visibleFields = section.fields.where(_isVisible).toList();
    if (visibleFields.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: section.title),
          const SizedBox(height: 12),
          ...visibleFields.map((f) => _buildField(context, f)),
        ],
      ),
    );
  }

  Widget _buildField(BuildContext context, ServiceFieldConfig field) {
    switch (field.type) {
      case ServiceFieldType.number:
      case ServiceFieldType.text:
        return _NumberTextField(
          field: field,
          controller: _controllerFor(field),
          onChanged: (v) => _update(field.key, v),
        );

      case ServiceFieldType.dropdown:
        return _DropdownField(
          field: field,
          value: _values[field.key] as String?,
          onChanged: (v) => _update(field.key, v),
        );

      case ServiceFieldType.multiSelect:
        return _MultiSelectField(
          field: field,
          selected: List<String>.from(_values[field.key] ?? []),
          onChanged: (v) => _update(field.key, v),
        );

      case ServiceFieldType.toggle:
        return _ToggleField(
          field: field,
          value: _values[field.key] == true,
          onChanged: (v) => _update(field.key, v),
        );

      case ServiceFieldType.radio:
        return _RadioField(
          field: field,
          value: _values[field.key] as String? ?? field.radioOptions?.first.value ?? '',
          onChanged: (v) => _update(field.key, v),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Individual field widgets
// ---------------------------------------------------------------------------

class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
    );
  }
}

// ---- Number / Text field ----

class _NumberTextField extends StatelessWidget {
  final ServiceFieldConfig field;
  final TextEditingController controller;
  final void Function(dynamic) onChanged;

  const _NumberTextField({
    required this.field,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isNumber = field.type == ServiceFieldType.number;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: field.unit != null
              ? '${field.label} (${field.unit})'
              : field.label,
          hintText: field.hint,
          filled: true,
          fillColor: Colors.white,
          suffixText: field.unit,
          suffixStyle: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        validator: field.required
            ? (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (isNumber && double.tryParse(v) == null) return 'Invalid number';
                return null;
              }
            : (v) {
                if (isNumber && v != null && v.trim().isNotEmpty && double.tryParse(v) == null) {
                  return 'Invalid number';
                }
                return null;
              },
        onChanged: (v) {
          if (isNumber) {
            onChanged(double.tryParse(v) ?? v);
          } else {
            onChanged(v);
          }
        },
      ),
    );
  }
}

// ---- Dropdown field ----

class _DropdownField extends StatelessWidget {
  final ServiceFieldConfig field;
  final String? value;
  final void Function(String?) onChanged;

  const _DropdownField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = field.stringOptions ?? [];
    final effectiveValue = (value != null && options.contains(value)) ? value : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: effectiveValue,
        decoration: InputDecoration(
          labelText: field.label,
          filled: true,
          fillColor: Colors.white,
        ),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: onChanged,
        validator: field.required
            ? (v) => (v == null || v.isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }
}

// ---- Multi-select chips ----

class _MultiSelectField extends StatelessWidget {
  final ServiceFieldConfig field;
  final List<String> selected;
  final void Function(List<String>) onChanged;

  const _MultiSelectField({
    required this.field,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = field.stringOptions ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label + (field.required ? ' *' : ''),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: options.map((opt) {
              final isSelected = selected.contains(opt);
              return FilterChip(
                label: Text(opt),
                selected: isSelected,
                onSelected: (v) {
                  final next = List<String>.from(selected);
                  if (v) {
                    next.add(opt);
                  } else {
                    next.remove(opt);
                  }
                  onChanged(next);
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                checkmarkColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.grey.shade300,
                ),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              );
            }).toList(),
          ),
          if (field.required && selected.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Please select at least one option',
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Toggle ----

class _ToggleField extends StatelessWidget {
  final ServiceFieldConfig field;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: Text(
          field.label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        dense: true,
        contentPadding: EdgeInsets.zero,
        activeColor: AppTheme.primaryColor,
      ),
    );
  }
}

// ---- Radio ----

class _RadioField extends StatelessWidget {
  final ServiceFieldConfig field;
  final String value;
  final void Function(String) onChanged;

  const _RadioField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = field.radioOptions ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
          Row(
            children: options.map((opt) {
              final isSelected = opt.value == value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(opt.value),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      opt.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
