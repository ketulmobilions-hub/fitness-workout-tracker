import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_domain/fitness_domain.dart';

import '../../providers/profile_providers.dart';

class CompetitionProfileScreen extends ConsumerStatefulWidget {
  const CompetitionProfileScreen({super.key});

  @override
  ConsumerState<CompetitionProfileScreen> createState() =>
      _CompetitionProfileScreenState();
}

class _CompetitionProfileScreenState
    extends ConsumerState<CompetitionProfileScreen> {
  static const _federations = ['IPF', 'USAPL', 'CPU', 'RPS', 'WRPF'];
  static const _genders = ['M', 'F', 'Mx'];

  // Default classes used while the reference endpoint is loading.
  static const _defaultWeightClasses = {
    'M': [53.0, 59.0, 66.0, 74.0, 83.0, 93.0, 105.0, 120.0],
    'F': [43.0, 47.0, 52.0, 57.0, 63.0, 69.0, 76.0, 84.0],
  };

  String? _federation;
  double? _weightClassKg;
  String? _gender;

  bool _saving = false;
  String? _error;
  String? _bwError;

  // True once profile values have been pre-filled. Prevents the stream from
  // overwriting edits the user has already made on this screen.
  bool _initialized = false;

  final _divisionController = TextEditingController();
  final _bodyweightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Immediate fill if the profile is already loaded.
      final profile = ref.read(profileStreamProvider).value;
      if (profile != null) _applyProfile(profile);

      // Re-fill when profile arrives after a cold-launch delay.
      ref.listen<AsyncValue<UserProfile?>>(
        profileStreamProvider,
        (_, next) {
          if (!_initialized) {
            next.whenData((p) {
              if (p != null) _applyProfile(p);
            });
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _divisionController.dispose();
    _bodyweightController.dispose();
    super.dispose();
  }

  void _applyProfile(UserProfile profile) {
    setState(() {
      _federation = profile.federation;
      _weightClassKg = profile.weightClassKg;
      _gender = profile.gender;
      _divisionController.text = profile.division ?? '';
      if (profile.bodyweightKg != null) {
        _bodyweightController.text =
            profile.bodyweightKg!.toStringAsFixed(1);
      }
      _initialized = true;
    });
  }

  List<double> _availableWeightClasses(Map<String, dynamic>? weightClassData) {
    if (_gender == null) return [];

    if (weightClassData != null && _federation != null) {
      final byFed = weightClassData[_federation] as Map<String, dynamic>?;
      if (byFed != null) {
        if (_gender == 'Mx') {
          // Merge M+F classes for non-binary athletes — federations don't yet
          // publish separate Mx classes; athletes typically use whichever
          // class applies to their body weight.
          final mClasses =
              (byFed['M'] as List<dynamic>?)?.map((e) => (e as num).toDouble()) ??
                  <double>[];
          final fClasses =
              (byFed['F'] as List<dynamic>?)?.map((e) => (e as num).toDouble()) ??
                  <double>[];
          return ({...mClasses, ...fClasses}.toList()..sort());
        }
        final classes = byFed[_gender] as List<dynamic>?;
        if (classes != null) {
          return classes.map((e) => (e as num).toDouble()).toList();
        }
      }
    }

    // Fall back to defaults while reference data is loading.
    if (_gender == 'Mx') {
      return ({
        ..._defaultWeightClasses['M']!,
        ..._defaultWeightClasses['F']!,
      }.toList()..sort());
    }
    return _defaultWeightClasses[_gender] ?? [];
  }

  bool _validateBodyweight() {
    final text = _bodyweightController.text.trim();
    if (text.isEmpty) {
      setState(() => _bwError = null);
      return true;
    }
    final v = double.tryParse(text);
    if (v == null || v <= 0 || v > 500) {
      setState(
          () => _bwError = 'Enter a weight between 0 and 500 kg');
      return false;
    }
    setState(() => _bwError = null);
    return true;
  }

  Future<void> _save() async {
    if (!_validateBodyweight()) return;
    final text = _bodyweightController.text.trim();
    final bw = text.isEmpty ? null : double.parse(text);
    final division = _divisionController.text.trim();

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updateCompetitionProfile(
            federation: _federation,
            division: division.isEmpty ? null : division,
            weightClassKg: _weightClassKg,
            bodyweightKg: bw,
            gender: _gender,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch cached weight-class reference data (fetched once, keepAlive).
    final weightClassAsync = ref.watch(weightClassesProvider);
    final weightClassData = weightClassAsync.value;
    final classes = _availableWeightClasses(weightClassData);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Competition Profile'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _error!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),

          // Gender
          _SectionLabel('Gender'),
          Wrap(
            spacing: 8,
            children: _genders
                .map(
                  (g) => ChoiceChip(
                    label: Text(g),
                    selected: _gender == g,
                    onSelected: (_) => setState(() {
                      _gender = g;
                      // Clear weight class — classes differ by gender.
                      _weightClassKg = null;
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),

          // Federation
          _SectionLabel('Federation'),
          Wrap(
            spacing: 8,
            children: _federations
                .map(
                  (f) => ChoiceChip(
                    label: Text(f),
                    selected: _federation == f,
                    onSelected: (_) => setState(() {
                      _federation = f;
                      // Clear weight class — classes vary by federation.
                      _weightClassKg = null;
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),

          // Weight class — shown when a gender is selected
          if (_gender != null) ...[
            _SectionLabel('Weight Class (kg)'),
            if (weightClassAsync.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else
              Wrap(
                spacing: 8,
                children: classes
                    .map(
                      (kg) => ChoiceChip(
                        label: Text(kg % 1 == 0
                            ? kg.toInt().toString()
                            : kg.toString()),
                        // Epsilon comparison — avoids float equality pitfall
                        // for values like 67.5 that may differ in last bit.
                        selected: _weightClassKg != null &&
                            (_weightClassKg! - kg).abs() < 0.001,
                        onSelected: (_) =>
                            setState(() => _weightClassKg = kg),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 20),
          ],

          // Division
          _SectionLabel('Division (optional)'),
          TextField(
            controller: _divisionController,
            decoration: const InputDecoration(
              hintText: 'e.g. Open, Junior, Master',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          // Bodyweight
          _SectionLabel('Current Bodyweight (kg, optional)'),
          TextField(
            controller: _bodyweightController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _validateBodyweight(),
            decoration: InputDecoration(
              hintText: 'e.g. 82.5',
              border: const OutlineInputBorder(),
              suffixText: 'kg',
              errorText: _bwError,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
