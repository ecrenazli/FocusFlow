import 'dart:async';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/calisma_kaydi.dart';

/// Her bir Pomodoro oturumunun anlık durumunu tutan veri modeli.
class ActiveSession {
  int kalanSaniye;
  int kazanilanSaniye;
  bool calisiyor;
  Timer? timer;
  VoidCallback? onTick;
  VoidCallback? onFinished;

  ActiveSession({
    required this.kalanSaniye,
    required this.kazanilanSaniye,
    required this.calisiyor,
  });
}

/// Singleton Design Pattern kullanılarak oluşturulmuş Merkezi Zamanlayıcı Yöneticisi.
/// Sayfalar arası geçiş yapılsa bile timer'ın arka planda çalışmaya devam etmesini sağlar.
class FocusTimerManager {
  static final FocusTimerManager _instance = FocusTimerManager._internal();
  factory FocusTimerManager() => _instance;
  FocusTimerManager._internal();

  final Map<int, ActiveSession> _sessions = {};

  /// Belirtilen ID'ye ait aktif bir oturum varsa getirir.
  ActiveSession? getSession(int id) => _sessions[id];

  /// Yeni bir oturumu belleğe kaydeder.
  void setSession(int id, ActiveSession session) {
    _sessions[id] = session;
  }

  /// Oturumu tamamen sonlandırır ve bellekten temizler.
  void removeSession(int id) {
    _sessions[id]?.timer?.cancel();
    _sessions.remove(id);
  }
}

/// Kullanıcının odaklanma sürecini başlattığı, yönettiği ve not aldığı Pomodoro ekranı.
class PomodoroSayfasi extends StatefulWidget {
  final CalismaKaydi kayit;
  const PomodoroSayfasi({super.key, required this.kayit});

  @override
  State<PomodoroSayfasi> createState() => _PomodoroSayfasiState();
}

class _PomodoroSayfasiState extends State<PomodoroSayfasi> {
  // --- KONTROLCÜLER VE VERİTABANI BAĞLANTILARI ---
  final DBHelper _dbHelper = DBHelper();
  final TextEditingController _notController = TextEditingController();

  // --- DURUM (STATE) DEĞİŞKENLERİ ---
  int _kalanSaniye = 0;
  bool _calisiyor = false;
  int _kazanilanSaniye = 0;
  int _toplamHedefSaniye = 1500; // İlerleme çemberinin oranını hesaplamak için temel alınır

  @override
  void initState() {
    super.initState();
    _loadTimerSettings();

    // Sayfa ilk yüklendiğinde, eğer oturum zaten bittiyse direkt not ekranını açar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_kalanSaniye == 0 && _kazanilanSaniye > 0) {
        _showSessionNotesDialog();
      }
    });
  }


  /// Mevcut kayda ait devam eden bir oturum olup olmadığını kontrol eder ve ayarları yükler.
  void _loadTimerSettings() {
    final int recordId = widget.kayit.id ?? -1;
    var existingSession = FocusTimerManager().getSession(recordId);

    // Toplam hedef süreyi belirle (sıfıra bölünme hatasını engellemek için korumalı)
    _toplamHedefSaniye = widget.kayit.hedefSaniye <= 0 ? 1500 : widget.kayit.hedefSaniye;

    if (existingSession != null) {
      setState(() {
        _kalanSaniye = existingSession.kalanSaniye;
        _kazanilanSaniye = existingSession.kazanilanSaniye;
        _calisiyor = existingSession.calisiyor;
      });

      existingSession.onTick = () {
        if (!mounted) return;
        setState(() {
          _kalanSaniye = existingSession.kalanSaniye;
          _kazanilanSaniye = existingSession.kazanilanSaniye;
          _calisiyor = existingSession.calisiyor;
        });
      };

      existingSession.onFinished = () {
        if (!mounted) return;
        _showSystemNotification("🎯 Pomodoro Başarıyla Bitti!", "Harika odaklandın! Şimdi günlük notunu kaydedebilirsin.");
        _showSessionNotesDialog();
      };
    } else {
      setState(() {
        _kalanSaniye = _toplamHedefSaniye;
        _kazanilanSaniye = 0;
        _calisiyor = false;
      });
    }
  }

  /// Pomodoro süresine manuel olarak 1 dakika ekler.
  void _sureEkle() {
    if (_calisiyor) return;
    setState(() {
      _kalanSaniye += 60;
      _toplamHedefSaniye += 60; // Halkanın oranını senkronize tutmak için
    });
  }

  /// Pomodoro süresinden manuel olarak 1 dakika eksiltir.
  void _sureAzalt() {
    if (_calisiyor) return;
    setState(() {
      if (_kalanSaniye > 60) {
        _kalanSaniye -= 60;
        _toplamHedefSaniye -= 60;
      } else {
        _kalanSaniye = 0;
      }
    });
  }

  /// Zamanlayıcıyı başlatır veya duraklatır.
  void _toggleTimer() {
    final int recordId = widget.kayit.id ?? -1;
    var manager = FocusTimerManager();
    var session = manager.getSession(recordId);

    if (_calisiyor) {
      // Duraklatma Durumu
      if (session != null) {
        session.timer?.cancel();
        session.calisiyor = false;
      }
      _showSystemNotification("Oturum Duraklatıldı ⏱️", "İstediğiniz an devam edebilir veya oturumu tamamen bitirebilirsiniz.");
      setState(() => _calisiyor = false);
    } else {
      // Başlatma / Devam Etme Durumu
      setState(() => _calisiyor = true);

      if (session == null) {
        session = ActiveSession(
          kalanSaniye: _kalanSaniye,
          kazanilanSaniye: _kazanilanSaniye,
          calisiyor: true,
        );
        manager.setSession(recordId, session);
      } else {
        session.calisiyor = true;
      }

      session.onTick = () {
        if (!mounted) return;
        setState(() {
          _kalanSaniye = session!.kalanSaniye;
          _kazanilanSaniye = session.kazanilanSaniye;
          _calisiyor = session.calisiyor;
        });
      };

      session.onFinished = () {
        if (!mounted) return;
        _showSystemNotification("🎯 Pomodoro Başarıyla Bitti!", "Harika odaklandın! Şimdi günlük notunu kaydedebilirsin.");
        _showSessionNotesDialog();
      };

      // Asenkron periyodik timer başlatılır
      session.timer?.cancel();
      session.timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (session!.kalanSaniye > 0) {
          session.kalanSaniye--;
          session.kazanilanSaniye++;
          if (session.onTick != null) session.onTick!();
        } else {
          session.timer?.cancel();
          session.calisiyor = false;
          if (session.onTick != null) session.onTick!();
          if (session.onFinished != null) session.onFinished!();
        }
      });
    }
  }

  /// Oturumu manuel olarak erken bitirir ve kayıt penceresini açar.
  void _finishSession() {
    _showSessionNotesDialog();
  }

  /// Sistem genelinde üstten düşen özel bildirim banner'ını gösterir.
  void _showSystemNotification(String title, String message) {
    if (!mounted) return;
    try {
      OverlayState? overlayState = Overlay.of(context);
      late OverlayEntry overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (context) => NotificationBannerWidget(
          title: title,
          message: message,
          onDismiss: () => overlayEntry.remove(),
        ),
      );

      overlayState.insert(overlayEntry);

      Timer(const Duration(seconds: 4), () {
        try { overlayEntry.remove(); } catch (_) {}
      });
    } catch (_) {}
  }

  /// Oturum sonunda kullanıcının kazanımlarını veritabanına yazdığı diyalog penceresi.
  void _showSessionNotesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [Icon(Icons.edit_note, color: Colors.deepPurpleAccent, size: 28), SizedBox(width: 10), Text('Oturum Not Defteri')],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tebrikler! Bu oturumda ${_kazanilanSaniye ~/ 60} dakika verimli çalıştın. Neler yaptığını kısaca not al:'),
            const SizedBox(height: 15),
            TextField(
                controller: _notController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(hintText: 'Örn: Konu testlerini bitirdim', border: OutlineInputBorder())
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              CalismaKaydi updatedRecord = CalismaKaydi(
                id: widget.kayit.id,
                gorevAdi: widget.kayit.gorevAdi,
                sureSaniye: widget.kayit.sureSaniye + _kazanilanSaniye,
                kalanSaniye: _kalanSaniye,
                hedefSaniye: widget.kayit.hedefSaniye,
                tarih: widget.kayit.tarih,
                kategori: widget.kayit.kategori,
                notlar: _notController.text.trim().isEmpty ? widget.kayit.notlar : _notController.text.trim(),
                kullaniciAdi: widget.kayit.kullaniciAdi,
              );

              await _dbHelper.calismaGuncelle(updatedRecord);

              final int recordId = widget.kayit.id ?? -1;
              FocusTimerManager().removeSession(recordId);

              if (mounted) {
                Navigator.pop(context); // Diyaloğu kapat
                Navigator.pop(context); // Sayfadan çık
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
            child: const Text('Günlüğü Veritabanına Kaydet', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    final int recordId = widget.kayit.id ?? -1;
    var session = FocusTimerManager().getSession(recordId);
    if (session != null) {
      session.onTick = null;
      session.onFinished = null;
    }
    _notController.dispose();
    super.dispose();
  }

  /// Dairesel geri sayım kadranını ve içindeki dakika ayar butonlarını çizer.
  Widget _buildTimerDisplay(double progressRatio, int minutes, int seconds) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 240,
          height: 240,
          child: CircularProgressIndicator(
            value: progressRatio,
            strokeWidth: 12,
            backgroundColor: Colors.grey.withOpacity(0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 32, color: Colors.redAccent),
              onPressed: _calisiyor || _kazanilanSaniye > 0 ? null : _sureAzalt,
            ),
            const SizedBox(width: 10),
            Text(
                '$minutes:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 1)
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 32, color: Colors.greenAccent),
              onPressed: _calisiyor || _kazanilanSaniye > 0 ? null : _sureEkle,
            ),
          ],
        ),
      ],
    );
  }

  /// Zamanlayıcıyı başlatan, duraklatan ve tamamen bitiren aksiyon butonlarını çizer.
  Widget _buildActionButtons() {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _calisiyor
              ? ElevatedButton.icon(
            key: const ValueKey('pauseButton'),
            onPressed: _toggleTimer,
            icon: const Icon(Icons.pause_circle_rounded, size: 28),
            label: const Text('Oturumu Duraklat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          )
              : ElevatedButton.icon(
            key: ValueKey(_kazanilanSaniye > 0 ? 'resumeButton' : 'startButton'),
            onPressed: _toggleTimer,
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: Text(_kazanilanSaniye > 0 ? 'Devam Et' : 'Odaklanmayı Başlat', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
        if (_kazanilanSaniye > 0) ...[
          const SizedBox(height: 25),
          TextButton.icon(
            onPressed: _finishSession,
            icon: const Icon(Icons.stop_rounded, color: Colors.redAccent, size: 22),
            label: const Text('Oturumu Tamamen Bitir ve Kaydet', style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ]
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    int minutes = _kalanSaniye ~/ 60;
    int seconds = _kalanSaniye % 60;

    // Çemberin doluluk oranını hesapla (0.0 ile 1.0 arası)
    double progressRatio = _toplamHedefSaniye > 0 ? _kalanSaniye / _toplamHedefSaniye : 1.0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.kayit.gorevAdi), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Modül: Dairesel Kadran
            _buildTimerDisplay(progressRatio, minutes, seconds),
            const SizedBox(height: 60),

            // 2. Modül: Kontrol Butonları
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
}

class NotificationBannerWidget extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback onDismiss;

  const NotificationBannerWidget({super.key, required this.title, required this.message, required this.onDismiss});

  @override
  State<NotificationBannerWidget> createState() => _NotificationBannerWidgetState();
}

class _NotificationBannerWidgetState extends State<NotificationBannerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _offsetAnimation = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Container(
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4))],
                border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.4), width: 1.5)
            ),
            child: Material(
              color: Colors.transparent,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.deepPurple.shade800, shape: BoxShape.circle),
                    child: const Icon(Icons.notifications_active, color: Colors.tealAccent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(widget.message, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white38, size: 18), onPressed: widget.onDismiss)
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}