import 'package:flutter/material.dart';
import '../../config/app_config.dart';

class SearchBarWidget extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  const SearchBarWidget({
    super.key,
    required this.hintText,
    required this.onSearchChanged,
    this.onClear,
    this.autofocus = false,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasRequestedInitialFocus = false;

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      setState(() {});
    });

    if (widget.autofocus && !_hasRequestedInitialFocus) {
      _hasRequestedInitialFocus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _controller.clear();
    widget.onSearchChanged('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConfig.spacing8),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: widget.onSearchChanged,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                )
              : null,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConfig.spacing16,
            vertical: AppConfig.spacing8,
          ),
        ),
      ),
    );
  }
}

