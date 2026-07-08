import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/app_error_banner.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/onboarding_notifier.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  static const _totalPages = 6;
  final _pageController = PageController();
  int _page = 0;

  // Local controllers for text inputs
  final _divisionController = TextEditingController();
  final _squatController = TextEditingController();
  final _benchController = TextEditingController();
  final _deadliftController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _divisionController.dispose();
    _squatController.dispose();
    _benchController.dispose();
    _deadliftController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _page++);
    }
  }

  void _back() {
    if (_page > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _page--);
    }
  }

  void _skip() => _next();

  bool get _canSkip => _page >= 2 && _page <= 4;
  bool get _canGoBack => _page > 0 && _page < _totalPages - 1;
  bool get _isLastPage => _page == _totalPages - 1;

  bool _nextEnabled(OnboardingDraft draft) {
    if (_page == 1) return draft.experienceLevel != null;
    return true;
  }

  bool _isFinishing = false;

  Future<void> _finish() async {
    if (_isFinishing) return;
    _isFinishing = true;
    try {
      final success = await ref.read(onboardingProvider.notifier).submit();
      if (success && mounted) context.go(AppRoutes.home);
    } finally {
      if (mounted) _isFinishing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            if (_page > 0)
              LinearProgressIndicator(
                value: _page / (_totalPages - 1),
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(cs.primary),
              ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomePage(onNext: _next),
                  _ExperiencePage(draft: draft),
                  _FederationPage(
                    draft: draft,
                    divisionController: _divisionController,
                  ),
                  _WeightClassPage(draft: draft),
                  _MaxesPage(
                    squatController: _squatController,
                    benchController: _benchController,
                    deadliftController: _deadliftController,
                  ),
                  _SuggestionPage(draft: draft),
                ],
              ),
            ),

            // Navigation bar (hidden on welcome page — it has its own CTA)
            if (_page > 0)
              _NavBar(
                canGoBack: _canGoBack,
                canSkip: _canSkip,
                isLastPage: _isLastPage,
                nextEnabled: _nextEnabled(draft),
                isSubmitting: draft.isSubmitting,
                error: draft.error,
                onBack: _back,
                onSkip: _skip,
                onNext: _next,
                onFinish: _finish,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Navigation bar ────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.canGoBack,
    required this.canSkip,
    required this.isLastPage,
    required this.nextEnabled,
    required this.isSubmitting,
    required this.error,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
    required this.onFinish,
  });

  final bool canGoBack;
  final bool canSkip;
  final bool isLastPage;
  final bool nextEnabled;
  final bool isSubmitting;
  final AppException? error;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: AppErrorBanner(error: error),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              // Back
              if (canGoBack)
                TextButton(
                  onPressed: onBack,
                  child: const Text('Back'),
                )
              else
                const SizedBox(width: 72),

              const Spacer(),

              // Skip
              if (canSkip)
                TextButton(
                  onPressed: onSkip,
                  child: const Text('Skip'),
                ),

              const SizedBox(width: 8),

              // Next / Finish
              FilledButton(
                onPressed: nextEnabled && !isSubmitting
                    ? (isLastPage ? onFinish : onNext)
                    : null,
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isLastPage ? 'Start IronLog' : 'Next'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Page 0: Welcome ───────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.fitness_center,
              size: 48,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to IronLog',
            style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Built for powerlifters. Track your attempts, analyze your meets, and push your total.',
            style: tt.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size(200, 52),
            ),
            child: const Text("Let's go"),
          ),
        ],
      ),
    );
  }
}

// ── Page 1: Experience Level ──────────────────────────────────────────────────

class _ExperiencePage extends ConsumerWidget {
  const _ExperiencePage({required this.draft});
  final OnboardingDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'How long have you been powerlifting?',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us suggest the right training approach.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          ...ExperienceLevel.values.map(
            (level) => _ExperienceCard(
              level: level,
              selected: draft.experienceLevel == level,
              onTap: () => ref
                  .read(onboardingProvider.notifier)
                  .setExperienceLevel(level),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final ExperienceLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
            border: Border.all(
              color: selected ? cs.primary : cs.outline,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.label,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? cs.onPrimaryContainer
                            : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      level.description,
                      style: tt.bodySmall?.copyWith(
                        color: selected
                            ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Page 2: Federation & Division ────────────────────────────────────────────

class _FederationPage extends ConsumerWidget {
  const _FederationPage({
    required this.draft,
    required this.divisionController,
  });

  final OnboardingDraft draft;
  final TextEditingController divisionController;

  static const _federations = ['IPF', 'USAPL', 'CPU', 'RPS', 'WRPF'];
  static const _genders = ['M', 'F', 'Mx'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final notifier = ref.read(onboardingProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'Where do you compete?',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Used to look up weight classes. Skip if not competing yet.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 28),

          // Federation
          Text('Federation', style: tt.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _federations
                .map(
                  (f) => ChoiceChip(
                    label: Text(f),
                    selected: draft.federation == f,
                    onSelected: (_) => notifier.setFederation(
                      draft.federation == f ? null : f,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),

          // Gender
          Text('Gender', style: tt.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _genders
                .map(
                  (g) => ChoiceChip(
                    label: Text(g),
                    selected: draft.gender == g,
                    onSelected: (_) =>
                        notifier.setGender(draft.gender == g ? null : g),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),

          // Division
          Text('Division (optional)', style: tt.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: divisionController,
            decoration: const InputDecoration(
              hintText: 'e.g. Open, Junior, Master',
              border: OutlineInputBorder(),
            ),
            onChanged: notifier.setDivision,
          ),
        ],
      ),
    );
  }
}

// ── Page 3: Weight Class ──────────────────────────────────────────────────────

class _WeightClassPage extends ConsumerWidget {
  const _WeightClassPage({required this.draft});
  final OnboardingDraft draft;

  static const _defaultWeightClasses = {
    'M': [59.0, 66.0, 74.0, 83.0, 93.0, 105.0, 120.0],
    'F': [47.0, 52.0, 57.0, 63.0, 69.0, 76.0, 84.0],
  };

  List<double> _classes(Map<String, dynamic>? data) {
    final gender = draft.gender;
    final federation = draft.federation;

    if (gender == null) {
      return [
        ..._defaultWeightClasses['M']!,
        ..._defaultWeightClasses['F']!,
      ]..sort();
    }

    if (data != null && federation != null) {
      final byFed = data[federation] as Map<String, dynamic>?;
      if (byFed != null) {
        if (gender == 'Mx') {
          final m = (byFed['M'] as List?)
                  ?.map((e) => (e as num).toDouble()) ??
              <double>[];
          final f = (byFed['F'] as List?)
                  ?.map((e) => (e as num).toDouble()) ??
              <double>[];
          return ({...m, ...f}.toList()..sort());
        }
        final list = byFed[gender] as List?;
        if (list != null) {
          return list.map((e) => (e as num).toDouble()).toList();
        }
      }
    }

    if (gender == 'Mx') {
      return ({
        ..._defaultWeightClasses['M']!,
        ..._defaultWeightClasses['F']!,
      }.toList()..sort());
    }
    return _defaultWeightClasses[gender] ?? [];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final weightClassAsync = ref.watch(weightClassesProvider);
    final classes = _classes(weightClassAsync.value);
    final notifier = ref.read(onboardingProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            "What's your weight class?",
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            draft.federation != null && draft.gender != null
                ? '${draft.federation} · ${draft.gender}'
                : 'Common weight classes shown. Select federation & gender in the previous step for exact classes.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          if (weightClassAsync.isLoading)
            const LinearProgressIndicator()
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: classes.map((kg) {
                final label =
                    kg % 1 == 0 ? '${kg.toInt()} kg' : '${kg} kg';
                final selected = draft.weightClassKg != null &&
                    (draft.weightClassKg! - kg).abs() < 0.001;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) =>
                      notifier.setWeightClass(selected ? null : kg),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ── Page 4: Current Maxes ─────────────────────────────────────────────────────

class _MaxesPage extends ConsumerWidget {
  const _MaxesPage({
    required this.squatController,
    required this.benchController,
    required this.deadliftController,
  });

  final TextEditingController squatController;
  final TextEditingController benchController;
  final TextEditingController deadliftController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final notifier = ref.read(onboardingProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'What are your current bests?',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Used to personalize your program suggestion. All fields optional.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          _MaxField(
            label: 'Squat 1RM',
            controller: squatController,
            icon: Icons.arrow_downward,
            onChanged: (v) => notifier.setSquat(double.tryParse(v)),
          ),
          const SizedBox(height: 16),
          _MaxField(
            label: 'Bench Press 1RM',
            controller: benchController,
            icon: Icons.horizontal_rule,
            onChanged: (v) => notifier.setBench(double.tryParse(v)),
          ),
          const SizedBox(height: 16),
          _MaxField(
            label: 'Deadlift 1RM',
            controller: deadliftController,
            icon: Icons.arrow_upward,
            onChanged: (v) => notifier.setDeadlift(double.tryParse(v)),
          ),
        ],
      ),
    );
  }
}

class _MaxField extends StatelessWidget {
  const _MaxField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'kg',
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

// ── Page 5: Program Suggestion ────────────────────────────────────────────────

class _SuggestionPage extends StatelessWidget {
  const _SuggestionPage({required this.draft});
  final OnboardingDraft draft;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final level = draft.experienceLevel ?? ExperienceLevel.beginner;

    double? total;
    if (draft.squatKg != null &&
        draft.benchKg != null &&
        draft.deadliftKg != null) {
      total = draft.squatKg! + draft.benchKg! + draft.deadliftKg!;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            "You're all set!",
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on your experience, here is our program recommendation.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),

          // Suggestion card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      level.label,
                      style: tt.labelLarge?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  level.suggestion,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Total if provided
          if (total != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _TotalStat(
                      label: 'SBD Total',
                      value: '${total.toStringAsFixed(1)} kg'),
                  if (draft.squatKg != null)
                    _TotalStat(
                        label: 'Squat',
                        value: '${draft.squatKg!.toStringAsFixed(1)} kg'),
                  if (draft.benchKg != null)
                    _TotalStat(
                        label: 'Bench',
                        value: '${draft.benchKg!.toStringAsFixed(1)} kg'),
                  if (draft.deadliftKg != null)
                    _TotalStat(
                        label: 'Deadlift',
                        value:
                            '${draft.deadliftKg!.toStringAsFixed(1)} kg'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Text(
            'You can update all of this later in your profile settings.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TotalStat extends StatelessWidget {
  const _TotalStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
