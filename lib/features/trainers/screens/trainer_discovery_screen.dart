import 'package:fitness_app/core/responsive/app_breakpoints.dart';
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/category_chip.dart';
import 'package:fitness_app/core/widgets/empty_state_widget.dart';
import 'package:fitness_app/core/widgets/shimmer_skeleton.dart';
import 'package:fitness_app/features/trainers/models/trainer_filter_criteria.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:fitness_app/features/trainers/screens/trainer_dashboard_screen.dart';
import 'package:fitness_app/features/trainers/screens/trainer_registration_screen.dart';
import 'package:fitness_app/features/trainers/services/trainer_service.dart';
import 'package:fitness_app/features/trainers/widgets/trainer_card.dart';
import 'package:flutter/material.dart';

/// Trainer Discovery Screen: search bar, specialty filter chips, hourly rate
/// ceiling slider, trainer cards list, and empty / error states.
class TrainerDiscoveryScreen extends StatefulWidget {
  const TrainerDiscoveryScreen({
    super.key,
    this.initialTrainers,
    this.trainerService,
  });

  /// Optional preloaded trainers for testing or standalone execution
  final List<TrainerProfile>? initialTrainers;
  final TrainerService? trainerService;

  @override
  State<TrainerDiscoveryScreen> createState() => _TrainerDiscoveryScreenState();
}

class _TrainerDiscoveryScreenState extends State<TrainerDiscoveryScreen> {
  final _searchController = TextEditingController();
  late final TrainerService _trainerService;
  List<TrainerProfile> _allTrainers = <TrainerProfile>[];
  List<TrainerProfile> _filteredTrainers = <TrainerProfile>[];
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedSpecialty = 'All';
  double _maxHourlyRate = 5000;
  double? _minRating;
  bool _showRateSlider = false;

  static const List<String> _specialties = <String>[
    'All',
    'Strength',
    'Hypertrophy',
    'HIIT',
    'Mobility',
    'Powerlifting',
    'Nutrition',
    'Yoga',
  ];

  @override
  void initState() {
    super.initState();
    _trainerService = widget.trainerService ?? TrainerService();
    _loadTrainers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrainers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.initialTrainers != null) {
        _allTrainers = widget.initialTrainers!;
      } else {
        _allTrainers = await _trainerService.getTrainers(forceRefresh: true);
      }
      _applyFilters();
    } on Object catch (_) {
      _errorMessage =
          'Could not load trainer marketplace. Tap below to retry.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final criteria = TrainerFilterCriteria(
      searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      selectedSpecialty:
          _selectedSpecialty != 'All' ? _selectedSpecialty : null,
      maxHourlyRate: _maxHourlyRate,
      minRating: _minRating,
    );

    setState(() {
      _filteredTrainers = _allTrainers.where(criteria.matches).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedSpecialty = 'All';
      _maxHourlyRate = 5000;
      _minRating = null;
    });
    _applyFilters();
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedSpecialty != 'All' ||
      _maxHourlyRate < 5000 ||
      _minRating != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppBreakpoints.desktopMin;
    final isWide = width >= AppBreakpoints.wideDesktopMin;
    final crossAxisCount = isWide ? 3 : (isDesktop ? 2 : 1);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.marketplaceMaxWidth,
          ),
          child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 110,
              floating: true,
              pinned: true,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: Text(
                  'Find a Coach',
                  style: theme.appBarTheme.titleTextStyle,
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.background, AppColors.surface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.dashboard_customize_rounded),
                  tooltip: 'Trainer Dashboard',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<dynamic>(
                        builder: (context) => TrainerDashboardScreen(
                          trainerService: _trainerService,
                        ),
                      ),
                    );
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Be a Coach'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<dynamic>(
                        builder: (context) => TrainerRegistrationScreen(
                          trainerService: _trainerService,
                        ),
                      ),
                    ).then((_) => _loadTrainers());
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ];
        },
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadTrainers,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          _searchQuery = val.trim();
                          _applyFilters();
                        },
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText:
                              'Search coach by name, specialty, or bio...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.textSecondary,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: AppColors.textSecondary,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _applyFilters();
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _specialties.map((specialty) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: CategoryChip(
                                label: specialty,
                                isSelected: _selectedSpecialty == specialty,
                                onTap: () {
                                  setState(() {
                                    _selectedSpecialty = specialty;
                                  });
                                  _applyFilters();
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showRateSlider = !_showRateSlider;
                              });
                            },
                            child: Row(
                              children: [
                                Icon(
                                  _showRateSlider
                                      ? Icons.tune_rounded
                                      : Icons.filter_list_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Max Rate: '
                                  '₹${_maxHourlyRate.toStringAsFixed(0)}/hr',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _showRateSlider
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                          if (_hasActiveFilters)
                            TextButton(
                              onPressed: _resetFilters,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                              ),
                              child: const Text(
                                'Clear Filters',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_showRateSlider) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Price Range Ceiling',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Up to ₹'
                                    '${_maxHourlyRate.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppColors.primary,
                                  inactiveTrackColor: AppColors.surfaceElevated,
                                  thumbColor: AppColors.primary,
                                  overlayColor:
                                      AppColors.primary.withValues(alpha: 0.2),
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  value: _maxHourlyRate,
                                  min: 500,
                                  max: 5000,
                                  divisions: 18,
                                  onChanged: (val) {
                                    setState(() {
                                      _maxHourlyRate = val;
                                    });
                                    _applyFilters();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        '${_filteredTrainers.length} coaches available',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  child: ShimmerTrainerDiscoverySkeleton(),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateWidget(
                    icon: Icons.cloud_off_rounded,
                    title: 'Marketplace Unavailable',
                    description: _errorMessage!,
                    buttonText: 'Try Again',
                    onButtonPressed: _loadTrainers,
                  ),
                )
              else if (_allTrainers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateWidget(
                    icon: Icons.sports_gymnastics_rounded,
                    title: 'No Coaches Registered Yet',
                    description:
                        'Be the first certified fitness coach to join the '
                        'PulseFit AI marketplace and start coaching clients.',
                    buttonText: 'Become a Coach',
                    onButtonPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<dynamic>(
                          builder: (context) => TrainerRegistrationScreen(
                            trainerService: _trainerService,
                          ),
                        ),
                      ).then((_) => _loadTrainers());
                    },
                  ),
                )
              else if (_filteredTrainers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateWidget(
                    icon: Icons.person_search_rounded,
                    title: 'No Coaches Found',
                    description:
                        'No coaches match your search criteria. Try expanding '
                        'your price range or selecting another specialty.',
                    buttonText: 'Reset Filters',
                    onButtonPressed: _resetFilters,
                  ),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  sliver: crossAxisCount == 1
                      ? SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return TrainerCard(
                                  trainer: _filteredTrainers[index]);
                            },
                            childCount: _filteredTrainers.length,
                          ),
                        )
                      : SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 220,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return TrainerCard(
                                  trainer: _filteredTrainers[index]);
                            },
                            childCount: _filteredTrainers.length,
                          ),
                        ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}
