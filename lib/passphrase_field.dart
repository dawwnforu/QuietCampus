import 'package:flutter/material.dart';

import 'app_language.dart';

String? validateNewPassphrase(String? value) =>
    (value ?? '').runes.length < 12 ? '加密口令至少需要 12 个字符' : null;

class PassphraseField extends StatefulWidget {
  const PassphraseField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.validator,
    this.onSubmitted,
    this.newPassphrase = false,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final bool newPassphrase;

  @override
  State<PassphraseField> createState() => _PassphraseFieldState();
}

class _PassphraseFieldState extends State<PassphraseField> {
  bool visible = false;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: !visible,
    enableSuggestions: false,
    autocorrect: false,
    validator: widget.validator == null
        ? null
        : (value) {
            final message = widget.validator!(value);
            return message == null ? null : context.t(message);
          },
    autovalidateMode: AutovalidateMode.onUserInteraction,
    onFieldSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      labelText: context.t(widget.label),
      helperText: widget.newPassphrase
          ? context.t('至少 12 个字符，可使用中文、字母、数字或符号')
          : null,
      helperMaxLines: 4,
      suffixIcon: IconButton(
        tooltip: context.t(visible ? '隐藏{label}' : '显示{label}', {
          'label': context.t(widget.label),
        }),
        onPressed: widget.enabled
            ? () => setState(() => visible = !visible)
            : null,
        icon: Icon(
          visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    ),
  );
}
