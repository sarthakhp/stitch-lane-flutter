import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/contact_data.dart';

class ContactsService {
  static bool get isContactsAvailable {
    if (kIsWeb) return false;
    return true;
  }

  static Future<bool> checkPermission() async {
    if (!isContactsAvailable) return false;
    
    try {
      return await FlutterContacts.requestPermission(readonly: true);
    } catch (e) {
      return false;
    }
  }

  static Future<bool> requestPermission({bool readonly = true}) async {
    if (!isContactsAvailable) return false;
    
    try {
      return await FlutterContacts.requestPermission(readonly: readonly);
    } catch (e) {
      return false;
    }
  }

  static Future<ContactData?> pickContact() async {
    if (!isContactsAvailable) return null;

    try {
      final hasPermission = await requestPermission(readonly: true);
      if (!hasPermission) return null;

      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return null;

      final fullContact = await FlutterContacts.getContact(contact.id);
      if (fullContact == null) return null;

      final name = fullContact.displayName.trim();
      if (name.isEmpty) return null;

      String phoneNumber = '';
      if (fullContact.phones.isNotEmpty) {
        phoneNumber = fullContact.phones.first.number.trim();
      }

      return ContactData(
        name: name,
        phoneNumber: phoneNumber,
      );
    } catch (e) {
      return null;
    }
  }

  static String _normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
  }

  static Future<bool> _contactExists(String phoneNumber) async {
    try {
      final normalizedInput = _normalizePhoneNumber(phoneNumber);

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      for (final contact in contacts) {
        for (final phone in contact.phones) {
          final normalizedContactPhone = _normalizePhoneNumber(phone.number);

          if (normalizedContactPhone == normalizedInput) {
            return true;
          }

          if (normalizedContactPhone.endsWith(normalizedInput) ||
              normalizedInput.endsWith(normalizedContactPhone)) {
            if ((normalizedContactPhone.length - normalizedInput.length).abs() <= 3) {
              return true;
            }
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
      final hasPermission = await requestPermission(readonly: false);
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

