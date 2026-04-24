import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import '../providers/room_provider.dart';

class CreateRoomSheet extends ConsumerStatefulWidget {
  const CreateRoomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateRoomSheet(),
    );
  }

  @override
  ConsumerState<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends ConsumerState<CreateRoomSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _metric = 'CHECKINS';
  String _period = 'WEEKLY';
  bool _isPublic = true;
  int _maxMembers = 30;
  bool _loading = false;
  String? _error;

  static const _metrics = [
    {'value': 'CHECKINS',  'label': 'Check-ins',  'sub': 'Gym visits in period',                        'icon': Icons.bolt},
    {'value': 'SESSIONS',  'label': 'Classes',    'sub': 'Attended sessions',                            'icon': Icons.fitness_center},
    {'value': 'STREAK',    'label': 'Streak',     'sub': 'Consecutive days',                             'icon': Icons.local_fire_department},
    {'value': 'COMPOSITE', 'label': 'All-Around', 'sub': 'Check-ins + sessions + streak + challenges',   'icon': Icons.workspace_premium},
  ];

  static const _periods = [
    {'value': 'WEEKLY',  'label': 'Weekly',  'sub': 'Resets every Monday'},
    {'value': 'MONTHLY', 'label': 'Monthly', 'sub': 'Resets 1st of month'},
    {'value': 'ONGOING', 'label': 'Ongoing', 'sub': 'Cumulative, no reset'},
  ];

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(myRoomsProvider.notifier).createRoom(
        name: name,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        metric: _metric,
        period: _period,
        isPublic: _isPublic,
        maxMembers: _maxMembers,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _loading = false; _error = e.toString().replaceAll('Exception: ', ''); });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppTokens.colorBgPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTokens.colorBrand.withValues(alpha: 0.15),
                    ),
                    child: const Icon(Icons.emoji_events, color: AppTokens.colorBrand, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Create Room',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text('Compete with gym members',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon:
                        const Icon(Icons.close, color: Colors.white54, size: 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Divider(color: Colors.white.withValues(alpha: 0.06)),
            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                children: [
                  // Name
                  _label('Room Name'),
                  const SizedBox(height: 8),
                  _textField(_nameCtrl, 'January Gym Challenge'),
                  const SizedBox(height: 16),

                  // Description
                  _label('Description (optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 2,
                    decoration: _inputDecoration('Top 3 members win prizes!'),
                  ),
                  const SizedBox(height: 20),

                  // Metric
                  _label('Compete On'),
                  const SizedBox(height: 10),
                  ..._metrics.map((m) {
                    final selected = _metric == m['value'];
                    return GestureDetector(
                      onTap: () => setState(() => _metric = m['value'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: selected ? AppTokens.colorBrand.withValues(alpha: 0.1) : AppTokens.colorBgSurface,
                          border: Border.all(
                            color: selected ? AppTokens.colorBrand.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06),
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(m['icon'] as IconData, color: selected ? AppTokens.colorBrand : Colors.white38, size: 22),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m['label'] as String, style: TextStyle(color: selected ? AppTokens.colorBrand : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(m['sub'] as String, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                ],
                              ),
                            ),
                            if (selected) const Icon(Icons.check_circle, color: AppTokens.colorBrand, size: 18),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),

                  // Period
                  _label('Reset Period'),
                  const SizedBox(height: 10),
                  Row(
                    children: _periods.map((p) {
                      final selected = _period == p['value'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _period = p['value'] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: EdgeInsets.only(right: p['value'] == 'ONGOING' ? 0 : 8),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: selected ? AppTokens.colorBrand.withValues(alpha: 0.1) : AppTokens.colorBgSurface,
                              border: Border.all(color: selected ? AppTokens.colorBrand.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(p['label'] as String, style: TextStyle(color: selected ? AppTokens.colorBrand : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 3),
                                Text(p['sub'] as String, style: const TextStyle(color: Colors.white38, fontSize: 9), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Settings row
                  Row(
                    children: [
                      // Visibility
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Visibility'),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => setState(() => _isPublic = !_isPublic),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppTokens.colorBgSurface,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(_isPublic ? Icons.public : Icons.lock_outline,
                                        color: _isPublic ? Colors.greenAccent : Colors.white54, size: 18),
                                    const SizedBox(width: 8),
                                    Text(_isPublic ? 'Public' : 'Private',
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Max members
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Max Members'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTokens.colorBgSurface,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 16, color: Colors.white54),
                                    onPressed: () => setState(() => _maxMembers = (_maxMembers - 5).clamp(5, 500)),
                                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                  ),
                                  Expanded(child: Text('$_maxMembers', textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 16, color: Colors.white54),
                                    onPressed: () => setState(() => _maxMembers = (_maxMembers + 5).clamp(5, 500)),
                                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
            // CTA
            Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.colorBrand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Create Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8));

  Widget _textField(TextEditingController ctrl, String hint) => TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: _inputDecoration(hint),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 14),
        filled: true,
        fillColor: AppTokens.colorBgSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTokens.colorBrand)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}
