import 'package:flutter/material.dart';

// Yerel (Local) Bağlantılar
import 'database/db_helper.dart';
import 'screens/ana_iskelet.dart';
import 'screens/onboarding_sayfasi.dart';
import 'screens/profil_kurulum_sayfasi.dart';

/// Global tema yönetim nesnesi (ValueNotifier ile State Management gerektirmeden dinlenir)
final ValueNotifier<ThemeMode> temaModu = ValueNotifier<ThemeMode>(ThemeMode.dark);

void main() async {
  // Flutter motorunun asenkron işlemler için hazır olduğundan emin oluyoruz.
  WidgetsFlutterBinding.ensureInitialized();

  bool onboardingDone = false;
  bool hasUser = false;

  // Hoca Dokunuşu: Veritabanı başlatılırken oluşabilecek çökmeleri önleyen güvenlik bloğu.
  try {
    final DBHelper dbHelper = DBHelper();
    onboardingDone = await dbHelper.isOnboardingCompleted();

    final Map<String, dynamic>? aktifKullanici = await dbHelper.aktifKullaniciGetir();
    hasUser = aktifKullanici != null;
  } catch (e) {
    debugPrint("HATA (Sistem Başlatma): Veritabanı başlangıç durumları çekilemedi. Detay: $e");
  }

  // Çekilen durumlara göre uygulamayı ilgili parametrelerle başlatıyoruz.
  runApp(
    FocusFlowApp(
      onboardingDone: onboardingDone,
      hasUser: hasUser,
    ),
  );
}

/// Uygulamanın ana iskeletini ve tema ayarlarını barındıran kök widget.
class FocusFlowApp extends StatelessWidget {
  final bool onboardingDone;
  final bool hasUser;

  const FocusFlowApp({
    super.key,
    required this.onboardingDone,
    required this.hasUser,
  });

  // --- İŞ MANTIĞI (ROUTING / YÖNLENDİRME) ---

  /// Uygulamanın açılışta hangi sayfaya gideceğine karar veren yönlendirme algoritması.
  Widget _baslangicSayfasiniBelirle() {
    if (!onboardingDone) {
      // Kullanıcı uygulamayı ilk kez açıyorsa tanıtım ekranına git
      return const OnboardingSayfasi();
    } else if (hasUser) {
      // Tanıtım bitmiş ve içeride aktif bir kullanıcı varsa ana dashboard'a git
      return const AnaIskelet();
    } else {
      // Tanıtım bitmiş ama kullanıcı çıkış yapmışsa profil kurulumuna git
      return const ProfilKurulumSayfasi();
    }
  }

  // --- ARAYÜZ (UI) TEMA METOTLARI ---

  /// Gündüz Modu (Light Theme) Yapılandırması
  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.deepPurple,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
    );
  }

  /// Gece Modu (Dark Theme) Yapılandırması
  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.deepPurple,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.black,
    );
  }

  // --- ANA BUILD METODU ---

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: temaModu,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'FocusFlow',
          debugShowCheckedModeBanner: false, // Sağ üstteki "DEBUG" yazısını kaldırır

          themeMode: currentMode,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),

          // Yönlendirme (Routing) Akış Kontrolü:
          // Karmaşık ternary operatörü yerine temiz bir yönlendirme metodu kullanıldı.
          home: _baslangicSayfasiniBelirle(),
        );
      },
    );
  }
}