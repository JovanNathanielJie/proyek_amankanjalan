class EmailValidator {
  /// Domain email yang diizinkan
  static const List<String> allowedDomains = [
    'gmail.com',
    'yahoo.com',
    'outlook.com',
    'hotmail.com',
    'mail.com',
    'protonmail.com',
    'icloud.com',
  ];

  /// Validasi email hanya dengan domain yang diizinkan
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email tidak boleh kosong';
    }

    // Cek format dasar email
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Format email tidak valid';
    }

    // Ekstrak domain dari email
    final parts = value.trim().split('@');
    if (parts.length != 2) {
      return 'Format email tidak valid';
    }

    final domain = parts[1].toLowerCase();

    // Cek apakah domain ada di dalam daftar yang diizinkan
    if (!allowedDomains.contains(domain)) {
      final allowedDomainsStr = allowedDomains.join(', ');
      return 'Email harus menggunakan domain: $allowedDomainsStr';
    }

    return null;
  }
}
