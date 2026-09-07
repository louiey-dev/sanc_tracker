import 'package:flutter/material.dart';

/// A modal dialog for editing or renaming a tracking session's title.
///
/// Encapsulates the [TextEditingController] in a [StatefulWidget] so that
/// the controller is only disposed in [State.dispose] after the dialog route has popped.
class SessionTitleDialog extends StatefulWidget {
  const SessionTitleDialog({
    super.key,
    required this.initialTitle,
  });

  final String initialTitle;

  static Future<String?> show(
    BuildContext context, {
    required String initialTitle,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => SessionTitleDialog(initialTitle: initialTitle),
    );
  }

  @override
  State<SessionTitleDialog> createState() => _SessionTitleDialogState();
}

class _SessionTitleDialogState extends State<SessionTitleDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('기록 이름 수정'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: '기록 이름',
          hintText: '예: 북한산 백운대 등산, 아침 산책',
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _controller.clear();
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('저장'),
        ),
      ],
    );
  }
}
