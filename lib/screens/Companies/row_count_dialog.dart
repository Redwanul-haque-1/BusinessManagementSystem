import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<int?> showRowCountDialog(BuildContext context) {
  return showDialog<int>(
    context: context,
    builder: (_) => const _RowCountDialog(),
  );
}

class _RowCountDialog extends StatefulWidget {
  const _RowCountDialog();

  @override
  State<_RowCountDialog> createState() => _RowCountDialogState();
}

class _RowCountDialogState extends State<_RowCountDialog> {
  final TextEditingController controller = TextEditingController(text: '1');
  String? errorText;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final count = int.tryParse(controller.text.trim());
    if (count == null || count < 1 || count > 100) {
      setState(() {
        errorText = '১ থেকে ১০০-এর মধ্যে সারির সংখ্যা দিন।';
      });
      return;
    }

    Navigator.pop(context, count);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('কতটি নতুন সারি যোগ করবেন?'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'সারির সংখ্যা',
          errorText: errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('বাতিল'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('যোগ করুন')),
      ],
    );
  }
}
