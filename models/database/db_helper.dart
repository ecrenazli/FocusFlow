import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/calisma_kaydi.dart';

/// Veritabanı işlemlerini Singleton mimarisi ile yöneten merkezi sınıf.
class DBHelper {
  static Database? _database;

  // --- TABLO İSİMLERİ (Magic String'leri önlemek için) ---
  static const String _tableCalisma = 'calisma_kayitlari';
  static const String _tableKullanici = 'kullanici';
  static const String _tableAyarlar = 'ayarlar';

  /// Veritabanı örneğini asenkron olarak döndürür.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  /// Veritabanını oluşturur ve başlangıç tablolarını ayağa kaldırır.
  Future<Database> _initDB() async {
    try {
      String path = join(await getDatabasesPath(), 'focusflow_v2.db');
      return await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {

          // 1. Çalışma Kayıtları Tablosu
          await db.execute('''
            CREATE TABLE $_tableCalisma (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              gorev_adi TEXT,
              sure_saniye INTEGER,
              kalanSaniye INTEGER,
              hedef_saniye INTEGER,
              tarih TEXT,
              kategori TEXT,
              notlar TEXT,
              kullanici_adi TEXT
            )
          ''');

          // 2. Kullanıcı Yönetim Tablosu
          await db.execute('''
            CREATE TABLE $_tableKullanici (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ad TEXT UNIQUE,
              bolum TEXT,
              tavsiye_saat INTEGER,
              is_active INTEGER
            )
          ''');

          // 3. Sistem Ayarları Tablosu
          await db.execute('''
            CREATE TABLE $_tableAyarlar (
              id INTEGER PRIMARY KEY,
              odak_dakika INTEGER,
              mola_dakika INTEGER,
              onboarding_completed INTEGER
            )
          ''');

          // Varsayılan sistem ayarlarının başlangıçta atanması
          await db.insert(_tableAyarlar, {
            'id': 1,
            'odak_dakika': 25,
            'mola_dakika': 5,
            'onboarding_completed': 0
          });
        },
      );
    } catch (e) {

      return await openDatabase(join(await getDatabasesPath(), 'focusflow_v2.db'));
    }
  }

  /// Kullanıcının tanıtım ekranını geçip geçmediğini kontrol eder.
  Future<bool> isOnboardingCompleted() async {
    try {
      Database db = await database;
      List<Map<String, dynamic>> result = await db.query(_tableAyarlar, where: 'id = ?', whereArgs: [1]);
      if (result.isNotEmpty) {
        return result.first['onboarding_completed'] == 1;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Tanıtım ekranının tamamlandığını sisteme kaydeder.
  Future<void> completeOnboarding() async {
    try {
      Database db = await database;
      await db.update(_tableAyarlar, {'onboarding_completed': 1}, where: 'id = ?', whereArgs: [1]);
    } catch (_) {}
  }

  // --- OTURUM VE KULLANICI YÖNETİMİ ---

  /// Yeni kullanıcı oluşturur veya mevcut kullanıcının oturumunu aktif hale getirir.
  Future<int> kullaniciGirisYap(String ad, String bolum, int tavsiyeSaat) async {
    Database db = await database;

    // Sistemdeki tüm açık oturumları kapat
    await db.update(_tableKullanici, {'is_active': 0});

    // Kullanıcının sistemde var olup olmadığını kontrol et
    List<Map<String, dynamic>> mevcutKullanici = await db.query(_tableKullanici, where: 'ad = ?', whereArgs: [ad]);

    if (mevcutKullanici.isNotEmpty) {
      // Mevcut kullanıcının oturumunu aç
      return await db.update(_tableKullanici, {'is_active': 1}, where: 'ad = ?', whereArgs: [ad]);
    } else {
      // Yeni kullanıcıyı sisteme kaydet ve oturumunu aç
      return await db.insert(_tableKullanici, {
        'ad': ad,
        'bolum': bolum,
        'tavsiye_saat': tavsiyeSaat,
        'is_active': 1
      });
    }
  }

  /// Aktif kullanıcının oturumunu sonlandırır.
  Future<int> kullaniciCikisYap() async {
    Database db = await database;
    return await db.update(_tableKullanici, {'is_active': 0}, where: 'is_active = ?', whereArgs: [1]);
  }

  /// Sistemde şu an aktif olan kullanıcının verilerini döndürür.
  Future<Map<String, dynamic>?> aktifKullaniciGetir() async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(_tableKullanici, where: 'is_active = ?', whereArgs: [1], limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  // --- POMODORO AYARLARI ---

  /// Sistemdeki mevcut pomodoro (odaklanma/mola) ayarlarını getirir.
  Future<Map<String, dynamic>> ayarlariGetir() async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(_tableAyarlar, where: 'id = ?', whereArgs: [1]);
    if (result.isNotEmpty) return result.first;

    // Veritabanından veri alınamazsa varsayılan değerleri döndür
    return {'odak_dakika': 25, 'mola_dakika': 5};
  }

  /// Pomodoro sürelerini günceller.
  Future<int> ayariGuncelle(int odakDk, int molaDk) async {
    Database db = await database;
    return await db.update(_tableAyarlar, {'odak_dakika': odakDk, 'mola_dakika': molaDk}, where: 'id = ?', whereArgs: [1]);
  }
  /// Yeni bir çalışma/odaklanma kaydını veritabanına ekler.
  Future<int> calismaEkle(CalismaKaydi kayit) async {
    Database db = await database;
    return await db.insert(_tableCalisma, kayit.toMap());
  }

  /// Belirtilen kullanıcıya ait tüm çalışma kayıtlarını getirir.
  Future<List<CalismaKaydi>> calismalariGetir(String kullaniciAdi) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(_tableCalisma, where: 'kullanici_adi = ?', whereArgs: [kullaniciAdi]);
    return List.generate(result.length, (i) => CalismaKaydi.fromMap(result[i]));
  }

  /// Seçilen bir çalışma kaydını veritabanından kalıcı olarak siler.
  Future<int> calismaSil(int id) async {
    Database db = await database;
    return await db.delete(_tableCalisma, where: 'id = ?', whereArgs: [id]);
  }

  /// Mevcut bir çalışma kaydının verilerini (kalan süre, notlar vb.) günceller.
  Future<int> calismaGuncelle(CalismaKaydi kayit) async {
    Database db = await database;
    return await db.update(_tableCalisma, kayit.toMap(), where: 'id = ?', whereArgs: [kayit.id]);
  }
}