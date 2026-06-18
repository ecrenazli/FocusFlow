import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/calisma_kaydi.dart';
import 'pomodoro_sayfasi.dart';
import 'profil_kurulum_sayfasi.dart';
import '../main.dart';

/// Kullanıcının profiline ait özet verileri gördüğü, yeni plan ekleyebildiği
/// ve aktif görevlerini listelediği ana kontrol paneli (Dashboard).
class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  // --- KONTROLCÜLER VE VERİTABANI ---
  final TextEditingController _gorevController = TextEditingController();
  final TextEditingController _hedefController = TextEditingController();
  final TextEditingController _odakAyariController = TextEditingController();
  final TextEditingController _molaAyariController = TextEditingController();
  final DBHelper _dbHelper = DBHelper();

  // --- DURUM (STATE) DEĞİŞKENLERİ ---
  List<CalismaKaydi> _calismalar = [];
  String _kullaniciAdi = "Yükleniyor...";
  int _tavsiyeDakika = 60;
  String _seciliKategori = "Kodlama";

  /// Plan eklerken kullanılabilecek varsayılan akademik kategoriler
  final List<String> _kategoriler = [
    "Kodlama", "Siber Güvenlik", "Matematik",
    "Teorik Ezber", "Proje Geliştirme", "Genel"
  ];

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }



  /// Veritabanından aktif kullanıcının bilgilerini ve çalışma planlarını güvenli bir şekilde çeker.
  void _verileriYukle() async {
    try {
      var kullanici = await _dbHelper.aktifKullaniciGetir();
      if (kullanici != null) {
        String aktifAd = kullanici['ad'];
        var liste = await _dbHelper.calismalariGetir(aktifAd);

        if (mounted) {
          setState(() {
            _calismalar = liste;
            _kullaniciAdi = aktifAd;
            _tavsiyeDakika = kullanici['tavsiye_saat'] as int;
          });
        }
      }
    } catch (e) {
      debugPrint("HATA (Veri Yükleme): Veritabanından bilgiler çekilemedi. Detay: $e");
    }
  }

  /// Aktif oturumu sonlandırarak kullanıcıyı güvenle profil kurulum ekranına yönlendirir.
  void _oturumuKapat() async {
    try {
      await _dbHelper.kullaniciCikisYap();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfilKurulumSayfasi()));
      }
    } catch (e) {
      debugPrint("HATA (Oturum Kapatma): Kullanıcı çıkış işlemi başarısız oldu. Detay: $e");
    }
  }

  /// Pomodoro ayarlarını veritabanına kaydeder. Hata anında uygulamanın çökmesini önler.
  Future<void> _ayarlariVeritabaninaKaydet() async {
    try {
      int oDk = int.parse(_odakAyariController.text);
      int mDk = int.parse(_molaAyariController.text);
      await _dbHelper.ayariGuncelle(oDk, mDk);

      if (mounted) Navigator.pop(context); // İşlem başarılıysa pencereyi kapat
    } catch (e) {
      debugPrint("HATA (Ayar Kaydetme): Ayarlar veritabanına yazılamadı. Detay: $e");
    }
  }

  /// Yeni oluşturulan hedefi veritabanına işler ve listeyi günceller.
  Future<void> _yeniHedefKaydet(DateTime secilenTarih) async {
    String gAd = _gorevController.text.trim();
    if (gAd.isEmpty || _kullaniciAdi == "Yükleniyor...") return;

    try {
      int hedefSaniye = int.parse(_hedefController.text.trim()) * 60;
      await _dbHelper.calismaEkle(CalismaKaydi(
          gorevAdi: gAd,
          sureSaniye: 0,
          kalanSaniye: 1500,
          hedefSaniye: hedefSaniye,
          tarih: secilenTarih.toString().substring(0, 10),
          kategori: _seciliKategori,
          notlar: "",
          kullaniciAdi: _kullaniciAdi
      ));

      _gorevController.clear();
      if (mounted) Navigator.pop(context);

      _verileriYukle(); // Listeyi yenile
    } catch (e) {
      debugPrint("HATA (Hedef Ekleme): Yeni çalışma kaydı oluşturulamadı. Detay: $e");
    }
  }

  // --- DİYALOG PENCERELERİ (DIALOGS) ---

  /// Kullanıcının Pomodoro sürelerini değiştirebileceği ayarlar penceresini açar.
  void _ayarlarPenceresiGoster() async {
    try {
      var ayarlar = await _dbHelper.ayarlariGetir();
      _odakAyariController.text = ayarlar['odak_dakika'].toString();
      _molaAyariController.text = ayarlar['mola_dakika'].toString();

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(children: [Icon(Icons.settings, color: Colors.deepPurpleAccent), SizedBox(width: 10), Text('Pomodoro Ayarları')]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _odakAyariController, decoration: const InputDecoration(labelText: 'Odaklanma Süresi (Dakika)'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(controller: _molaAyariController, decoration: const InputDecoration(labelText: 'Mola Süresi (Dakika)'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: _ayarlariVeritabaninaKaydet,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
              child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      );
    } catch (e) {
      debugPrint("HATA (Ayar Getirme): Veritabanından ayarlar çekilemedi. Detay: $e");
    }
  }

  /// Yeni bir akademik görev/plan eklemek için kullanılan veri giriş penceresini açar.
  void _gorevEklePenceresiGoster() {
    _hedefController.text = _tavsiyeDakika.toString();
    DateTime secilenTarih = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('🎯 Yeni Hedef Belirle'),
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
                    onPressed: () => _yeniHedefKaydet(secilenTarih),
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

  // --- ARAYÜZ (UI) WIDGET PARÇALARI ---

  /// Sayfanın en üstünde yer alan, kullanıcı adı ve toplam süreyi gösteren özet kartı.
  Widget _buildProfilKarti(int toplamSaniye, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: isDark
                ? [Colors.deepPurple.shade700, Colors.indigo.shade900]
                : [Colors.deepPurpleAccent, Colors.blueAccent]
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profil: $_kullaniciAdi 👋', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Verimli Süre: ${toplamSaniye ~/ 60} Dakika', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildGorevElemani(CalismaKaydi kayit, bool isDark) {
    return Dismissible(
      key: Key(kayit.id.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) async {
        try {
          await _dbHelper.calismaSil(kayit.id!);
          _verileriYukle();
        } catch (e) {
          debugPrint("HATA (Kayıt Silme): Görev veritabanından silinemedi. Detay: $e");
        }
      },
      background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(Icons.delete, color: Colors.white)
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: isDark ? Colors.grey.shade900 : Colors.white,
        child: ListTile(
          title: Text(kayit.gorevAdi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              '📅 Tarih: ${kayit.tarih} | ${kayit.kategori}\n'
                  '⏳ Çalışılan: ${kayit.sureSaniye ~/ 60} dk\n'
                  '📝 Not: ${kayit.notlar.isEmpty ? "Yok" : kayit.notlar}',
              style: const TextStyle(height: 1.4),
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.play_circle_fill, size: 36, color: Colors.deepPurpleAccent),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PomodoroSayfasi(kayit: kayit))
            ).then((_) => _verileriYukle()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    int toplamSaniye = _calismalar.fold(0, (sum, item) => sum + item.sureSaniye);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusFlow'),
        leading: IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.redAccent), onPressed: _oturumuKapat),
        actions: [
          IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: _ayarlarPenceresiGoster),
          IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: Colors.amberAccent),
              onPressed: () => temaModu.value = isDark ? ThemeMode.light : ThemeMode.dark
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Profil Özet Kartı
          _buildProfilKarti(toplamSaniye, isDark),

          // 2. Dinamik Görevler Listesi
          Expanded(
            child: _calismalar.isEmpty
                ? const Center(child: Text('Bu profile ait çalışma planı bulunmuyor.'))
                : ListView.builder(
              itemCount: _calismalar.length,
              itemBuilder: (context, index) => _buildGorevElemani(_calismalar[index], isDark),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _gorevEklePenceresiGoster,
          label: const Text('Plan Ekle'),
          icon: const Icon(Icons.add)
      ),
    );
  }
}