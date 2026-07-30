import 'package:flutter/material.dart';
import '../services/api_config.dart';
import '../services/sound_manager.dart';

class AvatarPickerDialog extends StatelessWidget {
  final List<dynamic> avatarPool;
  final List<String> fallbackAvatarAssets;
  final int? selectedAvatarId;
  final String? profileAvatarUrl;
  final Function(int? avatarId, String? imageUrl) onAvatarSelected;

  const AvatarPickerDialog({
    super.key,
    required this.avatarPool,
    required this.fallbackAvatarAssets,
    required this.selectedAvatarId,
    required this.profileAvatarUrl,
    required this.onAvatarSelected,
  });

  /// Helper to safely resolve Network or AssetImage providers
  ImageProvider? _getAvatarProvider(String? urlOrPath) {
    if (urlOrPath == null || urlOrPath.isEmpty) return null;
    final formattedUrl = ApiConfig.formatImageUrl(urlOrPath);

    if (formattedUrl.startsWith('http://') || formattedUrl.startsWith('https://')) {
      return NetworkImage(formattedUrl);
    }
    return AssetImage(formattedUrl);
  }

  static Future<void> show(
      BuildContext context, {
        required List<dynamic> avatarPool,
        required List<String> fallbackAvatarAssets,
        required int? selectedAvatarId,
        required String? profileAvatarUrl,
        required Function(int? avatarId, String? imageUrl) onAvatarSelected,
      }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AvatarPickerDialog(
        avatarPool: avatarPool,
        fallbackAvatarAssets: fallbackAvatarAssets,
        selectedAvatarId: selectedAvatarId,
        profileAvatarUrl: profileAvatarUrl,
        onAvatarSelected: onAvatarSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = avatarPool.isNotEmpty
        ? avatarPool
        : fallbackAvatarAssets.map((path) => {'id': null, 'image_url': path}).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose profile picture',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: GridView.builder(
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final String img = item['image_url'] ?? '';
                  final int? id = item['id'];

                  final bool selected = (id != null && id == selectedAvatarId) ||
                      (img.isNotEmpty && img == profileAvatarUrl);

                  return GestureDetector(
                    onTap: () {
                      SoundManager.instance.playClick();
                      Navigator.of(context).pop();
                      onAvatarSelected(id, img);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          backgroundImage: _getAvatarProvider(img),
                          radius: 36,
                          backgroundColor: Colors.grey.shade200,
                        ),
                        if (selected)
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.28),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.check, color: Colors.white),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () {
                SoundManager.instance.playClick();
                Navigator.of(context).pop();
                onAvatarSelected(null, null);
              },
              child: const Text('Remove / Reset to default'),
            ),
          ],
        ),
      ),
    );
  }
}