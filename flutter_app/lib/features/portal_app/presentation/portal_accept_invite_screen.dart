import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_config.dart';
import '../data/portal_session.dart';

/// Public screen where an invited contact sets a password and activates
/// their portal account. The invite [token] may be passed in (e.g. via a
/// deep link) or pasted manually.
class PortalAcceptInviteScreen extends ConsumerStatefulWidget {
  const PortalAcceptInviteScreen({super.key, this.token});

  final String? token;

  @override
  ConsumerState<PortalAcceptInviteScreen> createState() =>
      _PortalAcceptInviteScreenState();
}

class _PortalAcceptInviteScreenState
    extends ConsumerState<PortalAcceptInviteScreen> {
  late final TextEditingController _tokenCtrl;
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _tokenCtrl = TextEditingController(text: widget.token ?? '');
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final token = _tokenCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    if (token.isEmpty) {
      _snack('Enter the invite token from your email.');
      return;
    }
    if (password.length < 8) {
      _snack('Password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      _snack('Passwords do not match.');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ref.read(portalDioProvider).post(
        ApiConfig.portalAcceptInvite,
        data: {'token': token, 'password': password},
      );
      final data = res.data['data'] as Map<String, dynamic>;
      final newToken = data['token'] as String?;
      if (newToken == null || newToken.isEmpty) {
        _snack('Activation failed: no token returned.');
        return;
      }
      ref.read(portalTokenProvider.notifier).state = newToken;
      ref.read(portalProfileProvider.notifier).state =
          data['portalUser'] as Map<String, dynamic>?;
      if (!mounted) return;
      context.go('/portal/home');
    } on DioException catch (e) {
      _snack(_errorMessage(e));
    } catch (e) {
      _snack('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Unable to activate your account. Check the token and try again.';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _loading ? null : () => context.go('/portal/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Activate your portal access',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the invite token from your email and choose a '
                      'password.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _tokenCtrl,
                      enabled: !_loading,
                      decoration: const InputDecoration(
                        labelText: 'Invite token',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordCtrl,
                      enabled: !_loading,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        helperText: 'At least 8 characters',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmCtrl,
                      enabled: !_loading,
                      obscureText: _obscure,
                      onSubmitted: (_) => _loading ? null : _activate(),
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _activate,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Activate account'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed:
                          _loading ? null : () => context.go('/portal/login'),
                      child: const Text('Already activated? Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
