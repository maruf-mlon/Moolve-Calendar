import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  runApp(CalendarApp(prefs: prefs));
}

//  EVENT MODEL
enum EventType { birthday, running, date, meeting }

extension EventTypeX on EventType {
  String label(bool isRu) {
    switch (this) {
      case EventType.birthday: return isRu ? 'День рождения' : 'Birthday';
      case EventType.running:  return isRu ? 'Пробежка'     : 'Running';
      case EventType.date:     return isRu ? 'Свидание'     : 'Date';
      case EventType.meeting:  return isRu ? 'Встреча'      : 'Meeting';
    }
  }
  String get emoji {
    switch (this) {
      case EventType.birthday: return '🎂';
      case EventType.running:  return '🏃';
      case EventType.date:     return '❤️';
      case EventType.meeting:  return '📋';
    }
  }
  Color get color {
    switch (this) {
      case EventType.birthday: return const Color(0xFFFF4081);
      case EventType.running:  return const Color(0xFF00C853);
      case EventType.date:     return const Color(0xFFE91E63);
      case EventType.meeting:  return const Color(0xFF2196F3);
    }
  }
}

class DayEvent {
  final EventType type;
  final String note;
  DayEvent({required this.type, required this.note});

  Map<String, dynamic> toJson() => {'type': type.index, 'note': note};
  factory DayEvent.fromJson(Map<String, dynamic> j) =>
      DayEvent(type: EventType.values[j['type'] as int], note: j['note'] as String);
}

//  LOCALIZATION
const _monthNamesRu = [
  'Январь','Февраль','Март','Апрель','Май','Июнь',
  'Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь',
];
const _monthNamesEn = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December',
];
const _weekDaysRu = ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'];
const _weekDaysEn = ['Mo','Tu','We','Th','Fr','Sa','Su'];

String _monthName(int month, bool isRu) =>
    isRu ? _monthNamesRu[month - 1] : _monthNamesEn[month - 1];
List<String> _weekDays(bool isRu) => isRu ? _weekDaysRu : _weekDaysEn;

String _t(String ru, String en, bool isRu) => isRu ? ru : en;

//  APP ROOT
class CalendarApp extends StatefulWidget {
  final SharedPreferences prefs;
  const CalendarApp({super.key, required this.prefs});
  @override
  State<CalendarApp> createState() => _CalendarAppState();
}

class _CalendarAppState extends State<CalendarApp> {
  bool _isDark = false;
  bool _isRu = true;

  @override
  void initState() {
    super.initState();
    _isDark = widget.prefs.getBool('isDark') ?? false;
    _isRu   = widget.prefs.getBool('isRu') ?? true;
  }

  void _toggleTheme() {
    setState(() => _isDark = !_isDark);
    widget.prefs.setBool('isDark', _isDark);
  }

  void _toggleLang() {
    setState(() => _isRu = !_isRu);
    widget.prefs.setBool('isRu', _isRu);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Moolve Calendar',
      theme: ThemeData(
        brightness: _isDark ? Brightness.dark : Brightness.light,
        fontFamily: 'Georgia',
      ),
      home: CalendarHome(
        isDark: _isDark,
        isRu: _isRu,
        prefs: widget.prefs,
        onToggleTheme: _toggleTheme,
        onToggleLang: _toggleLang,
      ),
    );
  }
}

//  SCENE
enum _Scene { newYear, spring, summer, autumn }
_Scene _sceneFor(int m) {
  if (m == 12 || m == 1 || m == 2 || m == 11) return _Scene.newYear;
  if (m >= 3 && m <= 5) return _Scene.spring;
  if (m >= 6 && m <= 8) return _Scene.summer;
  return _Scene.autumn;
}

//  HOME
class CalendarHome extends StatefulWidget {
  final bool isDark;
  final bool isRu;
  final SharedPreferences prefs;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLang;
  const CalendarHome({
    super.key,
    required this.isDark,
    required this.isRu,
    required this.prefs,
    required this.onToggleTheme,
    required this.onToggleLang,
  });
  @override
  State<CalendarHome> createState() => _CalendarHomeState();
}

class _CalendarHomeState extends State<CalendarHome> {
  final Map<String, List<DayEvent>> _ev = {};
  late int _year;
  final _now = DateTime.now();
  bool _confetti = false;

  @override
  void initState() {
    super.initState();
    _year = _now.year;
    _load();
  }

  void _load() {
    final raw = widget.prefs.getString('cal_events_v3');
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        m.forEach((k, v) {
          _ev[k] = (v as List).map((e) => DayEvent.fromJson(e as Map<String, dynamic>)).toList();
        });
      } catch (_) {}
    }
    _checkBirthday();
  }

  void _save() {
    final out = <String, dynamic>{};
    _ev.forEach((k, v) => out[k] = v.map((e) => e.toJson()).toList());
    widget.prefs.setString('cal_events_v3', jsonEncode(out));
  }

  void _checkBirthday() {
    final k = _key(_now.year, _now.month, _now.day);
    if ((_ev[k] ?? []).any((e) => e.type == EventType.birthday)) {
      setState(() => _confetti = true);
    }
  }

  String _key(int y, int m, int d) =>
      '$y-${m.toString().padLeft(2,'0')}-${d.toString().padLeft(2,'0')}';

  List<DayEvent> _evFor(int m, int d) => _ev[_key(_year, m, d)] ?? [];
  bool _today(int m, int d) => _now.month == m && _now.day == d && _now.year == _year;

  // ── Settings bottom sheet ─────────────────────
  void _openSettings() {
    final isDark = widget.isDark;
    final isRu   = widget.isRu;
    final bg  = isDark ? const Color(0xFF12123A) : Colors.white;
    final txt = isDark ? Colors.white : const Color(0xFF1A3A5C);
    final acc = isDark ? const Color(0xFF7C4DFF) : const Color(0xFF2196F3);
    final sub = isDark ? Colors.white54 : const Color(0xFF1A3A5C).withOpacity(0.45);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: acc.withOpacity(0.2), blurRadius: 28)],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: sub, borderRadius: BorderRadius.circular(2)),
          )),
          Text(
            _t('Настройки', 'Settings', isRu),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: txt),
          ),
          const SizedBox(height: 24),

          // Theme toggle row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: acc.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: acc.withOpacity(0.2)),
            ),
            child: Row(children: [
              Text(isDark ? '🌙' : '☀️', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(child: Text(
                _t(isDark ? 'Тёмная тема' : 'Светлая тема',
                    isDark ? 'Dark theme'  : 'Light theme', isRu),
                style: TextStyle(color: txt, fontSize: 15, fontWeight: FontWeight.w600),
              )),
              Switch(
                value: isDark,
                activeColor: acc,
                onChanged: (_) {
                  Navigator.pop(context);
                  widget.onToggleTheme();
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Language toggle row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: acc.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: acc.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Text('🌍', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(child: Text(
                _t('Язык', 'Language', isRu),
                style: TextStyle(color: txt, fontSize: 15, fontWeight: FontWeight.w600),
              )),
              // RU / EN pill toggle
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  widget.onToggleLang();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 80, height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    color: acc.withOpacity(0.15),
                    border: Border.all(color: acc.withOpacity(0.4)),
                  ),
                  child: Stack(children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      left: isRu ? 2 : 42, top: 2,
                      child: Container(
                        width: 36, height: 30,
                        decoration: BoxDecoration(
                          color: acc,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(child: Text(
                          isRu ? 'RU' : 'EN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        )),
                      ),
                    ),
                    Positioned(
                      left: isRu ? 44 : 6, top: 8,
                      child: Text(
                        isRu ? 'EN' : 'RU',
                        style: TextStyle(
                          color: txt.withOpacity(0.4),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: widget.isDark ? const _NightBg() : const _DayBg()),
      Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: Column(children: [
          _TopBar(
            isDark: widget.isDark,
            isRu: widget.isRu,
            year: _year,
            onYear: (y) => setState(() => _year = y),
            onSettings: _openSettings,
          ),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: 12,
            itemBuilder: (ctx, i) {
              final m = i + 1;
              return _MonthBlock(
                month: m, year: _year,
                isDark: widget.isDark,
                isRu: widget.isRu,
                eventsFor: (d) => _evFor(m, d),
                isToday: (d) => _today(m, d),
                onTap: (d) => _showSheet(ctx, m, d),
              );
            },
          )),
        ])),
      ),
      if (_confetti)
        Positioned.fill(child: _ConfettiLayer(
            onDismiss: () => setState(() => _confetti = false))),
    ]);
  }

  void _showSheet(BuildContext ctx, int m, int d) {
    final k = _key(_year, m, d);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _Sheet(
        month: m, day: d, year: _year,
        isDark: widget.isDark,
        isRu: widget.isRu,
        current: List.from(_ev[k] ?? []),
        onSave: (list) {
          setState(() { list.isEmpty ? _ev.remove(k) : _ev[k] = list; });
          _save();
          if (list.any((e) => e.type == EventType.birthday) && _today(m, d)) {
            setState(() => _confetti = true);
          }
        },
      ),
    );
  }
}

//  TOP BAR  — тема убрана, добавлена шестерёнка
class _TopBar extends StatelessWidget {
  final bool isDark;
  final bool isRu;
  final int year;
  final ValueChanged<int> onYear;
  final VoidCallback onSettings;

  const _TopBar({
    required this.isDark,
    required this.isRu,
    required this.year,
    required this.onYear,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final txt = isDark ? Colors.white : const Color(0xFF1A3A5C);
    final acc = isDark ? const Color(0xFF7C4DFF) : const Color(0xFF2196F3);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        _Btn(icon: Icons.chevron_left_rounded, color: acc,
            onTap: () => onYear(year - 1)),
        const SizedBox(width: 8),
        Text('$year', style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold,
            color: txt, letterSpacing: 2)),
        const SizedBox(width: 8),
        _Btn(icon: Icons.chevron_right_rounded, color: acc,
            onTap: () => onYear(year + 1)),
        const Spacer(),
        // ⚙️ Settings button
        GestureDetector(
          onTap: onSettings,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: acc.withOpacity(0.15),
              border: Border.all(color: acc.withOpacity(0.4)),
              boxShadow: [BoxShadow(color: acc.withOpacity(0.3), blurRadius: 8)],
            ),
            child: Icon(Icons.settings_rounded, color: acc, size: 22),
          ),
        ),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback onTap;
  const _Btn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(shape: BoxShape.circle,
          color: color.withOpacity(0.15),
          border: Border.all(color: color.withOpacity(0.4))),
      child: Icon(icon, color: color, size: 18),
    ),
  );
}

//  MONTH BLOCK
class _MonthBlock extends StatelessWidget {
  final int month, year; final bool isDark, isRu;
  final List<DayEvent> Function(int) eventsFor;
  final bool Function(int) isToday;
  final void Function(int) onTap;
  const _MonthBlock({required this.month, required this.year,
    required this.isDark, required this.isRu,
    required this.eventsFor, required this.isToday, required this.onTap});

  int get _days => DateUtils.getDaysInMonth(year, month);
  int get _startWd => DateTime(year, month, 1).weekday - 1;

  @override
  Widget build(BuildContext context) {
    final rows = ((_startWd + _days) / 7).ceil();
    final acc = isDark ? const Color(0xFF7C4DFF) : const Color(0xFF2196F3);
    final wd = _weekDays(isRu);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark
            ? Colors.white.withOpacity(0.1) : const Color(0xFF90CAF9).withOpacity(0.4)),
        boxShadow: [BoxShadow(color: acc.withOpacity(0.08), blurRadius: 20, spreadRadius: 2)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: [
          _Header(month: month, isDark: isDark, isRu: isRu, scene: _sceneFor(month)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: List.generate(7, (i) {
              final isSat = i == 5; final isSun = i == 6;
              return Expanded(child: Center(child: Text(wd[i],
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                    color: isSun ? const Color(0xFFFF5252)
                        : isSat ? acc
                        : (isDark ? Colors.white54 : const Color(0xFF1A3A5C).withOpacity(0.45)),
                  ))));
            })),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Column(children: List.generate(rows, (row) => Row(
              children: List.generate(7, (col) {
                final idx = row * 7 + col;
                final d = idx - _startWd + 1;
                if (d < 1 || d > _days) return const Expanded(child: SizedBox(height: 46));
                return Expanded(child: _Cell(
                  day: d, col: col, isDark: isDark,
                  events: eventsFor(d), isToday: isToday(d),
                  onTap: () => onTap(d),
                ));
              }),
            ))),
          ),
        ]),
      ),
    );
  }
}

//  MONTH HEADER
class _Header extends StatelessWidget {
  final int month; final bool isDark, isRu; final _Scene scene;
  const _Header({required this.month, required this.isDark,
    required this.isRu, required this.scene});

  List<Color> _grad() {
    if (isDark) return [const Color(0xFF7C4DFF).withOpacity(0.7), const Color(0xFF40C4FF).withOpacity(0.5)];
    switch (scene) {
      case _Scene.newYear: return [const Color(0xFF1565C0), const Color(0xFF42A5F5)];
      case _Scene.spring:  return [const Color(0xFF43A047), const Color(0xFFAED581)];
      case _Scene.summer:  return [const Color(0xFF0288D1), const Color(0xFF00ACC1)];
      case _Scene.autumn:  return [const Color(0xFFBF360C), const Color(0xFFFFB300)];
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 115,
    decoration: BoxDecoration(gradient: LinearGradient(
        colors: _grad(), begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _IlluPainter(scene: scene, isDark: isDark))),
      Positioned(left: 16, bottom: 12, child: Text(
        _monthName(month, isRu),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black45, blurRadius: 6)]),
      )),
    ]),
  );
}

//  ILLUSTRATION PAINTER — без изменений
class _IlluPainter extends CustomPainter {
  final _Scene scene; final bool isDark;
  const _IlluPainter({required this.scene, required this.isDark});

  @override
  void paint(Canvas c, Size s) {
    switch (scene) {
      case _Scene.newYear: _newYear(c, s); break;
      case _Scene.spring:  _spring(c, s);  break;
      case _Scene.summer:  _summer(c, s);  break;
      case _Scene.autumn:  _autumn(c, s);  break;
    }
  }

  Paint _p([Color col = Colors.white, PaintingStyle st = PaintingStyle.fill]) =>
      Paint()..style = st..color = col;

  void _cloud(Canvas c, double cx, double cy, double sc) {
    final p = _p(Colors.white.withOpacity(0.32));
    c.drawCircle(Offset(cx, cy), 15 * sc, p);
    c.drawCircle(Offset(cx + 17*sc, cy + 4*sc), 11 * sc, p);
    c.drawCircle(Offset(cx - 14*sc, cy + 5*sc), 10 * sc, p);
    c.drawCircle(Offset(cx + 6*sc, cy + 10*sc), 12 * sc, p);
    c.drawCircle(Offset(cx - 5*sc, cy + 10*sc), 11 * sc, p);
  }

  void _sun(Canvas c, double cx, double cy, double r) {
    c.drawCircle(Offset(cx, cy), r, _p(Colors.yellow.withOpacity(0.9)));
    final rays = Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 2..color = Colors.yellow.withOpacity(0.45);
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4;
      c.drawLine(Offset(cx + cos(a)*(r+3), cy + sin(a)*(r+3)),
          Offset(cx + cos(a)*(r+14), cy + sin(a)*(r+14)), rays);
    }
  }

  void _fir(Canvas c, double cx, double base, double h) {
    final p = _p(Colors.white.withOpacity(0.38));
    for (int i = 0; i < 3; i++) {
      final tier = h * (0.42 + i * 0.2);
      final y = base - h * (0.55 - i * 0.17);
      c.drawPath(Path()
        ..moveTo(cx, y - tier*0.5)
        ..lineTo(cx - tier*0.45, y + tier*0.15)
        ..lineTo(cx + tier*0.45, y + tier*0.15)
        ..close(), p);
    }
    c.drawRect(Rect.fromCenter(center: Offset(cx, base+5), width: 7, height: 11),
        _p(Colors.white.withOpacity(0.2)));
  }

  void _newYear(Canvas c, Size s) {
    c.drawRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, s.height*0.72, s.width, s.height),
        topLeft: const Radius.circular(28), topRight: const Radius.circular(28)),
        _p(Colors.white.withOpacity(0.22)));
    _fir(c, s.width*0.7, s.height*0.73, 40);
    _fir(c, s.width*0.82, s.height*0.7, 28);
    _fir(c, s.width*0.58, s.height*0.75, 24);
    c.drawCircle(Offset(s.width*0.15, s.height*0.22), 15, _p(Colors.white.withOpacity(0.9)));
    c.drawCircle(Offset(s.width*0.19, s.height*0.19), 12, _p(const Color(0xFF1565C0)));
    final rnd = Random(7);
    for (int i = 0; i < 22; i++) {
      c.drawCircle(Offset(rnd.nextDouble()*s.width, rnd.nextDouble()*s.height*0.65),
          rnd.nextDouble()*2 + 0.5, _p(Colors.white.withOpacity(0.7)));
    }
  }

  void _flower(Canvas c, double cx, double cy, double r) {
    final petals = _p(Colors.white.withOpacity(0.8));
    for (int i = 0; i < 5; i++) {
      final a = i * 2 * pi / 5;
      c.drawCircle(Offset(cx + cos(a)*r, cy + sin(a)*r), r*0.7, petals);
    }
    c.drawCircle(Offset(cx, cy), r*0.6, _p(Colors.yellow.withOpacity(0.9)));
    c.drawLine(Offset(cx, cy+r+2), Offset(cx, cy+r+14),
        Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Colors.white.withOpacity(0.5));
  }

  void _spring(Canvas c, Size s) {
    c.drawRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, s.height*0.75, s.width, s.height),
        topLeft: const Radius.circular(28), topRight: const Radius.circular(28)),
        _p(Colors.white.withOpacity(0.18)));
    _sun(c, s.width*0.8, s.height*0.22, 18);
    _cloud(c, s.width*0.14, s.height*0.17, 0.85);
    _cloud(c, s.width*0.47, s.height*0.11, 1.05);
    _flower(c, s.width*0.2, s.height*0.84, 8);
    _flower(c, s.width*0.38, s.height*0.79, 7);
    _flower(c, s.width*0.57, s.height*0.86, 9);
  }

  void _summer(Canvas c, Size s) {
    c.drawRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, s.height*0.58, s.width, s.height),
        topLeft: const Radius.circular(22), topRight: const Radius.circular(22)),
        _p(Colors.white.withOpacity(0.22)));
    for (int w = 0; w < 3; w++) {
      final wy = s.height*(0.63 + w*0.07);
      final path = Path()..moveTo(0, wy);
      for (double x = 0; x <= s.width; x += 8) {
        path.lineTo(x, wy + sin(x/14 + w)*3);
      }
      c.drawPath(path, Paint()..style = PaintingStyle.stroke
        ..strokeWidth = 1.8..color = Colors.white.withOpacity(0.4));
    }
    c.drawRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, s.height*0.72, s.width, s.height),
        topLeft: const Radius.circular(10), topRight: const Radius.circular(10)),
        _p(Colors.yellow.withOpacity(0.22)));
    _sun(c, s.width*0.76, s.height*0.18, 20);
    _cloud(c, s.width*0.14, s.height*0.14, 0.8);
    _cloud(c, s.width*0.45, s.height*0.09, 1.0);
    c.drawArc(Rect.fromCenter(center: Offset(s.width*0.22, s.height*0.71),
        width: 54, height: 34), pi, pi, true, _p(Colors.red.withOpacity(0.5)));
    c.drawArc(Rect.fromCenter(center: Offset(s.width*0.22, s.height*0.71),
        width: 54, height: 34), pi+0.35, pi/3, true, _p(Colors.white.withOpacity(0.45)));
    c.drawLine(Offset(s.width*0.22, s.height*0.71), Offset(s.width*0.22, s.height*0.86),
        Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Colors.white.withOpacity(0.6));
  }

  void _autumn(Canvas c, Size s) {
    c.drawRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, s.height*0.75, s.width, s.height),
        topLeft: const Radius.circular(28), topRight: const Radius.circular(28)),
        _p(Colors.white.withOpacity(0.18)));
    final trunk = Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 5..color = Colors.white.withOpacity(0.4)..strokeCap = StrokeCap.round;
    c.drawLine(Offset(s.width*0.68, s.height*0.75), Offset(s.width*0.68, s.height*0.33), trunk);
    c.drawLine(Offset(s.width*0.68, s.height*0.5), Offset(s.width*0.57, s.height*0.39), trunk);
    c.drawLine(Offset(s.width*0.68, s.height*0.44), Offset(s.width*0.79, s.height*0.37), trunk);
    c.drawCircle(Offset(s.width*0.68, s.height*0.26), 27, _p(Colors.orange.withOpacity(0.45)));
    c.drawCircle(Offset(s.width*0.59, s.height*0.30), 18, _p(Colors.deepOrange.withOpacity(0.38)));
    c.drawCircle(Offset(s.width*0.77, s.height*0.29), 17, _p(Colors.yellow.withOpacity(0.4)));
    final rnd = Random(13);
    final lc = [Colors.orange, Colors.deepOrange, Colors.yellow, Colors.red];
    for (int i = 0; i < 14; i++) {
      c.save();
      c.translate(rnd.nextDouble()*s.width*0.95, rnd.nextDouble()*s.height*0.95);
      c.rotate(rnd.nextDouble()*2*pi);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 11, height: 6),
          _p(lc[rnd.nextInt(lc.length)].withOpacity(0.55)));
      c.restore();
    }
    c.drawCircle(Offset(s.width*0.15, s.height*0.2), 14, _p(Colors.yellow.withOpacity(0.5)));
  }

  @override
  bool shouldRepaint(_IlluPainter o) => false;
}

//  DAY CELL
class _Cell extends StatelessWidget {
  final int day, col; final bool isDark, isToday;
  final List<DayEvent> events; final VoidCallback onTap;
  const _Cell({required this.day, required this.col, required this.isDark,
    required this.isToday, required this.events, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSun = col == 6; final isSat = col == 5;
    final acc = isDark ? const Color(0xFF7C4DFF) : const Color(0xFF2196F3);
    Color txt;
    if (isToday) txt = Colors.white;
    else if (isSun) txt = const Color(0xFFFF5252);
    else if (isSat) txt = acc;
    else txt = isDark ? Colors.white.withOpacity(0.85) : const Color(0xFF1A3A5C);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: isToday ? LinearGradient(
              colors: isDark
                  ? [const Color(0xFF7C4DFF), const Color(0xFF40C4FF)]
                  : [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
              begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: isToday ? null
              : events.isNotEmpty ? events.first.type.color.withOpacity(isDark ? 0.22 : 0.15)
              : isDark ? Colors.white.withOpacity(0.04) : const Color(0xFF2196F3).withOpacity(0.04),
          border: events.isNotEmpty && !isToday
              ? Border.all(color: events.first.type.color.withOpacity(0.45)) : null,
          boxShadow: isToday ? [BoxShadow(color: acc.withOpacity(0.5), blurRadius: 8)] : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$day', style: TextStyle(fontSize: 13,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal, color: txt)),
          if (events.isNotEmpty)
            Wrap(alignment: WrapAlignment.center, children: events.take(3)
                .map((e) => Text(e.type.emoji, style: const TextStyle(fontSize: 7))).toList()),
        ]),
      ),
    );
  }
}

//  EVENT SHEET
class _Sheet extends StatefulWidget {
  final int month, day, year; final bool isDark, isRu;
  final List<DayEvent> current;
  final void Function(List<DayEvent>) onSave;
  const _Sheet({required this.month, required this.day, required this.year,
    required this.isDark, required this.isRu,
    required this.current, required this.onSave});
  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  late List<DayEvent> _list;
  EventType? _pick;
  final _ctrl = TextEditingController();

  @override
  void initState() { super.initState(); _list = List.from(widget.current); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _add() {
    if (_pick == null) return;
    _list.removeWhere((e) => e.type == _pick);
    _list.add(DayEvent(type: _pick!, note: _ctrl.text.trim()));
    setState(() { _pick = null; _ctrl.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    final isRu = widget.isRu;
    final bg  = widget.isDark ? const Color(0xFF12123A) : Colors.white;
    final txt = widget.isDark ? Colors.white : const Color(0xFF1A3A5C);
    final acc = widget.isDark ? const Color(0xFF7C4DFF) : const Color(0xFF2196F3);
    final sub = widget.isDark ? Colors.white54 : const Color(0xFF1A3A5C).withOpacity(0.45);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: acc.withOpacity(0.2), blurRadius: 28)]),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: sub, borderRadius: BorderRadius.circular(2)))),
                Text('${_monthName(widget.month, isRu)}, ${widget.day}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: txt)),
                const SizedBox(height: 3),
                Text('${widget.year}', style: TextStyle(color: sub, fontSize: 13)),
                const SizedBox(height: 20),

                if (_list.isNotEmpty) ...[
                  Text(_t('События', 'Events', isRu),
                      style: TextStyle(color: sub, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._list.map((e) => _EvTile(ev: e, isDark: widget.isDark, isRu: isRu,
                      onDel: () => setState(() => _list.removeWhere((x) => x.type == e.type)))),
                  const SizedBox(height: 16),
                ],

                Text(_t('Добавить', 'Add', isRu),
                    style: TextStyle(color: sub, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: EventType.values.map((t) {
                  final sel = _pick == t;
                  final has = _list.any((e) => e.type == t);
                  return GestureDetector(
                    onTap: has ? null : () => setState(() {
                      _pick = sel ? null : t; _ctrl.clear();
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? t.color : t.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: has
                            ? Colors.grey.withOpacity(0.3) : t.color.withOpacity(0.5)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(t.label(isRu), style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : has ? Colors.grey : txt)),
                      ]),
                    ),
                  );
                }).toList()),

                if (_pick != null) ...[
                  const SizedBox(height: 14),
                  TextField(controller: _ctrl, autofocus: true, style: TextStyle(color: txt),
                      decoration: InputDecoration(
                        hintText: _t('Заметка (необязательно)', 'Note (optional)', isRu),
                        hintStyle: TextStyle(color: sub),
                        filled: true, fillColor: acc.withOpacity(0.07),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: acc, width: 1.5)),
                      )),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: _add,
                    style: ElevatedButton.styleFrom(backgroundColor: _pick!.color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(
                      '${_t('Добавить', 'Add', isRu)} ${_pick!.emoji}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  )),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(foregroundColor: sub,
                        side: BorderSide(color: sub.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(_t('Закрыть', 'Close', isRu)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton(
                    onPressed: () { widget.onSave(_list); Navigator.pop(context); },
                    style: ElevatedButton.styleFrom(backgroundColor: acc,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14), elevation: 4),
                    child: Text(_t('Сохранить ✓', 'Save ✓', isRu),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  )),
                ]),
              ]),
        ),
      ),
    );
  }
}

class _EvTile extends StatelessWidget {
  final DayEvent ev; final bool isDark, isRu; final VoidCallback onDel;
  const _EvTile({required this.ev, required this.isDark,
    required this.isRu, required this.onDel});
  @override
  Widget build(BuildContext context) {
    final txt = isDark ? Colors.white : const Color(0xFF1A3A5C);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: ev.type.color.withOpacity(isDark ? 0.18 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ev.type.color.withOpacity(0.35))),
      child: Row(children: [
        Text(ev.type.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ev.type.label(isRu),
              style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 13)),
          if (ev.note.isNotEmpty)
            Text(ev.note, style: TextStyle(color: txt.withOpacity(0.6), fontSize: 12)),
        ])),
        GestureDetector(onTap: onDel,
            child: Icon(Icons.delete_outline_rounded,
                color: Colors.red.withOpacity(0.6), size: 20)),
      ]),
    );
  }
}

//  DAY BACKGROUND
class _DayBg extends StatefulWidget {
  const _DayBg();
  @override
  State<_DayBg> createState() => _DayBgState();
}

class _DayBgState extends State<_DayBg> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          Color.lerp(const Color(0xFF42A5F5), const Color(0xFF1E88E5), _anim.value)!,
          Color.lerp(const Color(0xFF90CAF9), const Color(0xFFBBDEFB), _anim.value)!,
          Color.lerp(const Color(0xFFE3F2FD), const Color(0xFFF5F9FF), _anim.value)!,
        ],
      )),
      child: CustomPaint(painter: _SkyPainter(_anim.value)),
    ),
  );
}

class _SkyPainter extends CustomPainter {
  final double t;
  _SkyPainter(this.t);

  void _cloud(Canvas c, double cx, double cy, double sc) {
    final p = Paint()..style = PaintingStyle.fill..color = Colors.white.withOpacity(0.72);
    c.drawCircle(Offset(cx, cy), 22*sc, p);
    c.drawCircle(Offset(cx+25*sc, cy+5*sc), 16*sc, p);
    c.drawCircle(Offset(cx-18*sc, cy+6*sc), 14*sc, p);
    c.drawCircle(Offset(cx+9*sc, cy+11*sc), 18*sc, p);
    c.drawCircle(Offset(cx-6*sc, cy+11*sc), 16*sc, p);
  }

  @override
  void paint(Canvas c, Size s) {
    c.drawCircle(Offset(s.width*0.8, s.height*0.07), 55,
        Paint()..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35)
          ..color = Colors.yellow.withOpacity(0.25));
    c.drawCircle(Offset(s.width*0.8, s.height*0.07), 24,
        Paint()..color = Colors.yellow.withOpacity(0.9));
    final rays = Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 2.2..color = Colors.yellow.withOpacity(0.4);
    for (int i = 0; i < 8; i++) {
      final a = i*pi/4 + t*0.4;
      c.drawLine(Offset(s.width*0.8+cos(a)*28, s.height*0.07+sin(a)*28),
          Offset(s.width*0.8+cos(a)*40, s.height*0.07+sin(a)*40), rays);
    }
    _cloud(c, s.width*(0.1 + t*0.06), s.height*0.15, 0.9);
    _cloud(c, s.width*(0.55 - t*0.05), s.height*0.09, 1.1);
    _cloud(c, s.width*(0.28 + t*0.04), s.height*0.24, 0.7);
  }

  @override
  bool shouldRepaint(_SkyPainter o) => o.t != t;
}

//  NIGHT BACKGROUND
class _NightBg extends StatefulWidget {
  const _NightBg();
  @override
  State<_NightBg> createState() => _NightBgState();
}

class _NightBgState extends State<_NightBg> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    final rnd = Random(42);
    _stars = List.generate(90, (_) => _Star(
        x: rnd.nextDouble(), y: rnd.nextDouble(),
        r: rnd.nextDouble()*1.8+0.4, phase: rnd.nextDouble()*2*pi));
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF0D0D2B), Color(0xFF1A1040), Color(0xFF0D0D2B)],
      )),
      child: CustomPaint(painter: _StarPainter(_stars, _anim.value)),
    ),
  );
}

class _Star {
  final double x,y,r,phase;
  const _Star({required this.x, required this.y, required this.r, required this.phase});
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars; final double t;
  _StarPainter(this.stars, this.t);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..style = PaintingStyle.fill;
    for (final st in stars) {
      final tw = sin(st.phase + t*pi)*0.5+0.5;
      p.color = Colors.white.withOpacity(0.25+tw*0.65);
      c.drawCircle(Offset(st.x*s.width, st.y*s.height), st.r, p);
    }
    c.drawCircle(Offset(s.width*0.82, s.height*0.07), 60,
        Paint()..maskFilter=const MaskFilter.blur(BlurStyle.normal,30)
          ..color=const Color(0xFF7C4DFF).withOpacity(0.15));
    c.drawCircle(Offset(s.width*0.82, s.height*0.07), 22,
        Paint()..color=const Color(0xFFEEEAFF));
    c.drawCircle(Offset(s.width*0.87, s.height*0.065), 17,
        Paint()..color=const Color(0xFF1A1040));
    c.drawLine(Offset(s.width*0.3+t*40, s.height*0.12),
        Offset(s.width*0.3+t*40+55, s.height*0.12+14),
        Paint()..style=PaintingStyle.stroke..strokeWidth=1.5..strokeCap=StrokeCap.round
          ..color=Colors.white.withOpacity(t*0.5));
  }
  @override
  bool shouldRepaint(_StarPainter o) => o.t != t;
}

//  CONFETTI LAYER
class _ConfettiLayer extends StatefulWidget {
  final VoidCallback onDismiss;
  const _ConfettiLayer({required this.onDismiss});
  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Piece> _pieces;

  static const _cols = [
    Color(0xFFFF5252), Color(0xFFFFD740), Color(0xFF69F0AE),
    Color(0xFF40C4FF), Color(0xFFFF4081), Color(0xFFE040FB),
    Color(0xFFFFAB40), Color(0xFFB2FF59),
  ];

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _pieces = List.generate(110, (_) => _Piece(
      x: rnd.nextDouble(), size: rnd.nextDouble()*12+5,
      color: _cols[rnd.nextInt(_cols.length)],
      spin: rnd.nextDouble()*2*pi, spinSpd: (rnd.nextDouble()-.5)*5,
      drift: (rnd.nextDouble()-.5)*0.12, delay: rnd.nextDouble()*0.5,
    ));
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    Future.delayed(const Duration(seconds: 7), () { if (mounted) widget.onDismiss(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onDismiss,
    child: AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _ConfettiPainter(_pieces, _ctrl.value),
        child: Container(color: Colors.transparent),
      ),
    ),
  );
}

class _Piece {
  final double x, size, spin, spinSpd, drift, delay; final Color color;
  const _Piece({required this.x, required this.size, required this.color,
    required this.spin, required this.spinSpd, required this.drift, required this.delay});
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces; final double t;
  _ConfettiPainter(this.pieces, this.t);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..style = PaintingStyle.fill;
    for (final pc in pieces) {
      final prog = ((t - pc.delay) % 1.0 + 1.0) % 1.0;
      final y = prog*(s.height+40) - 20;
      final x = pc.x*s.width + sin(prog*pi*3 + pc.drift*10)*38;
      p.color = pc.color.withOpacity(prog < 0.8 ? 1.0 : (1.0-prog)*5);
      c.save();
      c.translate(x, y);
      c.rotate(pc.spin + prog*pc.spinSpd*10);
      c.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: pc.size, height: pc.size*0.5),
          const Radius.circular(2)), p);
      c.restore();
    }
  }
  @override
  bool shouldRepaint(_ConfettiPainter o) => o.t != t;
}
