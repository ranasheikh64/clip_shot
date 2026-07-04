import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ─── Tool enum ───────────────────────────────────────────────────────────────

enum AnnotationTool { arrow, rectangle, freehand, marker }

// ─── Stroke model ─────────────────────────────────────────────────────────────

class AnnotationStroke {
  final AnnotationTool tool;
  final Color color;
  final double strokeWidth;
  /// freehand/marker: list of points.
  /// arrow/rectangle: exactly [start, end].
  final List<Offset> points;

  AnnotationStroke({
    required this.tool,
    required this.color,
    required this.strokeWidth,
    required this.points,
  });
}

// ─── Painter ──────────────────────────────────────────────────────────────────

class AnnotationPainter extends CustomPainter {
  final ui.Image? backgroundImage;
  final List<AnnotationStroke> strokes;
  final AnnotationStroke? inProgress;

  AnnotationPainter({
    required this.backgroundImage,
    required this.strokes,
    this.inProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background image
    if (backgroundImage != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, size.width, size.height),
        image: backgroundImage!,
        fit: BoxFit.fill,
      );
    }

    // Draw committed strokes
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke, size);
    }

    // Draw in-progress stroke
    if (inProgress != null) {
      _paintStroke(canvas, inProgress!, size);
    }
  }

  void _paintStroke(Canvas canvas, AnnotationStroke stroke, Size size) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (stroke.tool) {
      case AnnotationTool.freehand:
        _drawFreehand(canvas, stroke, paint);
        break;

      case AnnotationTool.marker:
        _drawMarker(canvas, stroke, paint);
        break;

      case AnnotationTool.rectangle:
        _drawRectangle(canvas, stroke, paint);
        break;

      case AnnotationTool.arrow:
        _drawArrow(canvas, stroke, paint);
        break;
    }
  }

  void _drawFreehand(Canvas canvas, AnnotationStroke stroke, Paint paint) {
    if (stroke.points.length < 2) return;
    final path = Path()
      ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length - 1; i++) {
      // Smooth via midpoint averaging
      final mid = Offset(
        (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
        (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(
        stroke.points[i].dx,
        stroke.points[i].dy,
        mid.dx,
        mid.dy,
      );
    }
    path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    canvas.drawPath(path, paint);
  }

  void _drawMarker(Canvas canvas, AnnotationStroke stroke, Paint paint) {
    if (stroke.points.length < 2) return;
    final markerPaint = Paint()
      ..color = stroke.color.withValues(alpha: 0.38)
      ..strokeWidth = stroke.strokeWidth * 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..blendMode = BlendMode.multiply
      ..isAntiAlias = true;

    final path = Path()
      ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (final pt in stroke.points.skip(1)) {
      path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path, markerPaint);
  }

  void _drawRectangle(Canvas canvas, AnnotationStroke stroke, Paint paint) {
    if (stroke.points.length < 2) return;
    final rect = Rect.fromPoints(stroke.points.first, stroke.points.last);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      paint,
    );
  }

  void _drawArrow(Canvas canvas, AnnotationStroke stroke, Paint paint) {
    if (stroke.points.length < 2) return;
    final start = stroke.points.first;
    final end = stroke.points.last;

    // Don't draw if the points are the same (zero-length drag)
    if ((end - start).distance < 5) return;

    canvas.drawLine(start, end, paint);
    _drawArrowHead(canvas, start, end, paint);
  }

  void _drawArrowHead(Canvas canvas, Offset start, Offset end, Paint paint) {
    final arrowSize = (paint.strokeWidth * 3.5).clamp(10.0, 22.0);
    final angle = math.atan2(
      end.dy - start.dy,
      end.dx - start.dx,
    );
    final path = Path();
    path.moveTo(end.dx, end.dy);
    path.lineTo(
      end.dx - arrowSize * math.cos(angle - math.pi / 6),
      end.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    path.moveTo(end.dx, end.dy);
    path.lineTo(
      end.dx - arrowSize * math.cos(angle + math.pi / 6),
      end.dy - arrowSize * math.sin(angle + math.pi / 6),
    );
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) => true;
}
