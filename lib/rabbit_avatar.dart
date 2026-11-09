import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'rabbit_story.dart';
import 'app_language.dart';

class RabbitAvatar extends StatefulWidget {
  const RabbitAvatar({super.key, required this.mood, this.size = 62});
  final RabbitMood mood;
  final double size;
  @override
  State<RabbitAvatar> createState() => _RabbitAvatarState();
}

class _RabbitAvatarState extends State<RabbitAvatar> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label:
        '${context.t('小兔阿跃')}${context.english ? ', ' : '，'}${context.t(switch (widget.mood) {
          RabbitMood.starry => '欣喜',
          RabbitMood.listening => '倾听',
          RabbitMood.thoughtful => '思考',
          RabbitMood.gentle => '陪伴',
        })}',
    child: MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedRotation(
        turns: MediaQuery.disableAnimationsOf(context)
            ? 0
            : hovered
            ? -.025
            : 0,
        duration: const Duration(milliseconds: 180),
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(painter: _RabbitPainter(widget.mood)),
        ),
      ),
    ),
  );
}

class _RabbitPainter extends CustomPainter {
  const _RabbitPainter(this.mood);
  final RabbitMood mood;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final ink = Paint()
      ..color = const Color(0xff385952)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void fill(Path path, Color color) {
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, ink);
    }

    void oval(Rect rect, Color color) {
      canvas.drawOval(rect, Paint()..color = color);
    }

    final soft = mood == RabbitMood.gentle
        ? const Color(0xffeaf0f5)
        : mood == RabbitMood.starry
        ? const Color(0xfffff1d5)
        : const Color(0xffe9f1e8);
    oval(const Rect.fromLTWH(4, 15, 92, 81), soft);
    oval(const Rect.fromLTWH(23, 86, 58, 10), const Color(0xffd6e5dc));
    fill(
      Path()
        ..moveTo(31, 47)
        ..cubicTo(18, 27, 25, 3, 33, 4)
        ..cubicTo(43, 4, 44, 32, 42, 47)
        ..close(),
      const Color(0xfffffcf2),
    );
    fill(
      Path()
        ..moveTo(54, 46)
        ..cubicTo(53, 29, 56, 7, 65, 9)
        ..cubicTo(70, 9, 75, 19, 72, 22)
        ..cubicTo(69, 25, 65, 20, 65, 19)
        ..cubicTo(68, 30, 67, 37, 65, 47)
        ..close(),
      const Color(0xfffffcf2),
    );
    oval(const Rect.fromLTWH(29, 13, 8, 29), const Color(0xfff1c9bc));
    canvas.drawPath(
      Path()
        ..moveTo(61, 18)
        ..quadraticBezierTo(65, 25, 61, 37),
      Paint()
        ..color = const Color(0xfff1c9bc)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    fill(
      Path()
        ..moveTo(28, 75)
        ..quadraticBezierTo(21, 91, 34, 92)
        ..lineTo(69, 92)
        ..quadraticBezierTo(82, 91, 71, 73)
        ..close(),
      const Color(0xfffffcf2),
    );
    fill(
      Path()
        ..moveTo(27, 72)
        ..quadraticBezierTo(42, 79, 67, 73)
        ..lineTo(65, 82)
        ..quadraticBezierTo(43, 88, 27, 80)
        ..close(),
      const Color(0xff75b4a5),
    );
    fill(
      Path()
        ..moveTo(56, 80)
        ..lineTo(67, 78)
        ..lineTo(75, 90)
        ..lineTo(67, 89)
        ..lineTo(63, 94)
        ..close(),
      const Color(0xff75b4a5),
    );
    fill(
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(19, 37, 62, 42),
          const Radius.circular(23),
        ),
      ),
      const Color(0xfffffcf2),
    );
    oval(const Rect.fromLTWH(26, 62, 12, 7), const Color(0xffedc0ad));
    oval(const Rect.fromLTWH(64, 62, 12, 7), const Color(0xffedc0ad));
    if (mood == RabbitMood.starry) {
      for (final x in [37.0, 64.0]) {
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final angle = -math.pi / 2 + i * math.pi / 5;
          final radius = i.isEven ? 6.4 : 3.1;
          final point = Offset(
            x + math.cos(angle) * radius,
            56 + math.sin(angle) * radius,
          );
          if (i == 0) {
            star.moveTo(point.dx, point.dy);
          } else {
            star.lineTo(point.dx, point.dy);
          }
        }
        star.close();
        fill(star, const Color(0xffdfae45));
      }
      canvas.drawPath(
        Path()
          ..moveTo(44, 67)
          ..quadraticBezierTo(51, 77, 58, 67),
        ink,
      );
    } else if (mood == RabbitMood.gentle) {
      canvas.drawPath(
        Path()
          ..moveTo(32, 56)
          ..quadraticBezierTo(37, 60, 42, 56)
          ..moveTo(59, 56)
          ..quadraticBezierTo(64, 60, 69, 56),
        ink,
      );
      canvas.drawPath(
        Path()
          ..moveTo(47, 69)
          ..quadraticBezierTo(51, 67, 55, 69),
        ink,
      );
    } else {
      oval(const Rect.fromLTWH(34, 52, 5, 8), const Color(0xff385952));
      oval(const Rect.fromLTWH(62, 52, 5, 8), const Color(0xff385952));
      canvas.drawPath(
        Path()
          ..moveTo(45, 67)
          ..quadraticBezierTo(50, 72, 55, 67),
        ink,
      );
    }
    fill(
      Path()
        ..moveTo(48, 62)
        ..lineTo(54, 62)
        ..quadraticBezierTo(51, 67, 48, 62)
        ..close(),
      const Color(0xffbd8877),
    );
    if (mood == RabbitMood.listening) {
      fill(
        Path()..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(27, 81, 21, 16),
            const Radius.circular(3),
          ),
        ),
        const Color(0xffe1c495),
      );
      canvas.drawLine(const Offset(32, 83), const Offset(32, 94), ink);
      canvas.drawLine(const Offset(37, 86), const Offset(43, 86), ink);
    } else if (mood == RabbitMood.thoughtful) {
      oval(const Rect.fromLTWH(60, 69, 12, 10), const Color(0xfffffcf2));
      canvas.drawArc(
        const Rect.fromLTWH(59, 68, 14, 11),
        0,
        math.pi,
        false,
        ink,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RabbitPainter oldDelegate) => mood != oldDelegate.mood;
}
