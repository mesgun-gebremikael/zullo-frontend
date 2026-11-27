/// Conservative address syntax checks. Only an emailed code proves ownership.
/// Do not silently fix a domain or reject legitimate custom email providers.
class EmailAddressValidation {
  static bool isValid(String input) {
    final value = input.trim();
    if (value.length > 200 ||
        value.contains(RegExp(r'\s')) ||
        value.contains(RegExp(r'[<>\r\n]'))) {
      return false;
    }
    final parts = value.split('@');
    if (parts.length != 2 || parts.first.isEmpty || parts.first.length > 64) {
      return false;
    }
    final local = parts.first;
    if (local.startsWith('.') || local.endsWith('.') || local.contains('..')) {
      return false;
    }
    if (!RegExp(r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+$").hasMatch(local)) {
      return false;
    }
    final domain = parts.last;
    final labels = domain.split('.');
    if (labels.length < 2 || labels.last.length < 2) return false;
    return labels.every((label) =>
        label.isNotEmpty &&
        label.length <= 63 &&
        !label.startsWith('-') &&
        !label.endsWith('-') &&
        !label.contains(RegExp(r'[^A-Za-z0-9\-\u0080-\uFFFF]')));
  }

  static String? suggestedAddress(String input) {
    final value = input.trim();
    final at = value.lastIndexOf('@');
    if (at < 1) return null;
    const domains = {
      'gmail.ocm': 'gmail.com',
      'gmail.con': 'gmail.com',
      'gmial.com': 'gmail.com',
      'gmai.com': 'gmail.com',
      'outlook.ocm': 'outlook.com',
      'outlook.con': 'outlook.com',
      'hotmail.ocm': 'hotmail.com',
      'hotmail.con': 'hotmail.com',
      'yahoo.ocm': 'yahoo.com',
      'yahoo.con': 'yahoo.com',
    };
    final corrected = domains[value.substring(at + 1).toLowerCase()];
    return corrected == null ? null : '${value.substring(0, at)}@$corrected';
  }
}
