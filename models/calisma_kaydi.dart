/// Veritabanı (SQLite) ve arayüz arasında veri taşımasını sağlayan Model (DTO) sınıfı.
/// Her bir çalışma/odaklanma oturumunun tüm detaylarını kapsar.
class CalismaKaydi {
  // --- SINIF DEĞİŞKENLERİ (ÖZELLİKLER) ---

  /// Benzersiz kayıt kimliği (Veritabanında otomatik oluşturulur).
  final int? id;

  /// Üzerinde çalışılan dersin veya görevin adı.
  final String gorevAdi;

  /// Bugüne kadar bu göreve harcanan toplam başarılı saniye.
  final int sureSaniye;

  /// Pomodoro sayacında o an kalan saniye (Oturumun nerede kaldığını tutar).
  final int kalanSaniye;

  /// Kullanıcının bu görev için belirlediği günlük hedef süre (Saniye cinsinden).
  final int hedefSaniye;

  /// Kaydın oluşturulduğu veya oturumun yapıldığı tarih (YYYY-MM-DD formatında).
  final String tarih;

  /// Görevin ait olduğu akademik kategori (Örn: Kodlama, Matematik).
  final String kategori;

  /// Oturum sonunda kullanıcının girdiği kişisel gelişim notları.
  final String notlar;

  /// Bu kaydın hangi kullanıcı profiline ait olduğunu belirten referans anahtarı.
  final String kullaniciAdi;

  // --- YAPICI METOT (CONSTRUCTOR) ---

  CalismaKaydi({
    this.id,
    required this.gorevAdi,
    required this.sureSaniye,
    required this.kalanSaniye,
    required this.hedefSaniye,
    required this.tarih,
    this.kategori = "Genel",
    this.notlar = "",
    required this.kullaniciAdi,
  });

  // --- SERİLEŞTİRME (SERIALIZATION) METOTLARI ---

  /// Dart nesnesini, SQLite veritabanına yazılabilmesi için Map (Sözlük) yapısına çevirir.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gorev_adi': gorevAdi,
      'sure_saniye': sureSaniye,
      'kalanSaniye': kalanSaniye, // Not: DB şemasında bu şekilde tanımlandığı için camelCase bırakıldı
      'hedef_saniye': hedefSaniye,
      'tarih': tarih,
      'kategori': kategori,
      'notlar': notlar,
      'kullanici_adi': kullaniciAdi,
    };
  }

  /// Veritabanından gelen Map (Sözlük) verisini, Flutter'da kullanılabilir Dart nesnesine çevirir.
  /// Null-Safety korumaları eklenmiştir.
  factory CalismaKaydi.fromMap(Map<String, dynamic> map) {
    return CalismaKaydi(
      id: map['id'],
      gorevAdi: map['gorev_adi'] ?? "",
      sureSaniye: map['sure_saniye'] ?? 0,
      kalanSaniye: map['kalanSaniye'] ?? 1500,
      hedefSaniye: map['hedef_saniye'] ?? 7200,
      tarih: map['tarih'] ?? "",
      kategori: map['kategori'] ?? "Genel",
      notlar: map['notlar'] ?? "",
      kullaniciAdi: map['kullanici_adi'] ?? "Bilinmeyen",
    );
  }
}