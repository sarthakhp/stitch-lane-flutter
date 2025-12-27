import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown_quill/markdown_quill.dart';
import 'package:markdown/markdown.dart' as md;
import '../../config/app_config.dart';
import '../../domain/services/audio_recording_service.dart';
import '../../domain/services/transcription_service.dart';
import 'transcription_voice_button.dart';

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
  late QuillController _quillController;
  late final md.Document _mdDocument;
  late final MarkdownToDelta _mdToDelta;
  late final DeltaToMarkdown _deltaToMd;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _mdDocument = md.Document(encodeHtml: false);
    _mdToDelta = MarkdownToDelta(markdownDocument: _mdDocument);
    _deltaToMd = DeltaToMarkdown();
    _initController();
  }

  void _initController() {
    if (widget.initialValue.isNotEmpty) {
      final delta = _mdToDelta.convert(widget.initialValue);
      _quillController = QuillController(
        document: Document.fromDelta(delta),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      _quillController = QuillController.basic();
    }
    _quillController.addListener(_onDocumentChange);
  }

  void _onDocumentChange() {
    if (widget.onChanged != null) {
      widget.onChanged!(getMarkdown());
    }
  }

  String getMarkdown() {
    return _deltaToMd.convert(_quillController.document.toDelta());
  }

  String getPlainText() {
    return _quillController.document.toPlainText().trim();
  }

  void setMarkdown(String markdown) {
    final delta = _mdToDelta.convert(markdown);
    _quillController.removeListener(_onDocumentChange);
    _quillController.document = Document.fromDelta(delta);
    _quillController.moveCursorToEnd();
    _quillController.addListener(_onDocumentChange);
  }

  void appendMarkdown(String markdown) {
    final currentMarkdown = getMarkdown();
    final newMarkdown = currentMarkdown.isEmpty
        ? markdown
        : '$currentMarkdown\n$markdown';
    setMarkdown(newMarkdown);
  }

  void clear() {
    _quillController.removeListener(_onDocumentChange);
    _quillController.document = Document();
    _quillController.addListener(_onDocumentChange);
    widget.onChanged?.call('');
  }

  bool get isEmpty => getPlainText().isEmpty;

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
  void dispose() {
    _quillController.removeListener(_onDocumentChange);
    _quillController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.labelText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            TranscriptionVoiceButton(
              onRecordingComplete: _handleTranscription,
            ),
          ],
        ),
        const SizedBox(height: AppConfig.spacing8),
        _buildToolbar(colorScheme),
        const SizedBox(height: AppConfig.spacing8),
        _buildEditor(colorScheme),
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
        controller: _quillController,
        config: QuillSimpleToolbarConfig(
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
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                  ),
                ),
                iconButtonUnselectedData: IconButtonData(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
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
        controller: _quillController,
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
