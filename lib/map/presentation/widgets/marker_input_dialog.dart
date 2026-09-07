import 'package:flutter/material.dart';

/// A dialog for adding or editing a map marker.
///
/// Encapsulates [TextEditingController]s in a [StatefulWidget] so that controllers
/// are only disposed in [State.dispose] after the dialog route has completely
/// popped, preventing "A TextEditingController was used after being disposed" errors.
class MarkerInputDialog extends StatefulWidget {
  const MarkerInputDialog({
    super.key,
    this.dialogTitle = '장소 마커 추가',
    this.initialTitle = '장소 마커',
    this.initialNote,
    this.initialCategory,
    this.titleLabel = '제목',
    this.submitLabel = '저장',
  });

  final String dialogTitle;
  final String initialTitle;
  final String? initialNote;
  final String? initialCategory;
  final String titleLabel;
  final String submitLabel;

  static Future<Map<String, String>?> show(
    BuildContext context, {
    String dialogTitle = '장소 마커 추가',
    String initialTitle = '장소 마커',
    String? initialNote,
    String? initialCategory,
    String titleLabel = '제목',
    String submitLabel = '저장',
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => MarkerInputDialog(
        dialogTitle: dialogTitle,
        initialTitle: initialTitle,
        initialNote: initialNote,
        initialCategory: initialCategory,
        titleLabel: titleLabel,
        submitLabel: submitLabel,
      ),
    );
  }

  @override
  State<MarkerInputDialog> createState() => _MarkerInputDialogState();
}

class _MarkerInputDialogState extends State<MarkerInputDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _categoryController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _noteController = TextEditingController(text: widget.initialNote ?? '');
    _categoryController =
        TextEditingController(text: widget.initialCategory ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop({
      'title': title,
      'note': _noteController.text.trim(),
      'category': _categoryController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: widget.titleLabel,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '메모(선택)',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: '분류(선택)',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

/// A dialog for entering title and memo for a captured photo.
class PhotoMemoDialog extends StatefulWidget {
  const PhotoMemoDialog({
    super.key,
    required this.defaultTitle,
  });

  final String defaultTitle;

  static Future<Map<String, String>?> show(
    BuildContext context, {
    required String defaultTitle,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => PhotoMemoDialog(defaultTitle: defaultTitle),
    );
  }

  @override
  State<PhotoMemoDialog> createState() => _PhotoMemoDialogState();
}

class _PhotoMemoDialogState extends State<PhotoMemoDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.defaultTitle);
    _memoController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop({
      'title': _titleController.text.trim(),
      'note': _memoController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('사진 메모'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '마커 이름',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '메모(선택)',
                hintText: '사진에 대한 메모를 입력하세요',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop({
            'title': widget.defaultTitle,
            'note': '',
          }),
          child: const Text('건너뛰기'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('저장'),
        ),
      ],
    );
  }
}
