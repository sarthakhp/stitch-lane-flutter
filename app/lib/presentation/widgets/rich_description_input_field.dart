import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown_quill/markdown_quill.dart';
import 'package:markdown/markdown.dart' as md;
import '../../config/app_config.dart';
import '../../domain/services/audio_recording_service.dart';
import '../../domain/services/transcription_service.dart';
import 'transcription_voice_button.dart';

class _MarkdownConverter {
  final md.Document _mdDocument = md.Document(encodeHtml: false);
  late final MarkdownToDelta _mdToDelta = MarkdownToDelta(markdownDocument: _mdDocument);
  final DeltaToMarkdown _deltaToMd = DeltaToMarkdown();

  Document toQuillDocument(String markdown) {
    return Document.fromDelta(_mdToDelta.convert(markdown));
  }

  String toMarkdown(Document document) => _deltaToMd.convert(document.toDelta());
}

class RichDescriptionInputField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String>? onChanged;
  final String labelText;
  final String hintText;
  final bool enabled;
  final int minLines;

  const RichDescriptionInputField({
    super.key,
    this.initialValue = '',
    this.onChanged,
    this.labelText = 'Description',
    this.hintText = 'Enter description...',
    this.enabled = true,
    this.minLines = 3,
  });

  @override
  State<RichDescriptionInputField> createState() => RichDescriptionInputFieldState();
}

class RichDescriptionInputFieldState extends State<RichDescriptionInputField> {
  final _converter = _MarkdownConverter();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  late QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController(widget.initialValue);
  }

  @override
  void dispose() {
    _controller.removeListener(_notifyChange);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  QuillController _createController(String markdown) {
    final controller = markdown.isNotEmpty
        ? QuillController(
            document: _converter.toQuillDocument(markdown),
            selection: const TextSelection.collapsed(offset: 0),
          )
        : QuillController.basic();
    controller.addListener(_notifyChange);
    return controller;
  }

  void _replaceController(QuillController newController) {
    _controller.removeListener(_notifyChange);
    _controller.dispose();
    _controller = newController;
    if (mounted) setState(() {});
  }

  void _notifyChange() => widget.onChanged?.call(getMarkdown());

  String getMarkdown() => _converter.toMarkdown(_controller.document);

  String getPlainText() => _controller.document.toPlainText().trim();

  bool get isEmpty => getPlainText().isEmpty;

  void setMarkdown(String markdown) {
    final newController = _createController(markdown);
    newController.moveCursorToEnd();
    _replaceController(newController);
  }

  void appendMarkdown(String markdown) {
    final current = getMarkdown();
    setMarkdown(current.isEmpty ? markdown : '$current\n$markdown');
  }

  void clear() {
    _replaceController(_createController(''));
    widget.onChanged?.call('');
  }

  Future<void> _handleTranscription(String? audioFilePath) async {
    if (audioFilePath == null) return;

    final newText = await TranscriptionService.transcribeAndGetAction(
      context: context,
      audioFilePath: audioFilePath,
      currentText: getMarkdown(),
    );

    if (newText != null && mounted) {
      setMarkdown(newText);
      widget.onChanged?.call(newText);
    }

    try {
      await AudioRecordingService.deleteTemporaryAudio();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(colorScheme),
        const SizedBox(height: AppConfig.spacing8),
        _buildToolbar(colorScheme),
        const SizedBox(height: AppConfig.spacing8),
        _buildEditor(colorScheme),
        const SizedBox(height: AppConfig.spacing8),
        TranscriptionVoiceButton(
          onRecordingComplete: _handleTranscription,
          expandWidth: true,
        ),
      ],
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.labelText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.clear),
              onPressed: clear,
              tooltip: 'Clear',
              visualDensity: VisualDensity.compact,
            );
          },
        ),
      ],
    );
  }

  Widget _buildToolbar(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppConfig.cardBorderRadius),
          topRight: Radius.circular(AppConfig.cardBorderRadius),
        ),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: QuillSimpleToolbar(
        controller: _controller,
        config: _buildToolbarConfig(colorScheme),
      ),
    );
  }

  QuillSimpleToolbarConfig _buildToolbarConfig(ColorScheme colorScheme) {
    return QuillSimpleToolbarConfig(
      showAlignmentButtons: false,
      showBackgroundColorButton: false,
      showCenterAlignment: false,
      showClearFormat: false,
      showCodeBlock: false,
      showColorButton: false,
      showDirection: false,
      showDividers: false,
      showFontFamily: false,
      showFontSize: false,
      showHeaderStyle: false,
      showIndent: false,
      showInlineCode: false,
      showJustifyAlignment: false,
      showLeftAlignment: false,
      showLink: false,
      showQuote: false,
      showRightAlignment: false,
      showSearchButton: false,
      showSmallButton: false,
      showStrikeThrough: false,
      showSubscript: false,
      showSuperscript: false,
      showUnderLineButton: false,
      showBoldButton: true,
      showItalicButton: true,
      showListBullets: true,
      showListNumbers: true,
      showListCheck: false,
      showClipboardCopy: false,
      showClipboardCut: false,
      showClipboardPaste: false,
      showRedo: false,
      showUndo: false,
      buttonOptions: QuillSimpleToolbarButtonOptions(
        base: QuillToolbarBaseButtonOptions(
          iconTheme: QuillIconTheme(
            iconButtonSelectedData: IconButtonData(
              color: colorScheme.onPrimary,
              style: IconButton.styleFrom(backgroundColor: colorScheme.primary),
            ),
            iconButtonUnselectedData: IconButtonData(color: colorScheme.onSurface),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(ColorScheme colorScheme) {
    final lineHeight = Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16;
    final minHeight = lineHeight * widget.minLines + 32;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: widget.enabled ? colorScheme.surface : colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppConfig.cardBorderRadius),
          bottomRight: Radius.circular(AppConfig.cardBorderRadius),
        ),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: QuillEditor(
        controller: _controller,
        focusNode: _focusNode,
        scrollController: _scrollController,
        config: QuillEditorConfig(
          placeholder: widget.hintText,
          padding: const EdgeInsets.all(AppConfig.spacing12),
          expands: false,
          autoFocus: false,
          scrollable: true,
          readOnlyMouseCursor: SystemMouseCursors.text,
          enableInteractiveSelection: widget.enabled,
        ),
      ),
    );
  }
}
