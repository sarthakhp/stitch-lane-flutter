import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../utils/url_launcher_helper.dart';

class ContactActionButtons extends StatelessWidget {
  final String phoneNumber;

  const ContactActionButtons({
    super.key,
    required this.phoneNumber,
  });

  static const Color _whatsappGreen = Color(0xFF25D366);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => UrlLauncherHelper.openWhatsApp(context, phoneNumber),
            icon: const Icon(Icons.chat),
            label: const Text('WhatsApp'),
            style: FilledButton.styleFrom(
              backgroundColor: _whatsappGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: AppConfig.spacing8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => UrlLauncherHelper.makePhoneCall(context, phoneNumber),
            icon: const Icon(Icons.phone),
            label: const Text('Call'),
          ),
        ),
      ],
    );
  }
}

