class AppValidators {
  AppValidators._();

  static String? requiredField(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static const allowedEmailDomains = <String>{
    'gmail.com',
    'googlemail.com',
    'icloud.com',
    'me.com',
    'mac.com',
    // Apple Sign In "Hide My Email"
    'privaterelay.appleid.com',
    'appleid.com',
  };

  static String? email(String? value) {
    final requiredError = requiredField(value, fieldName: 'Email');
    if (requiredError != null) {
      return requiredError;
    }

    final email = value!.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// StyleBite signup is limited to Gmail and iCloud addresses.
  static String? signupEmail(String? value) {
    final basic = AppValidators.email(value);
    if (basic != null) {
      return basic;
    }

    final normalized = value!.trim().toLowerCase();
    final at = normalized.lastIndexOf('@');
    final domain = at >= 0 ? normalized.substring(at + 1) : '';
    if (!allowedEmailDomains.contains(domain)) {
      return 'Use a Gmail or iCloud email to register';
    }
    return null;
  }

  static String? password(String? value) {
    final requiredError = requiredField(value, fieldName: 'Password');
    if (requiredError != null) {
      return requiredError;
    }

    if (value!.trim().length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? confirmPassword({
    required String? value,
    required String originalPassword,
  }) {
    final requiredError = requiredField(value, fieldName: 'Confirm password');
    if (requiredError != null) {
      return requiredError;
    }

    if (value!.trim() != originalPassword.trim()) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? pin(String? value) {
    final requiredError = requiredField(value, fieldName: 'PIN');
    if (requiredError != null) {
      return requiredError;
    }

    final pin = value!.trim();
    if (pin.length != 6 || int.tryParse(pin) == null) {
      return 'Enter a valid 6 digit PIN';
    }
    return null;
  }
}
