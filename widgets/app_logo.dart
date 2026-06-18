import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double boyut;

  const AppLogo({super.key, this.boyut = 80});

  /// Logonun arka planındaki dairesel degrade (gradient) ve gölge efektini oluşturur.
  BoxDecoration _buildBackgroundDecoration() {
    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        colors: [Colors.deepPurpleAccent, Colors.indigoAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.deepPurpleAccent.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _buildIconLayer() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [

          Icon(
            Icons.menu_book_rounded,
            size: boyut * 0.52,
            color: Colors.white,
          ),


          Positioned(
            top: boyut * 0.16,
            right: boyut * 0.16,
            child: Icon(
              Icons.auto_awesome,
              size: boyut * 0.24,
              color: Colors.amberAccent,
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      width: boyut,
      height: boyut,
      decoration: _buildBackgroundDecoration(),
      child: _buildIconLayer(),
    );
  }
}