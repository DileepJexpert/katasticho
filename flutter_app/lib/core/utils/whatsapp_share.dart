import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared WhatsApp share utility.
/// Fetches share data from the backend, then opens wa.me deep link.
Future<void> launchWhatsAppShare(
  BuildContext context, {
  required Future<Map<String, dynamic>> Function() fetchShareData,
}) async {
  try {
    final response = await fetchShareData();
    final data = response['data'] is Map
        ? response['data'] as Map<String, dynamic>
        : response;

    final message = data['message']?.toString() ?? '';
    String phone = data['phone']?.toString() ?? '';

    if (phone.isEmpty && context.mounted) {
      phone = await _promptForPhone(context) ?? '';
    }
    if (phone.isEmpty) return;

    phone = phone.replaceAll(RegExp(r'[\s\-\+]'), '');
    if (phone.length == 10) phone = '91$phone';

    final url = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WhatsApp share failed: $e')),
      );
    }
  }
}

Future<String?> _promptForPhone(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Phone Number'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Enter phone number',
          prefixText: '+91 ',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Send'),
        ),
      ],
    ),
  );
}
