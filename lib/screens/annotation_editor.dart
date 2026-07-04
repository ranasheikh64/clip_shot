import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/capture_item.dart';
import '../services/clipboard_service.dart';
import '../services/db_service.dart';
import '../services/ocr_service.dart';
import '../widgets/annotation_painter.dart';

// ─── Stroke width presets ────────────────────────────────────────────────────
const _strokePresets = [2.0, 4.0, 8.0, 14.0];

// ─── Color palette ───────────────────────────────────────────────────────────
const _palette = [
  Color(0xFFFF4444), // Red
  Color(0xFFFF9800), // Orange
  Color(0xFFFFEB3B), // Yellow
  Color(0xFF4CAF50), // Green
  Color(0xFF2196F3), // Blue
  Color(0xFFE91E63), // Pink
  Color(0xFFFFFFFF), // White
  Color(0xFF212121), // Black
];

class AnnotationEditor extends StatefulWidget {
  final String imagePath;
  const AnnotationEditor({super.key, required this.imagePath});

  @override
  State<AnnotationEditor> createState() => _AnnotationEditorState();
}

class _AnnotationEditorState extends State<AnnotationEditor>
    with TickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();
  ui.Image? _bgImage;
  Size _imageSize = Size.zero;

  final List<AnnotationStroke> _strokes = [];
  AnnotationStroke? _inProgress;
  final List<List<AnnotationStroke>> _history = []; // undo stack

  AnnotationTool _tool = AnnotationTool.arrow;
  Color _color = const Color(0xFFFF4444);
  double _strokeWidth = 4.0;

  bool _isProcessing = false;
  String _processingStatus = '';
  
  String? _dbItemId;

  late AnimationController _toolbarController;
  late Animation<double> _toolbarAnim;

  @override
  void initState() {
    super.initState();
    _toolbarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _toolbarAnim = CurvedAnimation(
      parent: _toolbarController,
      curve: Curves.easeOut,
    );
    _toolbarController.forward();
    _loadImage();
    _runAutoOcr();
  }

  @override
  void dispose() {
    _toolbarController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _bgImage = frame.image;
      _imageSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    });
  }

  // ─── Drawing callbacks ───────────────────────────────────────────────────

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _inProgress = AnnotationStroke(
        tool: _tool,
        color: _color,
        strokeWidth: _strokeWidth,
        points: [details.localPosition],
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_inProgress == null) return;
    setState(() {
      if (_tool == AnnotationTool.freehand || _tool == AnnotationTool.marker) {
        _inProgress!.points.add(details.localPosition);
      } else {
        // arrow / rectangle: keep only start + current
        if (_inProgress!.points.length == 1) {
          _inProgress!.points.add(details.localPosition);
        } else {
          _inProgress!.points[1] = details.localPosition;
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (_inProgress == null) return;
    setState(() {
      _history.add(List.from(_strokes)); // save undo state
      _strokes.add(_inProgress!);
      _inProgress = null;
    });
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _strokes
        ..clear()
        ..addAll(_history.removeLast());
    });
  }

  void _clearAll() {
    if (_strokes.isEmpty) return;
    setState(() {
      _history.add(List.from(_strokes));
      _strokes.clear();
    });
  }

  // ─── Export & OCR ────────────────────────────────────────────────────────

  // ─── Export & Auto-OCR ───────────────────────────────────────────────────

  Future<void> _runAutoOcr() async {
    try {
      final originalFile = File(widget.imagePath);
      final bytes = await originalFile.readAsBytes();
      
      // Run OCR immediately
      final text = await OcrService.recognizeText(bytes);
      
      if (text.isNotEmpty) {
        await ClipboardService.copyText(text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Text auto-extracted and copied to clipboard!'),
                ],
              ),
              backgroundColor: Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No text detected in this screenshot.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      // Save to history immediately
      final docsDir = await getApplicationSupportDirectory();
      final id = const Uuid().v4();
      _dbItemId = id;
      
      final savedPath = p.join(docsDir.path, 'snap_$id.png');
      await originalFile.copy(savedPath);

      final item = CaptureItem(
        id: id,
        imagePath: savedPath,
        extractedText: text,
        createdAt: DateTime.now(),
      );
      await DbService.instance.insert(item);
    } catch (e) {
      debugPrint('Auto OCR failed: $e');
    }
  }

  Future<Uint8List> _exportPng() async {
    final boundary =
        _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final pixelRatio = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 2.0;
    final image = await boundary.toImage(pixelRatio: math.max(pixelRatio, 2.0));
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _saveAnnotationsAndClose() async {
    if (_strokes.isEmpty) {
      // Nothing drawn, just close
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Saving annotations…';
    });

    try {
      final pngBytes = await _exportPng();

      if (_dbItemId != null) {
        // Overwrite the saved image with the annotated one
        final docsDir = await getApplicationSupportDirectory();
        final savedPath = p.join(docsDir.path, 'snap_$_dbItemId.png');
        await File(savedPath).writeAsBytes(pngBytes);
      }
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = '';
        });
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_bgImage == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF6C63FF)),
              SizedBox(height: 16),
              Text('Loading image…',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D18),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: Center(
              child: _imageSize == Size.zero
                  ? const SizedBox.shrink()
                  : RepaintBoundary(
                      key: _repaintKey,
                      child: AspectRatio(
                        aspectRatio: _imageSize.width / _imageSize.height,
                        child: GestureDetector(
                          onPanStart: _isProcessing ? null : _onPanStart,
                          onPanUpdate: _isProcessing ? null : _onPanUpdate,
                          onPanEnd: _isProcessing ? null : _onPanEnd,
                          child: CustomPaint(
                            painter: AnnotationPainter(
                              backgroundImage: _bgImage,
                              strokes: _strokes,
                              inProgress: _inProgress,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          if (_isProcessing) _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _processingStatus,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return FadeTransition(
      opacity: _toolbarAnim,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8)],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Close button
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Discard',
            ),
            const SizedBox(width: 4),
            _Divider(),
            const SizedBox(width: 4),

            // Tools
            _toolBtn(AnnotationTool.arrow, Icons.north_east_rounded, 'Arrow'),
            _toolBtn(AnnotationTool.rectangle, Icons.crop_square_rounded, 'Rectangle'),
            _toolBtn(AnnotationTool.freehand, Icons.edit_rounded, 'Freehand'),
            _toolBtn(AnnotationTool.marker, Icons.brush_rounded, 'Highlight'),

            const SizedBox(width: 4),
            _Divider(),
            const SizedBox(width: 8),

            // Color palette
            ..._palette.map(_colorSwatch),

            const SizedBox(width: 8),
            _Divider(),
            const SizedBox(width: 8),

            // Stroke width
            ..._strokePresets.map(_strokeBtn),

            const Spacer(),

            // Undo / Clear
            IconButton(
              icon: const Icon(Icons.undo_rounded, color: Colors.white70),
              onPressed: _strokes.isNotEmpty ? _undo : null,
              tooltip: 'Undo  (last stroke)',
            ),
            IconButton(
              icon: const Icon(Icons.layers_clear_rounded, color: Colors.white70),
              onPressed: _strokes.isNotEmpty ? _clearAll : null,
              tooltip: 'Clear all annotations',
            ),

            const SizedBox(width: 8),

            // Done button
            _isProcessing
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _saveAnnotationsAndClose,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Save & Close'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn(AnnotationTool tool, IconData icon, String tooltip) {
    final selected = _tool == tool;
    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          icon: Icon(
            icon,
            color: selected ? const Color(0xFF6C63FF) : Colors.white60,
            size: 20,
          ),
          onPressed: () => setState(() => _tool = tool),
        ),
      ),
    );
  }

  Widget _colorSwatch(Color color) {
    final selected = _color == color;
    return GestureDetector(
      onTap: () => setState(() => _color = color),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
              : null,
        ),
      ),
    );
  }

  Widget _strokeBtn(double width) {
    final selected = _strokeWidth == width;
    return GestureDetector(
      onTap: () => setState(() => _strokeWidth = width),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.25)
              : Colors.transparent,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 20,
          height: width.clamp(1.5, 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6C63FF) : Colors.white38,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

// ─── Divider helper ──────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white12,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}


