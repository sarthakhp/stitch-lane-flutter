import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart'
    as native_picker;
import '../../utils/app_logger.dart';
import '../models/contact_data.dart';

class ContactsService {
  static final native_picker.FlutterNativeContactPicker _nativeContactPicker =
      native_picker.FlutterNativeContactPicker();

  static bool get isContactsAvailable {
    if (kIsWeb) return false;
    return true;
  }

  static Future<bool> requestWritePermission() async {
    if (!isContactsAvailable) return false;

    try {
      final result = await FlutterContacts.requestPermission(readonly: false);
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<ContactData?> pickContact() async {
    if (!isContactsAvailable) return null;

    try {
      final contact = await _nativeContactPicker.selectContact();
      if (contact == null) return null;

      final name = contact.fullName?.trim() ?? '';
      if (name.isEmpty) return null;

      String phoneNumber = '';
      if (contact.phoneNumbers != null && contact.phoneNumbers!.isNotEmpty) {
        phoneNumber = contact.phoneNumbers!.first.trim();
      }

      return ContactData(
        name: name,
        phoneNumber: phoneNumber,
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ContactsService] pickContact failed', e, stackTrace);
      return null;
    }
  }

  static String _normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String _getLocalNumber(String normalizedNumber) {
    if (normalizedNumber.length > 10) {
      return normalizedNumber.substring(normalizedNumber.length - 10);
    }
    return normalizedNumber;
  }

  static Future<bool> _contactExists(String phoneNumber) async {
    try {
      final normalizedInput = _normalizePhoneNumber(phoneNumber);
      if (normalizedInput.isEmpty) return false;

      final localInput = _getLocalNumber(normalizedInput);

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      for (final contact in contacts) {
        for (final phone in contact.phones) {
          final normalizedContactPhone = _normalizePhoneNumber(phone.number);
          if (normalizedContactPhone.isEmpty) continue;

          if (normalizedContactPhone == normalizedInput) {
            return true;
          }

          final localContactPhone = _getLocalNumber(normalizedContactPhone);
          if (localInput.length >= 10 && localContactPhone == localInput) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> saveToContacts(String name, String phoneNumber) async {
    if (!isContactsAvailable) return false;
    if (name.trim().isEmpty) return false;

    try {
      final hasPermission = await requestWritePermission();
      if (!hasPermission) return false;

      final exists = await _contactExists(phoneNumber.trim());
      if (exists) {
        return false;
      }

      final contact = Contact()
        ..name.first = name.trim()
        ..phones = [Phone(phoneNumber.trim())];

      await contact.insert();
      return true;
    } catch (e) {
      return false;
    }
  }
}

