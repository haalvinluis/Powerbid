import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/section_header.dart';
import 'create_join_room_screen.dart';

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  String _selectedCategory = 'cricket';
  String _selectedGameMode = 'AUCTION_TEAM_CHALLENGE'; // 'AUCTION_TEAM_CHALLENGE' or 'POWER_COMPARISON'
  int _selectedItemCount = 10;
  List<Map<String, dynamic>> _categoriesList = [];
  bool _isLoadingCategories = true;

  final List<int> _itemCountOptions = [5, 10, 25];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final list = await SocketService.instance.getCategories();
      if (mounted) {
        setState(() {
          _categoriesList = list;
          _isLoadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auction Mode & Category Selection'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Game Mode Selection Header
              const SectionHeader(
                title: 'Select Game Mode',
                subtitle: 'Choose how match winner is determined',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildGameModeCard(
                      modeId: 'AUCTION_TEAM_CHALLENGE',
                      title: 'Mode B: Team Challenge',
                      subtitle: 'Auction bidding to build team; highest total team points wins',
                      icon: Icons.groups_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildGameModeCard(
                      modeId: 'POWER_COMPARISON',
                      title: 'Mode A: 1v1 Compare',
                      subtitle: 'Direct text character power comparison per round',
                      icon: Icons.compare_arrows_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Category Selection Header
              const SectionHeader(
                title: 'Select Category Catalog',
                subtitle: 'Authentic character records across 11 official categories',
              ),
              const SizedBox(height: 12),

              _isLoadingCategories
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(color: AppTheme.accent),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _categoriesList.length,
                      itemBuilder: (context, index) {
                        final cat = _categoriesList[index];
                        final catId = cat['id'] ?? 'cricket';
                        final name = cat['name'] ?? catId;
                        final actualCount = cat['actualCount'] ?? 0;
                        final targetCount = cat['targetCount'] ?? 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: _buildCategoryCard(
                            categoryId: catId,
                            title: name,
                            countText: '$actualCount / $targetCount Valid Records Available',
                            icon: _getCategoryIcon(catId),
                          ),
                        );
                      },
                    ),

              const SizedBox(height: 24),

              // Match Size Selection Header
              const SectionHeader(
                title: 'Auction Match Size',
                subtitle: 'Number of character items auctioned per match',
              ),
              const SizedBox(height: 12),
              Row(
                children: _itemCountOptions.map((count) {
                  final isSelected = _selectedItemCount == count;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedItemCount = count;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.accent : AppTheme.surfaceLight,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ITEMS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white70 : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Notice Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppTheme.accent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pure text-only mode active. Maximum 8 human players per room.',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Continue Button
              CustomButton(
                label: 'Continue to Room Setup',
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateJoinRoomScreen(
                        selectedCategory: _selectedCategory,
                        gameMode: _selectedGameMode,
                        itemCount: _selectedItemCount,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameModeCard({
    required String modeId,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedGameMode == modeId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGameMode = modeId;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surfaceLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isSelected ? AppTheme.accent : Colors.white70, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String categoryId,
    required String title,
    required String countText,
    required IconData icon,
  }) {
    final isSelected = _selectedCategory == categoryId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = categoryId;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surfaceLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    countText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: categoryId,
              groupValue: _selectedCategory,
              activeColor: AppTheme.accent,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCategory = val;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String catId) {
    switch (catId.toLowerCase()) {
      case 'cricket':
        return Icons.sports_cricket_rounded;
      case 'naruto':
        return Icons.bolt_rounded;
      case 'one_piece':
        return Icons.sailing_rounded;
      case 'dragon_ball':
        return Icons.local_fire_department_rounded;
      case 'pokemon':
        return Icons.catching_pokemon_rounded;
      case 'demon_slayer':
        return Icons.content_cut_rounded;
      case 'jujutsu_kaisen':
        return Icons.auto_awesome_rounded;
      case 'classic_cartoons':
        return Icons.tv_rounded;
      case 'superheroes':
        return Icons.shield_rounded;
      case 'marvel_avengers':
        return Icons.stars_rounded;
      case 'other_anime':
      default:
        return Icons.movie_filter_rounded;
    }
  }
}
