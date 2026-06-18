import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'ana_iskelet.dart';

/// Kullanıcının sisteme ilk giriş yaptığı ve profilini oluşturduğu ana ekran.
class ProfilKurulumSayfasi extends StatefulWidget {
  const ProfilKurulumSayfasi({super.key});

  @override
  State<ProfilKurulumSayfasi> createState() => _ProfilKurulumSayfasiState();
}

class _ProfilKurulumSayfasiState extends State<ProfilKurulumSayfasi> {

  final TextEditingController _adController = TextEditingController();
  final DBHelper _dbHelper = DBHelper();

  String _seciliBolum = "Bilgisayar Mühendisliği";

  final List<String> _bolumler = [
    "Bilgisayar Mühendisliği",
    "Yazılım Mühendisliği",
    "Elektrik-Elektronik Mühendisliği",
    "Diğer Mühendislikler",
    "Tıp",
    "Diş Hekimliği",
    "Hukuk",
    "Diğer Bölümler"
  ];


  /// Seçilen bölüme göre veritabanına kaydedilecek dakika cinsinden hedefi hesaplar.
  int _tavsiyeSaatHesapla(String bolum) {
    switch (bolum) {
      case 'Tıp':
      case 'Diş Hekimliği':
      case 'Hukuk':
        return 240; // 4 Saat
      case 'Bilgisayar Mühendisliği':
      case 'Yazılım Mühendisliği':
      case 'Elektrik-Elektronik Mühendisliği':
        return 180; // 3 Saat
      case 'Diğer Mühendislikler':
        return 150; // 2.5 Saat
      case 'Diğer Bölümler':
      default:
        return 120; // Varsayılan 2 Saat
    }
  }

  String _tavsiyeSaatFormatla(String bolum) {
    if (bolum == 'Tıp' || bolum == 'Diş Hekimliği' || bolum == 'Hukuk') return '4';
    if (bolum == 'Diğer Mühendislikler') return '2.5';
    if (bolum == 'Diğer Bölümler') return '2';
    return '3';
  }

  /// Seçilen bölüme özel motivasyon ve strateji metnini döndürür.
  String _tavsiyeMetniHesapla(String bolum) {
    switch (bolum) {
      case 'Tıp':
      case 'Diş Hekimliği':
      case 'Hukuk':
        return "Yoğun ezber ve ağır teorik okuma gerektiren bir bölümdesin. Başarı için günlük odaklanma sürelerini yüksek tutmalısın! 📚";
      case 'Bilgisayar Mühendisliği':
      case 'Yazılım Mühendisliği':
      case 'Elektrik-Elektronik Mühendisliği':
        return "Yoğun proje, laboratuvar ve kodlama süreçleri seni bekliyor. Pomodoro seansları ile zihnini her zaman taze tutmalısın! 💻";
      case 'Diğer Mühendislikler':
        return "Analitik problem çözme ve teknik raporlar için düzenli ve planlı çalışmak harika bir temel oluşturur. ⚙️";
      case 'Diğer Bölümler':
      default:
        return "Düzenli, istikrarlı ve dengeli bir çalışma takvimi ile tüm akademik hedeflerine rahatça ulaşabilirsin. 🎯";
    }
  }

  /// Kullanıcı sisteme güvenli giriş yaptığında tetiklenir.
  Future<void> _sistemeGirisYap() async {
    String girilenAd = _adController.text.trim();
    if (girilenAd.isEmpty) return;

    int tavsiyeSure = _tavsiyeSaatHesapla(_seciliBolum);

    // Veritabanı bütünlüğü için isim her zaman küçük harfle kaydedilir
    await _dbHelper.kullaniciGirisYap(girilenAd.toLowerCase(), _seciliBolum, tavsiyeSure);

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AnaIskelet()));
    }
  }

  @override
  void dispose() {
    _adController.dispose();
    super.dispose();
  }

  Widget _buildTavsiyeKutusu(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Önerilen Günlük Odaklanma: ${_tavsiyeSaatHesapla(_seciliBolum)} Dakika (${_tavsiyeSaatFormatla(_seciliBolum)} Saat)",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _tavsiyeMetniHesapla(_seciliBolum),
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopWaveClipper(),
              child: Container(
                height: 260,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [Colors.deepPurple.shade900, Colors.indigo.shade900]
                        : [Colors.deepPurpleAccent, Colors.purpleAccent],
                  ),
                ),
              ),
            ),
          ),

          // Ana Giriş Formu
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 50),
                  const Icon(Icons.bolt_rounded, size: 80, color: Colors.tealAccent),
                  const SizedBox(height: 15),
                  const Text(
                      'FocusFlow Portal',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      )
                  ),
                  const SizedBox(height: 100), // Dalga hatlarının altında kalması için güvenli boşluk

                  TextField(
                    controller: _adController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Adınız Soyadınız',
                      prefixIcon: const Icon(Icons.person_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  DropdownButtonFormField<String>(
                    value: _seciliBolum,
                    decoration: InputDecoration(
                      labelText: 'Okuduğun Bölüm',
                      prefixIcon: const Icon(Icons.school_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    items: _bolumler.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (v) => setState(() => _seciliBolum = v!),
                  ),
                  const SizedBox(height: 20),

                  // Dinamik Tavsiye Kutusu Çağrısı
                  _buildTavsiyeKutusu(isDark),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _sistemeGirisYap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text('Sisteme Güvenli Giriş', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 50);

    // Sol kavis başlangıcı
    Offset firstControlPoint = Offset(size.width / 4, size.height);
    Offset firstEndPoint = Offset(size.width / 2, size.height - 30);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);

    // Sağ kavis bitişi
    Offset secondControlPoint = Offset(size.width * 3 / 4, size.height - 60);
    Offset secondEndPoint = Offset(size.width, size.height - 10);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper oldClipper) => false;
}