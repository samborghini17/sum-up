import 'package:flutter/material.dart';

class KioSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback onSettingsTapped;

  const KioSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onSettingsTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'KREATIV\nINSTITUT.OWL',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF55FC27),
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('WORKSPACE'),
          _buildNavItem(Icons.video_library_outlined, 'Meine Videos', 0),
          _buildNavItem(Icons.upload_file_outlined, 'Video hochladen', 1),
          _buildNavItem(Icons.video_call_outlined, 'Neues Video aufnehmen', 2),
          const SizedBox(height: 24),
          _buildSectionHeader('ANALYSEN'),
          _buildNavItem(Icons.history, 'Letzte Ergebnisse', 3),
          const Spacer(),
          const Divider(color: Colors.white24),
          InkWell(
            onTap: onSettingsTapped,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, color: Colors.white70),
                  SizedBox(width: 16),
                  Text(
                    'Einstellungen & API',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index) {
    final isSelected = selectedIndex == index;
    return InkWell(
      onTap: () => onItemSelected(index),
      child: Container(
        color: isSelected ? const Color(0xFF55FC27).withOpacity(0.1) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF55FC27) : Colors.white54,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF55FC27) : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
