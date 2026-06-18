import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'profil_kurulum_sayfasi.dart';

/// Uygulamanın ilk kurulumunda kullanıcıyı karşılayan ve temel özellikleri anlatan ekran.
class OnboardingSayfasi extends StatefulWidget {
  const OnboardingSayfasi({super.key});

  @override
  State<OnboardingSayfasi> createState() => _OnboardingSayfasiState();
}

class _OnboardingSayfasiState extends State<OnboardingSayfasi> {
  // --- KONTROLCÜLER VE DEĞİŞKENLER ---
  final PageController _pageController = PageController();
  final DBHelper _dbHelper = DBHelper();
  int _currentPage = 0;

  /// Tanıtım sayfalarında gösterilecek veri seti (Başlık, Açıklama, İkon).
  final List<Map<String, String>> _onboardingData = [
    {
      "title": "FocusFlow'a Hoş Geldin 🚀",
      "desc": "Akademik hayatını düzene sokmak ve odaklanma süreni zirveye taşımak için doğru yerdesin.",
      "icon": "🎯"
    },
    {
      "title": "Gelişmiş Pomodoro Tekniği ⏱️",
      "desc": "Derslerine özel odaklanma ve mola süreleri belirle. Oturum sonlarında veritabanına özel başarı notları bırak.",
      "icon": "⚡"
    },
    {
      "title": "Detaylı Akademik Analizler 📊",
      "desc": "Haftalık gelişim trend çizgini ve kategorize edilmiş ders dağılım grafiklerini el yapımı arayüzlerle anlık takip et.",
      "icon": "📈"
    }
  ];

  // --- İŞ MANTIĞI (BUSINESS LOGIC) METOTLARI ---

  /// Tanıtım sürecinin tamamlandığını veritabanına kaydeder ve profil kurulumuna yönlendirir.
  void _completeAndNavigate() async {
    await _dbHelper.completeOnboarding();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfilKurulumSayfasi()),
      );
    }
  }
  /// Sağ üst köşedeki "Geç" butonunu oluşturur.
  Widget _buildSkipButton() {
    return Align(
      alignment: Alignment.topRight,
      child: TextButton(
        onPressed: _completeAndNavigate,
        child: const Text("Geç", style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 16)),
      ),
    );
  }

  /// PageView içindeki her bir sayfanın  tasarımını oluşturur.
  Widget _buildPageContent(int index) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_onboardingData[index]["icon"]!, style: const TextStyle(fontSize: 90)),
        const SizedBox(height: 40),
        Text(
          _onboardingData[index]["title"]!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text(
          _onboardingData[index]["desc"]!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 15, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _onboardingData.length,
            (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          height: 10,
          width: _currentPage == index ? 24 : 10,
          decoration: BoxDecoration(
            color: _currentPage == index ? Colors.deepPurpleAccent : Colors.grey.withOpacity(0.5),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    );
  }

  /// Sayfayı ileri saran veya tanıtımı bitiren alt aksiyon butonunu oluşturur.
  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: () {
          if (_currentPage == _onboardingData.length - 1) {
            _completeAndNavigate();
          } else {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurpleAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Text(
          _currentPage == _onboardingData.length - 1 ? "Hemen Başla ⚡" : "İleri",
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [Colors.black, Colors.deepPurple.shade900]
                : [Colors.white, Colors.deepPurple.shade50],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 50),

            // 1. Ekranın Üstü: Geç Butonu
            _buildSkipButton(),

            // 2. Ekranın Ortası: Kaydırılabilir Tanıtım Sayfaları
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) => _buildPageContent(index),
              ),
            ),

            // 3. Ekranın Altı: Sayfa Göstergeleri (Noktalar)
            _buildPageIndicators(),
            const SizedBox(height: 40),

            // 4. Ekranın En Altı: İleri / Hemen Başla Butonu
            _buildActionButton(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}