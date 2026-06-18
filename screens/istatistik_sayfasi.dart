import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database/db_helper.dart';
import '../models/calisma_kaydi.dart';

/// Kullanıcının çalışma verilerini, haftalık trendleri ve hedef uyum
/// oranlarını analiz eden, takvim entegrasyonlu dashboard ekranı.
class IstatistikSayfasi extends StatefulWidget {
  const IstatistikSayfasi({super.key});

  @override
  State<IstatistikSayfasi> createState() => _IstatistikSayfasiState();
}

class _IstatistikSayfasiState extends State<IstatistikSayfasi> {

  final DBHelper _dbHelper = DBHelper();
  final TextEditingController _gorevController = TextEditingController();
  final TextEditingController _hedefController = TextEditingController();

  // --- DURUM (STATE) DEĞİŞKENLERİ ---
  String _kullaniciAdi = "Yükleniyor...";
  int _tavsiyeDakika = 60;
  String _seciliKategori = "Kodlama";
  final List<String> _kategoriler = [
    "Kodlama", "Siber Güvenlik", "Matematik",
    "Teorik Ezber", "Proje Geliştirme", "Genel"
  ];

  // Takvim Durumu
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Analiz Verileri
  Map<String, int> _completedMinutesMap = {};
  Map<String, int> _targetedMinutesMap = {};
  List<int> _weeklyTrendData = [];
  List<String> _weeklyDaysLabels = [];

  bool _isLoading = true;
  int _totalCompletedFocus = 0;
  double _overallComplianceRate = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStatisticsAndCompliance();
  }

  /// Veritabanındaki tüm çalışma kayıtlarını çekerek haftalık trend,
  /// ders bazlı uyum oranı ve genel başarı yüzdesini hesaplar.
  void _loadStatisticsAndCompliance() async {
    try {
      var kullanici = await _dbHelper.aktifKullaniciGetir();
      if (kullanici == null) return;

      _kullaniciAdi = kullanici['ad'];
      _tavsiyeDakika = kullanici['tavsiye_saat'] as int; // Clean Code: 60'a bölme kaldırıldı (Hata düzeltmesi uygulandı)

      List<CalismaKaydi> records = await _dbHelper.calismalariGetir(_kullaniciAdi);

      Map<String, int> localCompleted = {};
      Map<String, int> localTargeted = {};
      int totalCompMin = 0;
      int totalTargetMin = 0;

      // Kayıtları tarayıp toplam süreleri ve hedefleri kategorize et
      for (var r in records) {
        String dersAdi = r.gorevAdi.trim().isEmpty ? "Genel" : r.gorevAdi.trim();
        int compMin = r.sureSaniye ~/ 60;
        int targetMin = r.hedefSaniye ~/ 60;

        localCompleted[dersAdi] = (localCompleted[dersAdi] ?? 0) + compMin;
        localTargeted[dersAdi] = (localTargeted[dersAdi] ?? 0) + targetMin;

        totalCompMin += compMin;
        totalTargetMin += targetMin;
      }

      // Genel Uyum Oranını Hesapla
      double globalCompliance = totalTargetMin > 0 ? (totalCompMin / totalTargetMin) * 100 : 0.0;

      // Son 7 günün haftalık trend analizini oluştur
      List<int> trendList = [];
      List<String> dayLabels = [];
      List<String> dayNamesTr = ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"];

      for (int i = 6; i >= 0; i--) {
        DateTime targetDate = DateTime.now().subtract(Duration(days: i));
        String targetDateString = targetDate.toString().substring(0, 10);

        int dailyTotalMinutes = 0;
        for (var r in records) {
          if (r.tarih == targetDateString) {
            dailyTotalMinutes += (r.sureSaniye ~/ 60);
          }
        }
        trendList.add(dailyTotalMinutes);
        dayLabels.add(dayNamesTr[targetDate.weekday % 7]);
      }

      if (mounted) {
        setState(() {
          _completedMinutesMap = localCompleted;
          _targetedMinutesMap = localTargeted;
          _weeklyTrendData = trendList;
          _weeklyDaysLabels = dayLabels;
          _totalCompletedFocus = totalCompMin;
          _overallComplianceRate = globalCompliance > 100.0 ? 100.0 : globalCompliance;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("HATA (İstatistik Yükleme): Veriler analiz edilemedi. Detay: $e");
    }
  }

  /// Takvimden seçilen gün için veritabanına yeni bir hedef çalışma kaydı ekler.
  Future<void> _yeniHedefKaydet(String formatliTarih) async {
    String gAd = _gorevController.text.trim();
    if (gAd.isEmpty || _kullaniciAdi == "Yükleniyor...") return;

    try {
      int hedefSaniye = int.parse(_hedefController.text.trim()) * 60;
      await _dbHelper.calismaEkle(CalismaKaydi(
          gorevAdi: gAd,
          sureSaniye: 0,
          kalanSaniye: 1500,
          hedefSaniye: hedefSaniye,
          tarih: formatliTarih,
          kategori: _seciliKategori,
          notlar: "",
          kullaniciAdi: _kullaniciAdi
      ));

      _gorevController.clear();
      if (mounted) Navigator.pop(context);

      // Eklenen verinin grafiklere anında yansıması için listeyi güncelle
      _loadStatisticsAndCompliance();
    } catch (e) {
      debugPrint("HATA (Takvim Hedef Ekleme): Kayıt başarısız. Detay: $e");
    }
  }

  /// Takvimden seçilen güne özel hedef/plan oluşturma penceresi.
  void _gorevEklePenceresiGoster(DateTime secilenTarih) {
    _hedefController.text = _tavsiyeDakika.toString();
    String formatliTarih = secilenTarih.toString().substring(0, 10);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text('🎯 $formatliTarih İçin Plan'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: _gorevController, decoration: const InputDecoration(labelText: 'Ders / Görev Adı')),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: _seciliKategori,
                        decoration: const InputDecoration(labelText: "Ders Kategorisi", border: OutlineInputBorder()),
                        items: _kategoriler.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                        onChanged: (v) => setState(() => _seciliKategori = v!),
                      ),
                      const SizedBox(height: 15),
                      TextField(controller: _hedefController, decoration: const InputDecoration(labelText: 'Günlük Hedef (Dakika)'), keyboardType: TextInputType.number),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
                  ElevatedButton(
                    onPressed: () => _yeniHedefKaydet(formatliTarih),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                    child: const Text('Planla', style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  @override
  void dispose() {
    _gorevController.dispose();
    _hedefController.dispose();
    super.dispose();
  }

  /// Etkileşimli TableCalendar modülünü oluşturur.
  Widget _buildTakvimModulu(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          // Gün seçildiğinde plan ekleme penceresini aç
          _gorevEklePenceresiGoster(selectedDay);
        },
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() => _calendarFormat = format);
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        calendarStyle: CalendarStyle(
          todayDecoration: const BoxDecoration(color: Colors.deepPurpleAccent, shape: BoxShape.circle),
          selectedDecoration: const BoxDecoration(color: Colors.tealAccent, shape: BoxShape.circle),
          selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          defaultTextStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
          weekendTextStyle: const TextStyle(color: Colors.redAccent),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonDecoration: BoxDecoration(
            color: Colors.deepPurpleAccent,
            borderRadius: BorderRadius.circular(20.0),
          ),
          formatButtonTextStyle: const TextStyle(color: Colors.white),
          titleTextStyle: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Genel çalışma uyum oranını gösteren animasyonlu grafik kartı.
  Widget _buildUyumKarti(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: isDark ? [Colors.deepPurple.shade900, Colors.black87] : [Colors.deepPurpleAccent, Colors.purpleAccent]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))]
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 70,
                width: 70,
                child: CircularProgressIndicator(
                  value: _overallComplianceRate / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                ),
              ),
              Text(
                "%${_overallComplianceRate.toStringAsFixed(0)}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              )
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Genel Plana Uyum Oranı", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  "Toplam Planlanan Hedefin %${_overallComplianceRate.toStringAsFixed(0)} kadarı başarıyla tamamlandı.",
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  /// CustomPainter kullanılarak çizilen haftalık gelişim trend grafiği.
  Widget _buildTrendGrafigi(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Haftalık Trend Analizi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text("Toplam Odaklanma: $_totalCompletedFocus Dakika", style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 10),
        Container(
          height: 110,
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CustomPaint(
            painter: TrendLinePainter(data: _weeklyTrendData, labels: _weeklyDaysLabels, isDark: isDark),
          ),
        ),
      ],
    );
  }

  /// Ders bazlı hedef başarı yüzdelerini liste halinde gösterir.
  Widget _buildDersListesi() {
    if (_completedMinutesMap.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text("Veri tabanında analiz edilecek ders kaydı bulunmuyor.", textAlign: TextAlign.center),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Ders Bazlı Hedef Uyum Yüzdeleri", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: _completedMinutesMap.keys.map((courseName) {
            int completed = _completedMinutesMap[courseName]!;
            int targeted = _targetedMinutesMap[courseName] ?? 1;
            if (targeted == 0) targeted = 1;

            double courseCompliance = (completed / targeted) * 100;
            double progressIndicatorValue = (completed / targeted).clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(courseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        '%${courseCompliance.toStringAsFixed(0)} Başarı ($completed/$targeted dk)',
                        style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(builder: (context, c) {
                    return LinearProgressIndicator(
                      value: progressIndicatorValue,
                      minHeight: 10,
                      backgroundColor: Colors.grey.withOpacity(0.15),
                      color: courseCompliance >= 100.0 ? Colors.greenAccent.shade700 : Colors.deepPurpleAccent,
                      borderRadius: BorderRadius.circular(5),
                    );
                  })
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Akademik Analiz Paneli'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTakvimModulu(isDark),
            const SizedBox(height: 25),

            _buildUyumKarti(isDark),
            const SizedBox(height: 25),

            _buildTrendGrafigi(isDark),
            const SizedBox(height: 25),

            _buildDersListesi(),
          ],
        ),
      ),
    );
  }
}

/// Özel verilerle haftalık trend çizgisini  çizen  sınıf.
class TrendLinePainter extends CustomPainter {
  final List<int> data;
  final List<String> labels;
  final bool isDark;

  TrendLinePainter({required this.data, required this.labels, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    int maxValue = data.fold(1, (max, e) => e > max ? e : max);
    if (maxValue == 0) maxValue = 1;

    double stepX = size.width / 6;
    List<Offset> points = [];

    for (int i = 0; i < data.length; i++) {
      double x = i * stepX;
      double y = size.height - 20 - ((data[i] / maxValue) * (size.height - 35));
      points.add(Offset(x, y));
    }

    Paint linePaint = Paint()..color = Colors.deepPurpleAccent..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var p in points) { path.lineTo(p.dx, p.dy); }
    canvas.drawPath(path, linePaint);

    Paint ptPaint = Paint()..color = Colors.tealAccent..style = PaintingStyle.fill;
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4, ptPaint);
      TextPainter(
        text: TextSpan(text: labels[i], style: TextStyle(color: isDark ? Colors.grey : Colors.black87, fontSize: 9, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout()..paint(canvas, Offset(points[i].dx - 6, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}