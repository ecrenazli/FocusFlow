import 'package:flutter/material.dart';
import 'ana_sayfa.dart';
import 'istatistik_sayfasi.dart';

/// Uygulamanın ana gezinti (Navigation) iskeleti.
/// Alt menü (BottomNavigationBar) üzerinden Ana Sayfa ve Analizler arasında geçişi sağlar.
class AnaIskelet extends StatefulWidget {
  const AnaIskelet({super.key});

  @override
  State<AnaIskelet> createState() => _AnaIskeletState();
}

class _AnaIskeletState extends State<AnaIskelet> {
  // --- DURUM (STATE) DEĞİŞKENLERİ ---
  int _seciliSayfa = 0;

  /// Alt menüden erişilebilen sayfaların listesi.
  final List<Widget> _sayfalar = [
    const AnaSayfa(),
    const IstatistikSayfasi(),
  ];

  /// Alt menüde bir sekmeye tıklandığında sayfayı günceller.
  void _sayfaDegistir(int index) {
    setState(() {
      _seciliSayfa = index;
    });
  }

  /// Gölge efektli ve temaya uyumlu özel alt gezinti çubuğunu çizer.
  Widget _buildBottomNavigationBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -3)
          )
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _seciliSayfa,
        onTap: _sayfaDegistir,
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        selectedItemColor: Colors.deepPurpleAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded, size: 26),
              label: 'Ana Sayfa'
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.analytics_rounded, size: 26),
              label: 'Analizler'
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Seçilen indekse göre sayfayı ekrana basar
      body: _sayfalar[_seciliSayfa],

      // Arayüz kodundan ayrıştırılmış alt menüyü çağırır
      bottomNavigationBar: _buildBottomNavigationBar(isDark),
    );
  }
}