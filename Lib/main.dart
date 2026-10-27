import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ───────────────────────── রঙ ও স্টাইল ─────────────────────────
const kPaper = Color(0xFFF4EFE6);
const kCard = Color(0xFFFBF8F1);
const kInk = Color(0xFF1B1B1B);
const kMuted = Color(0xFF6B6558);
const kRule = Color(0xFFD9D1BF);
const kRed = Color(0xFFB3261E);
const kGreen = Color(0xFF2E6B3A);
const kAmber = Color(0xFF8A5A00);
const kGrey = Color(0xFF9A937F);
const kToday = Color(0xFFEAE2D0);
const kSerif = 'serif';

TextStyle ts(double size,
    {Color color = kInk, FontWeight? w, bool serif = false, double? h}) {
  return TextStyle(
    fontSize: size,
    color: color,
    fontWeight: w,
    height: h,
    fontFamily: serif ? kSerif : null,
  );
}

// ───────────────────────── সাহায্যকারী ফাংশন ─────────────────────────
const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

String bn(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 48 && r <= 57) {
      b.write(_bnDigits[r - 48]);
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

String toEn(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x09E6 && r <= 0x09EF) {
      b.write(r - 0x09E6);
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

String money(double v) {
  final neg = v < 0;
  final s = v.abs().round().toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return bn((neg ? '-' : '') + out.toString());
}

String numText(double v) {
  return bn(v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1));
}

const kMon = [
  'জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ', 'অক্টো', 'নভে', 'ডিসে'
];
const kWd = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি', 'রবি'];

String dShort(DateTime d) => '${bn(d.day.toString())} ${kMon[d.month - 1]}';

String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

// বেতন মাস: ২৬ তারিখ থেকে পরের মাসের ২৫ তারিখ
DateTime periodStartFor(DateTime t) {
  if (t.day >= 26) return DateTime(t.year, t.month, 26);
  return DateTime(t.year, t.month - 1, 26);
}

String fmtTime(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
}

TimeOfDay? parseTime(String s) {
  final m = RegExp(r'^(\d{1,2}):(\d{2}) (AM|PM)$').firstMatch(s);
  if (m == null) return null;
  var h = int.parse(m.group(1)!);
  final mi = int.parse(m.group(2)!);
  final pm = m.group(3) == 'PM';
  if (h == 12) h = 0;
  if (pm) h += 12;
  return TimeOfDay(hour: h % 24, minute: mi);
}

Color statusColor(String st) {
  switch (st) {
    case 'P':
      return kGreen;
    case 'A':
      return kRed;
    case 'L':
      return kAmber;
    default:
      return kGrey;
  }
}

// ───────────────────────── মডেল ─────────────────────────
class DayEntry {
  String st; // '', P, A, L  (শুক্রবার নিজে নিজে WL)
  double ot;
  bool night;
  String inT;
  String outT;

  DayEntry({
    this.st = '',
    this.ot = 0,
    this.night = false,
    this.inT = '',
    this.outT = '',
  });

  bool get isEmpty =>
      st == '' && ot == 0 && !night && inT == '' && outT == '';

  DayEntry copy() =>
      DayEntry(st: st, ot: ot, night: night, inT: inT, outT: outT);

  Map<String, dynamic> toJson() =>
      {'s': st, 'o': ot, 'n': night, 'i': inT, 'u': outT};

  factory DayEntry.fromJson(Map<String, dynamic> j) => DayEntry(
        st: (j['s'] ?? '') as String,
        ot: ((j['o'] ?? 0) as num).toDouble(),
        night: (j['n'] ?? false) as bool,
        inT: (j['i'] ?? '') as String,
        outT: (j['u'] ?? '') as String,
      );
}

class PaySettings {
  String name;
  double basic;
  double house;
  double med;
  double otRate;
  double transport;
  double nightBill;
  double pf;

  PaySettings({
    this.name = '',
    this.basic = 0,
    this.house = 0,
    this.med = 0,
    this.otRate = 0,
    this.transport = 0,
    this.nightBill = 0,
    this.pf = 0,
  });

  double get fixed => basic + house + med;

  Map<String, dynamic> toJson() => {
        'name': name,
        'basic': basic,
        'house': house,
        'med': med,
        'otRate': otRate,
        'transport': transport,
        'nightBill': nightBill,
        'pf': pf,
      };

  factory PaySettings.fromJson(Map<String, dynamic> j) {
    double d(String k) => ((j[k] ?? 0) as num).toDouble();
    return PaySettings(
      name: (j['name'] ?? '') as String,
      basic: d('basic'),
      house: d('house'),
      med: d('med'),
      otRate: d('otRate'),
      transport: d('transport'),
      nightBill: d('nightBill'),
      pf: d('pf'),
    );
  }
}

class Summary {
  int length = 0;
  int present = 0;
  int absent = 0;
  int leave = 0;
  int fridays = 0;
  int nights = 0;
  double otHours = 0;
  double fixed = 0;
  double standard = 0;
  double daily = 0;
  double combined = 0;
  double otPay = 0;
  double transportPay = 0;
  double nightPay = 0;
  double gross = 0;
  double pf = 0;
  double net = 0;
}

// শীটের সূত্র হুবহু:
// সমন্বিত = ফিক্সড + (উপস্থিত − স্ট্যান্ডার্ড দিন) × দৈনিক হার
// স্ট্যান্ডার্ড দিন = মাসের দিন − শুক্রবার সংখ্যা, দৈনিক হার = ফিক্সড ÷ স্ট্যান্ডার্ড
Summary calcSummary(
    PaySettings s, DateTime start, int length, Map<String, DayEntry> e) {
  final r = Summary();
  r.length = length;
  for (var i = 0; i < length; i++) {
    final d = DateTime(start.year, start.month, start.day + i);
    final en = e[dateKey(d)];
    if (d.weekday == DateTime.friday) {
      r.fridays++;
    } else if (en != null) {
      if (en.st == 'P') {
        r.present++;
      } else if (en.st == 'A') {
        r.absent++;
      } else if (en.st == 'L') {
        r.leave++;
      }
    }
    if (en != null) {
      r.otHours += en.ot;
      if (en.night) r.nights++;
    }
  }
  r.fixed = s.fixed;
  r.standard = (length - r.fridays).toDouble();
  r.daily = r.standard > 0 ? r.fixed / r.standard : 0;
  r.combined = r.fixed + (r.present - r.standard) * r.daily;
  r.otPay = r.otHours * s.otRate;
  r.transportPay = r.present * s.transport;
  r.nightPay = r.nights * s.nightBill;
  r.gross = r.combined + r.otPay + r.transportPay + r.nightPay;
  r.pf = s.pf;
  r.net = r.gross - r.pf;
  return r;
}

// ───────────────────────── অ্যাপ ─────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: kPaper,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const DutyApp());
}

class DutyApp extends StatelessWidget {
  const DutyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ডিউটি হিসাব',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(seedColor: kRed, brightness: Brightness.light),
        scaffoldBackgroundColor: kPaper,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  SharedPreferences? _prefs;
  PaySettings _s = PaySettings();
  bool _hasSettings = false;
  bool _ready = false;
  int _tab = 1; // 0 সেটআপ, 1 হাজিরা, 2 হিসাব
  late DateTime _start;
  Map<String, DayEntry> _e = {};

  @override
  void initState() {
    super.initState();
    _start = periodStartFor(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    final raw = p.getString('settings');
    if (raw != null) {
      try {
        _s = PaySettings.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
        _hasSettings = true;
      } catch (_) {}
    }
    if (!_hasSettings) _tab = 0;
    _readPeriod();
    if (!mounted) return;
    setState(() => _ready = true);
  }

  String get _periodKey =>
      'p_${_start.year}-${_start.month.toString().padLeft(2, '0')}';

  void _readPeriod() {
    _e = {};
    final raw = _prefs?.getString(_periodKey);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map;
      m.forEach((k, v) {
        _e[k as String] =
            DayEntry.fromJson(Map<String, dynamic>.from(v as Map));
      });
    } catch (_) {}
  }

  void _writePeriod() {
    final out = <String, dynamic>{};
    _e.forEach((k, v) {
      if (!v.isEmpty) out[k] = v.toJson();
    });
    _prefs?.setString(_periodKey, jsonEncode(out));
  }

  void _onSettings(PaySettings s) {
    setState(() {
      _s = s;
      _hasSettings = true;
    });
    _prefs?.setString('settings', jsonEncode(_s.toJson()));
  }

  void _shift(int delta) {
    setState(() {
      _start = DateTime(_start.year, _start.month + delta, 26);
      _readPeriod();
    });
  }

  DayEntry _entry(DateTime d) {
    final x = _e[dateKey(d)];
    return x == null ? DayEntry() : x.copy();
  }

  void _setEntry(DateTime d, DayEntry en) {
    setState(() {
      if (en.isEmpty) {
        _e.remove(dateKey(d));
      } else {
        _e[dateKey(d)] = en;
      }
    });
    _writePeriod();
  }

  void _cycle(DateTime d) {
    final en = _entry(d);
    const order = ['', 'P', 'A', 'L'];
    final i = order.indexOf(en.st);
    en.st = order[(i + 1) % order.length];
    _setEntry(d, en);
  }

  void _toggleNight(DateTime d) {
    final en = _entry(d);
    en.night = !en.night;
    _setEntry(d, en);
  }

  void _todayPresent(DateTime today) {
    final en = _entry(today);
    if (en.st == 'P') {
      en.st = '';
    } else {
      en.st = 'P';
      if (en.inT.isEmpty) en.inT = fmtTime(TimeOfDay.now());
    }
    _setEntry(today, en);
  }

  Future<void> _openSheet(DateTime d) async {
    final res = await showModalBottomSheet<DayEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kPaper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => DaySheet(date: d, entry: _entry(d)),
    );
    if (res != null && mounted) _setEntry(d, res);
  }

  // ───────────── build ─────────────
  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: kPaper,
        body: Center(child: CircularProgressIndicator(color: kRed)),
      );
    }
    final length = daysInMonth(_start.year, _start.month);
    final end = DateTime(_start.year, _start.month, _start.day + length - 1);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final inPeriod = !today.isBefore(_start) && !today.isAfter(end);
    int elapsed;
    if (today.isBefore(_start)) {
      elapsed = 0;
    } else if (today.isAfter(end)) {
      elapsed = length;
    } else {
      elapsed = today.difference(_start).inDays + 1;
    }
    final sm = calcSummary(_s, _start, length, _e);
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    Widget content;
    if (_tab == 0) {
      content = SetupTab(
        settings: _s,
        onChanged: _onSettings,
        onDone: () => setState(() => _tab = 1),
      );
    } else if (_tab == 1) {
      content = _attendanceTab(length, today);
    } else {
      content = _ledgerTab(sm);
    }

    return Scaffold(
      backgroundColor: kPaper,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
              children: [
                _masthead(end),
                _hero(sm, elapsed, inPeriod, today),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(key: ValueKey(_tab), child: content),
                ),
              ],
            ),
          ),
          if (!keyboardOpen)
            Positioned(
              left: 18,
              right: 18,
              bottom: 14 + bottomInset,
              child: _navBar(),
            ),
        ],
      ),
    );
  }

  Widget _masthead(DateTime end) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('ডিউটি হিসাব',
                  style: ts(21, w: FontWeight.w500, serif: true)),
            ),
            InkWell(
              onTap: () => _shift(-1),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.chevron_left, size: 20, color: kMuted),
              ),
            ),
            Text('${dShort(_start)} – ${dShort(end)}',
                style: ts(12, color: kMuted)),
            InkWell(
              onTap: () => _shift(1),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.chevron_right, size: 20, color: kMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(height: 1.5, color: kInk),
        const SizedBox(height: 2),
        Container(height: 1, color: kInk),
      ],
    );
  }

  Widget _hero(Summary sm, int elapsed, bool inPeriod, DateTime today) {
    final isFri = today.weekday == DateTime.friday;
    final te = _e[dateKey(today)];
    final done = te != null && te.st == 'P';
    final stats = [
      [numText(sm.otHours), 'ওটি ঘন্টা'],
      [bn(sm.nights.toString()), 'নাইট'],
      [bn(sm.absent.toString()), 'অনুপস্থিত'],
      [bn(sm.leave.toString()), 'ছুটি'],
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kRule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('এই মাসে উপস্থিত',
              style: ts(11, color: kRed, w: FontWeight.w500)),
          const SizedBox(height: 2),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: bn(sm.present.toString()),
                style: ts(42, w: FontWeight.w500, serif: true)),
            TextSpan(text: ' দিন', style: ts(18, color: kMuted)),
          ])),
          const SizedBox(height: 8),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: kRule),
                bottom: BorderSide(color: kRule),
              ),
            ),
            child: Row(
              children: [
                for (var i = 0; i < stats.length; i++)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                              color: i < stats.length - 1
                                  ? kRule
                                  : Colors.transparent),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(stats[i][0],
                              style: ts(17, w: FontWeight.w500, serif: true)),
                          Text(stats[i][1], style: ts(11, color: kMuted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('মাসের অগ্রগতি', style: ts(11, color: kMuted)),
              Text('${bn(elapsed.toString())} / ${bn(sm.length.toString())} দিন গেছে',
                  style: ts(11, color: kMuted)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: sm.length == 0 ? 0 : elapsed / sm.length,
              minHeight: 5,
              backgroundColor: const Color(0xFFE3DCCB),
              valueColor: const AlwaysStoppedAnimation<Color>(kRed),
            ),
          ),
          if (inPeriod) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: isFri ? null : () => _todayPresent(today),
                icon: Icon(
                    isFri
                        ? Icons.weekend_outlined
                        : (done ? Icons.check : Icons.touch_app_outlined),
                    size: 18),
                label: Text(
                  isFri
                      ? 'আজ সাপ্তাহিক ছুটি (শুক্রবার)'
                      : (done
                          ? 'আজ উপস্থিত দেওয়া হয়েছে'
                          : 'আজ উপস্থিত (${dShort(today)})'),
                  style: ts(14, color: Colors.white, w: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: done ? kGreen : kRed,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: kRule,
                  disabledForegroundColor: kMuted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _navBar() {
    Widget item(int i, String label, IconData icon) {
      final sel = _tab == i;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _tab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 40,
            decoration: BoxDecoration(
              color: sel ? kRed : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18, color: sel ? Colors.white : const Color(0xFFCFC8B8)),
                const SizedBox(width: 6),
                Text(label,
                    style: ts(13,
                        color: sel ? Colors.white : const Color(0xFFCFC8B8))),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: kInk,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          item(0, 'সেটআপ', Icons.settings_outlined),
          item(1, 'হাজিরা', Icons.calendar_month_outlined),
          item(2, 'হিসাব', Icons.receipt_long_outlined),
        ],
      ),
    );
  }

  Widget _setupBanner() {
    return GestureDetector(
      onTap: () => setState(() => _tab = 0),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3DAD7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('আগে "সেটআপ" ট্যাবে বেতনের তথ্য বসান, তাহলে হিসাব ঠিক আসবে।',
            style: ts(13, color: kRed)),
      ),
    );
  }

  // ───────────── হাজিরা ট্যাব ─────────────
  Widget _attendanceTab(int length, DateTime today) {
    final rows = <Widget>[];
    for (var i = 0; i < length; i++) {
      final d = DateTime(_start.year, _start.month, _start.day + i);
      rows.add(_dayRow(d, d == today));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_hasSettings) _setupBanner(),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text('দৈনিক হাজিরা',
              style: ts(16, w: FontWeight.w500, serif: true)),
        ),
        Text('P উপস্থিত · A অনুপস্থিত · L ছুটি · WL সাপ্তাহিক ছুটি। সারিতে ট্যাপ করলে ওটি ও পাঞ্চ টাইম বসাতে পারবেন।',
            style: ts(11, color: kMuted, h: 1.4)),
        const SizedBox(height: 6),
        ...rows,
      ],
    );
  }

  Widget _dayRow(DateTime d, bool isToday) {
    final fri = d.weekday == DateTime.friday;
    final en = _e[dateKey(d)] ?? DayEntry();
    final label = fri ? 'WL' : (en.st.isEmpty ? '—' : en.st);
    final color = fri ? kGrey : statusColor(en.st);
    final hasTime = en.inT.isNotEmpty || en.outT.isNotEmpty;
    return InkWell(
      onTap: () => _openSheet(d),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: isToday ? kToday : null,
          border: const Border(bottom: BorderSide(color: kRule, width: 0.6)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dShort(d), style: ts(14, w: FontWeight.w500, serif: true)),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: kWd[d.weekday - 1]),
                    if (isToday)
                      TextSpan(
                          text: ' · আজ',
                          style: ts(11, color: kRed, w: FontWeight.w500)),
                  ]), style: ts(11, color: kMuted)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: fri ? null : () => _cycle(d),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: color, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(label,
                          style: ts(12, color: color, w: FontWeight.w500)),
                    ),
                  ),
                  if (hasTime)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                          '${en.inT.isEmpty ? '—' : bn(en.inT)} – ${en.outT.isEmpty ? '—' : bn(en.outT)}',
                          style: ts(11, color: kMuted)),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(en.ot > 0 ? 'ওটি ${numText(en.ot)}' : '—',
                  textAlign: TextAlign.center,
                  style: ts(12, color: en.ot > 0 ? kInk : kGrey)),
            ),
            GestureDetector(
              onTap: () => _toggleNight(d),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: en.night ? kInk : Colors.transparent,
                  border: Border.all(color: kRule, width: 0.8),
                ),
                child: Icon(Icons.dark_mode,
                    size: 16, color: en.night ? kPaper : kGrey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────── হিসাব ট্যাব ─────────────
  Widget _ledgerTab(Summary sm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_hasSettings) _setupBanner(),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text('বেতনের হিসাব',
              style: ts(16, w: FontWeight.w500, serif: true)),
        ),
        if (_s.name.isNotEmpty) ledger('কর্মচারী', Text(_s.name, style: ts(14))),
        ledger('উপস্থিত দিন', Text(bn(sm.present.toString()), style: ts(14))),
        ledger('অনুপস্থিত / ছুটি',
            Text('${bn(sm.absent.toString())} / ${bn(sm.leave.toString())}',
                style: ts(14))),
        ledger('মোট ওটি ঘন্টা', Text(numText(sm.otHours), style: ts(14))),
        ledger('নাইট দিন', Text(bn(sm.nights.toString()), style: ts(14))),
        ledger('স্ট্যান্ডার্ড দিন (শুক্র বাদে)',
            Text(bn(sm.standard.round().toString()), style: ts(14))),
        ledger('দৈনিক হার', Text('৳ ${money(sm.daily)}', style: ts(14))),
        const SizedBox(height: 8),
        ledger('বেসিক + হাউজরেন্ট + মেডিকেল (সমন্বিত)',
            Text('৳ ${money(sm.combined)}', style: ts(14))),
        ledger('ওটি পেমেন্ট', Text('৳ ${money(sm.otPay)}', style: ts(14))),
        ledger('ট্রান্সপোর্ট', Text('৳ ${money(sm.transportPay)}', style: ts(14))),
        ledger('নাইট বিল', Text('৳ ${money(sm.nightPay)}', style: ts(14))),
        ledger('মোট আয় (গ্রস)',
            Text('৳ ${money(sm.gross)}', style: ts(14, w: FontWeight.w500))),
        ledger('প্রভিডেন্ট ফান্ড (−)',
            Text('− ৳ ${money(sm.pf)}', style: ts(14))),
        const SizedBox(height: 6),
        Container(height: 1.5, color: kInk),
        const SizedBox(height: 2),
        Container(height: 1, color: kInk),
        ledger(
          'সর্বমোট বেতন (নিট)',
          Text('৳ ${money(sm.net)}',
              style: ts(20, w: FontWeight.w500, serif: true, color: kRed)),
          bold: true,
        ),
        const SizedBox(height: 10),
        Text(
            'সূত্র: সমন্বিত = ফিক্সড বেতন + (উপস্থিত দিন − স্ট্যান্ডার্ড দিন) × দৈনিক হার। শুক্রবারে বেতন যোগ-বিয়োগ হয় না।',
            style: ts(11, color: kMuted, h: 1.5)),
      ],
    );
  }
}

// ───────────────────────── ডটেড লাইন ও খাতার সারি ─────────────────────────
class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFB9B09B)
      ..strokeWidth = 1;
    final y = size.height - 8;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + 1.5, y), p);
      x += 4;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// খাতার সারি: বামে লেখা, ডানে মান, মাঝে ডটেড লাইন (লেখার পেছনে কাগজের রঙ দিয়ে ঢাকা)
Widget ledger(String label, Widget value, {bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _DotPainter())),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Container(
                color: kPaper,
                padding: const EdgeInsets.only(right: 6),
                child: Text(label,
                    style: ts(14, w: bold ? FontWeight.w500 : null)),
              ),
            ),
            Container(
              color: kPaper,
              padding: const EdgeInsets.only(left: 6),
              child: value,
            ),
          ],
        ),
      ],
    ),
  );
}

// ───────────────────────── সেটআপ ট্যাব ─────────────────────────
class SetupTab extends StatefulWidget {
  final PaySettings settings;
  final ValueChanged<PaySettings> onChanged;
  final VoidCallback onDone;

  const SetupTab({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onDone,
  });

  @override
  State<SetupTab> createState() => _SetupTabState();
}

class _SetupTabState extends State<SetupTab> {
  late final TextEditingController _name;
  late final TextEditingController _basic;
  late final TextEditingController _house;
  late final TextEditingController _med;
  late final TextEditingController _ot;
  late final TextEditingController _tr;
  late final TextEditingController _night;
  late final TextEditingController _pf;

  String _fmt(double v) {
    if (v == 0) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _name = TextEditingController(text: s.name);
    _basic = TextEditingController(text: _fmt(s.basic));
    _house = TextEditingController(text: _fmt(s.house));
    _med = TextEditingController(text: _fmt(s.med));
    _ot = TextEditingController(text: _fmt(s.otRate));
    _tr = TextEditingController(text: _fmt(s.transport));
    _night = TextEditingController(text: _fmt(s.nightBill));
    _pf = TextEditingController(text: _fmt(s.pf));
  }

  @override
  void dispose() {
    _name.dispose();
    _basic.dispose();
    _house.dispose();
    _med.dispose();
    _ot.dispose();
    _tr.dispose();
    _night.dispose();
    _pf.dispose();
    super.dispose();
  }

  double _n(TextEditingController c) {
    final t = toEn(c.text.trim());
    if (t.isEmpty) return 0;
    return double.tryParse(t) ?? 0;
  }

  void _changed() {
    final s = widget.settings;
    s.name = _name.text.trim();
    s.basic = _n(_basic);
    s.house = _n(_house);
    s.med = _n(_med);
    s.otRate = _n(_ot);
    s.transport = _n(_tr);
    s.nightBill = _n(_night);
    s.pf = _n(_pf);
    widget.onChanged(s);
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: kCard,
      hintText: hint,
      hintStyle: ts(14, color: kGrey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kRule, width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kRule, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kRed, width: 1.2),
      ),
    );
  }

  Widget _field(String label, TextEditingController c) {
    return ledger(
      label,
      SizedBox(
        width: 108,
        child: TextField(
          controller: c,
          textAlign: TextAlign.right,
          style: ts(14),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯.]')),
          ],
          decoration: _dec('০'),
          onChanged: (_) => _changed(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text('বেতনের তথ্য',
              style: ts(16, w: FontWeight.w500, serif: true)),
        ),
        Text('একবার বসান, ফোনেই সেভ থাকবে। যে কেউ নিজের হিসাব দিয়ে ব্যবহার করতে পারবে।',
            style: ts(12, color: kMuted, h: 1.4)),
        const SizedBox(height: 6),
        ledger(
          'নাম',
          SizedBox(
            width: 150,
            child: TextField(
              controller: _name,
              textAlign: TextAlign.right,
              style: ts(14),
              decoration: _dec('আপনার নাম'),
              onChanged: (_) => _changed(),
            ),
          ),
        ),
        _field('মূল বেতন (বেসিক)', _basic),
        _field('হাউজ রেন্ট', _house),
        _field('মেডিকেল আলাউয়েন্স', _med),
        ledger('মোট ফিক্সড বেতন (অটো)',
            Text('৳ ${money(s.fixed)}', style: ts(14, w: FontWeight.w500)),
            bold: true),
        _field('ওটি রেট / ঘন্টা', _ot),
        _field('ট্রান্সপোর্ট / দিন', _tr),
        _field('নাইট বিল / দিন', _night),
        _field('প্রভিডেন্ট ফান্ড / মাস', _pf),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              widget.onDone();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('সেভ করে হাজিরায় যান',
                style: ts(14, color: Colors.white, w: FontWeight.w500)),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── দিনের বিস্তারিত (বটম শীট) ─────────────────────────
class DaySheet extends StatefulWidget {
  final DateTime date;
  final DayEntry entry;

  const DaySheet({super.key, required this.date, required this.entry});

  @override
  State<DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<DaySheet> {
  late DayEntry e;

  @override
  void initState() {
    super.initState();
    e = widget.entry;
  }

  bool get _fri => widget.date.weekday == DateTime.friday;

  Future<void> _pick(bool isIn) async {
    final cur = parseTime(isIn ? e.inT : e.outT) ?? TimeOfDay.now();
    final t = await showTimePicker(context: context, initialTime: cur);
    if (t == null || !mounted) return;
    setState(() {
      if (isIn) {
        e.inT = fmtTime(t);
      } else {
        e.outT = fmtTime(t);
      }
    });
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(t, style: ts(12, color: kMuted, w: FontWeight.w500)),
      );

  Widget _roundBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: kRule),
          color: kCard,
        ),
        child: Icon(icon, size: 20, color: kInk),
      ),
    );
  }

  Widget _timeRow(String name, String value, bool isIn) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pick(isIn),
            style: OutlinedButton.styleFrom(
              foregroundColor: kInk,
              side: const BorderSide(color: kRule),
              backgroundColor: kCard,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              value.isEmpty ? '$name সময় বসান' : '$name   ${bn(value)}',
              style: ts(14, color: value.isEmpty ? kMuted : kInk),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: value.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18, color: kMuted),
                  onPressed: () => setState(() {
                    if (isIn) {
                      e.inT = '';
                    } else {
                      e.outT = '';
                    }
                  }),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.date;
    const choices = [
      ['P', 'উপস্থিত'],
      ['A', 'অনুপস্থিত'],
      ['L', 'ছুটি'],
      ['', 'খালি'],
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kRule,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('${dShort(d)}, ${kWd[d.weekday - 1]}বার',
                  style: ts(20, w: FontWeight.w500, serif: true)),
              _label('উপস্থিতি'),
              if (_fri)
                Text('শুক্রবার: সাপ্তাহিক ছুটি (WL)। বেতনে যোগ-বিয়োগ হয় না।',
                    style: ts(13, color: kMuted))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in choices)
                      GestureDetector(
                        onTap: () => setState(() => e.st = c[0]),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: e.st == c[0]
                                ? statusColor(c[0])
                                : Colors.transparent,
                            border: Border.all(
                                color: statusColor(c[0]), width: 1.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c[0].isEmpty ? c[1] : '${c[0]}  ${c[1]}',
                            style: ts(13,
                                color: e.st == c[0]
                                    ? Colors.white
                                    : statusColor(c[0]),
                                w: FontWeight.w500),
                          ),
                        ),
                      ),
                  ],
                ),
              _label('ওভারটাইম (ঘন্টা)'),
              Row(
                children: [
                  _roundBtn(Icons.remove, () {
                    setState(() {
                      final v = e.ot - 0.5;
                      e.ot = v < 0 ? 0.0 : v;
                    });
                  }),
                  SizedBox(
                    width: 90,
                    child: Text(numText(e.ot),
                        textAlign: TextAlign.center,
                        style: ts(22, w: FontWeight.w500, serif: true)),
                  ),
                  _roundBtn(Icons.add, () {
                    setState(() {
                      final v = e.ot + 0.5;
                      e.ot = v > 24 ? 24.0 : v;
                    });
                  }),
                ],
              ),
              _label('নাইট'),
              Row(
                children: [
                  Expanded(
                      child: Text('এই দিন নাইট করেছি', style: ts(14))),
                  Switch(
                    value: e.night,
                    activeColor: kRed,
                    onChanged: (v) => setState(() => e.night = v),
                  ),
                ],
              ),
              _label('পাঞ্চ টাইম (শুধু রেকর্ডের জন্য)'),
              _timeRow('IN', e.inT, true),
              const SizedBox(height: 6),
              _timeRow('OUT', e.outT, false),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(e),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('সেভ করুন',
                      style: ts(14, color: Colors.white, w: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
