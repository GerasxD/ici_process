import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CurrencyInputField extends StatefulWidget {
  final String label;
  final double value;
  final Function(double) onChanged;
  final bool disabled;

  const CurrencyInputField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.disabled = false,
  });

  @override
  State<CurrencyInputField> createState() => _CurrencyInputFieldState();
}

class _CurrencyInputFieldState extends State<CurrencyInputField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final _formatter = NumberFormat.currency(symbol: "\$ ");

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value > 0 ? _formatter.format(widget.value) : "",
    );

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Al ganar foco, mostramos solo el número para editar fácil
        _controller.text = widget.value > 0 ? widget.value.toStringAsFixed(2) : "";
      } else {
        // Al perder foco, aplicamos el formato de moneda
        double val = double.tryParse(_controller.text) ?? 0.0;
        widget.onChanged(val);
        _controller.text = val > 0 ? _formatter.format(val) : "";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: !widget.disabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            filled: true,
            fillColor: widget.disabled ? Colors.grey[100] : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}