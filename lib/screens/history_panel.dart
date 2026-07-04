import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/capture_item.dart';
import '../services/clipboard_service.dart';
import '../services/db_service.dart';

class HistoryPanel extends StatefulWidget {
  const HistoryPanel({super.key});

  @override
  State<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends State<HistoryPanel> {
  List<CaptureItem> _items = [];
  List<CaptureItem> _filtered = [];
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final items = await DbService.instance.getAll();
    setState(() {
      _items = items;
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_items);
    } else {
      final q = _searchQuery.toLowerCase();
      _filtered = _items
          .where((i) => i.extractedText.toLowerCase().contains(q))
          .toList();
    }
  }

  void _onSearch(String q) {
    setState(() {
      _searchQuery = q;
      _applyFilter();
    });
  }

  Future<void> _copyAgain(CaptureItem item) async {
    await ClipboardService.copyText(item.extractedText);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Copied to clipboard!'),
            ],
          ),
          backgroundColor: const Color(0xFF6C63FF),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _delete(CaptureItem item) async {
    await DbService.instance.delete(item.id);
    _refresh();
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E30),
        title: const Text('Clear All History',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete all captures. Are you sure?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DbService.instance.clearAll();
      _refresh();
    }
  }

  void _openPreview(CaptureItem item) {
    showDialog(
      context: context,
      builder: (ctx) => _ImagePreviewDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Capture History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
              tooltip: 'Clear all history',
              onPressed: _confirmClearAll,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search OCR text…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: Colors.white38),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: Colors.white38),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF0F0F1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            )
          : _filtered.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) =>
                      _buildCard(_filtered[index]),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.history_rounded,
            size: 72,
            color: Colors.white12,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No captures yet',
            style: const TextStyle(color: Colors.white38, fontSize: 16),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Press Ctrl+Shift+S to take your first screenshot',
              style: TextStyle(color: Colors.white24, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(CaptureItem item) {
    final hasImage = File(item.imagePath).existsSync();
    final dateStr = DateFormat('MMM d, y  HH:mm').format(item.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF1E1E30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openPreview(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              GestureDetector(
                onTap: () => _openPreview(item),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: hasImage
                      ? Image.file(
                          File(item.imagePath),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderThumb(),
                        )
                      : _placeholderThumb(),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.extractedText.isNotEmpty
                          ? item.extractedText
                          : '(no text detected)',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.extractedText.isNotEmpty
                            ? const Color(0xDEFFFFFF)
                            : Colors.white38,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.extractedText.length} chars',
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        size: 18, color: Color(0xFF6C63FF)),
                    tooltip: 'Copy text',
                    onPressed: item.extractedText.isNotEmpty
                        ? () => _copyAgain(item)
                        : null,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18, color: Colors.red.shade400),
                    tooltip: 'Delete',
                    onPressed: () => _delete(item),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderThumb() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_not_supported_rounded,
          color: Colors.white24, size: 28),
    );
  }
}

// ─── Image Preview Dialog ──────────────────────────────────────────────────────

class _ImagePreviewDialog extends StatelessWidget {
  final CaptureItem item;
  const _ImagePreviewDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasImage = File(item.imagePath).existsSync();

    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.image_rounded,
                      color: Color(0xFF6C63FF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM d, y  HH:mm').format(item.createdAt),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Image
            if (hasImage)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(item.imagePath),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

            // OCR text
            if (item.extractedText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F1A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      item.extractedText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  if (item.extractedText.isNotEmpty)
                    FilledButton.icon(
                      onPressed: () async {
                        await ClipboardService.copyText(item.extractedText);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Text'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
