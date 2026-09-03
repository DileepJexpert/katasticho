import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/api_error_parser.dart';
import '../../../../core/widgets/k_button.dart';
import '../../../../core/widgets/k_card.dart';
import '../../../../core/widgets/k_loading.dart';
import '../../data/field_sales_repository.dart';

void showMrEDetailingModal(BuildContext context, {required String visitId, required String doctorName}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MrEDetailingModal(visitId: visitId, doctorName: doctorName),
  );
}

class _MrEDetailingModal extends ConsumerStatefulWidget {
  final String visitId;
  final String doctorName;
  const _MrEDetailingModal({required this.visitId, required this.doctorName});

  @override
  ConsumerState<_MrEDetailingModal> createState() => _MrEDetailingModalState();
}

class _MrEDetailingModalState extends ConsumerState<_MrEDetailingModal> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _detailAids = [];
  int _currentSlideIndex = 0;

  // Detailing Timer
  Timer? _timer;
  int _secondsElapsed = 0;

  // Logged Products
  final List<Map<String, dynamic>> _loggedProducts = [];

  @override
  void initState() {
    super.initState();
    _loadAids();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  String _formatTimer(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _loadAids() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final aids = await repo.activeDetailAids();
      if (mounted) {
        setState(() {
          _detailAids = aids;
          if (_detailAids.isNotEmpty) {
            for (var a in _detailAids) {
              _loggedProducts.add({
                'productName': a['productName'] ?? a['name'],
                'detailed': true,
                'sampleQty': 0,
                'giftName': '',
                'giftQty': 0,
              });
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load detail aids: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDetailing() async {
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      await repo.logVisitProducts(widget.visitId, _loggedProducts);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doctor call detailing & samples logged!'), backgroundColor: KColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log products: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: KColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(KSpacing.xs),
                  decoration: BoxDecoration(
                    color: KColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.slideshow_outlined, color: KColors.primary, size: 20),
                ),
                const SizedBox(width: KSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('e-Detailing: ${widget.doctorName}', style: KTypography.h3),
                    Text('Visual Presentation & Sampling', style: KTypography.caption.copyWith(color: KColors.textSecondary)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: KColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: KColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimer(_secondsElapsed),
                        style: KTypography.bodySmall.copyWith(color: KColors.warning, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Interactive Body
          Expanded(
            child: _isLoading
                ? const Center(child: KLoading())
                : _detailAids.isEmpty
                    ? Center(
                        child: Text(
                          'No e-detailing aids found for your product division.\nYou can still record samples given below.',
                          textAlign: TextAlign.center,
                          style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
                        ),
                      )
                    : Row(
                        children: [
                          // Left Visual Slide Canvas (60%)
                          Expanded(
                            flex: 6,
                            child: Container(
                              color: KColors.bgApp,
                              padding: const EdgeInsets.all(KSpacing.md),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: KCard(
                                        padding: const EdgeInsets.all(KSpacing.lg),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.medical_information, size: 64, color: KColors.primary),
                                            const SizedBox(height: KSpacing.md),
                                            Text(
                                              _detailAids[_currentSlideIndex]['productName']?.toString() ??
                                                  _detailAids[_currentSlideIndex]['name']?.toString() ??
                                                  'Medical Brand',
                                              style: KTypography.h2,
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: KSpacing.xs),
                                            Text(
                                              _detailAids[_currentSlideIndex]['description']?.toString() ??
                                                  'Proven clinical efficacy and safety profile.',
                                              style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: KSpacing.sm),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.arrow_back),
                                        onPressed: _currentSlideIndex > 0
                                            ? () => setState(() => _currentSlideIndex--)
                                            : null,
                                      ),
                                      Text(
                                        'Slide ${_currentSlideIndex + 1} of ${_detailAids.length}',
                                        style: KTypography.labelMedium,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.arrow_forward),
                                        onPressed: _currentSlideIndex < _detailAids.length - 1
                                            ? () => setState(() => _currentSlideIndex++)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1),

                          // Right Samples & Disbursal Panel (40%)
                          Expanded(
                            flex: 4,
                            child: ListView(
                              padding: const EdgeInsets.all(KSpacing.md),
                              children: [
                                Text('Sample & Promo Disbursal', style: KTypography.h3),
                                const SizedBox(height: KSpacing.sm),
                                ..._loggedProducts.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final prod = entry.value;
                                  final sampleQty = prod['sampleQty'] as int? ?? 0;

                                  return KCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prod['productName']?.toString() ?? 'Product',
                                          style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: KSpacing.sm),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Sample Packs Given:', style: KTypography.caption),
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                                  onPressed: sampleQty > 0
                                                      ? () => setState(() => _loggedProducts[idx]['sampleQty'] = sampleQty - 1)
                                                      : null,
                                                ),
                                                Text('$sampleQty', style: KTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                                                IconButton(
                                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                                  onPressed: () => setState(() => _loggedProducts[idx]['sampleQty'] = sampleQty + 1),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: const BoxDecoration(
              color: KColors.surface,
              border: Border(top: BorderSide(color: KColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Call Duration: ${_formatTimer(_secondsElapsed)}',
                  style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                KButton(
                  label: 'Finish & Save Call Log',
                  icon: Icons.check,
                  onPressed: _saveDetailing,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
