import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherHelper {
  static const String _whatsappBaseUrl = 'https://wa.me/';
  static const String _telScheme = 'tel:';

  static String _cleanPhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  }

  static Future<bool> openWhatsApp(
    BuildContext context,
    String phoneNumber,
  ) async {
    final cleanNumber = _cleanPhoneNumber(phoneNumber);
    final uri = Uri.parse('$_whatsappBaseUrl$cleanNumber');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        if (context.mounted) {
          _showErrorSnackBar(context, 'Could not open WhatsApp');
        }
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Error opening WhatsApp: $e');
      }
      return false;
    }
  }

  static Future<bool> makePhoneCall(
    BuildContext context,
    String phoneNumber,
  ) async {
    final cleanNumber = _cleanPhoneNumber(phoneNumber);
    final uri = Uri.parse('$_telScheme$cleanNumber');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      } else {
        if (context.mounted) {
          _showErrorSnackBar(context, 'Could not make phone call');
        }
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Error making phone call: $e');
      }
      return false;
    }
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

