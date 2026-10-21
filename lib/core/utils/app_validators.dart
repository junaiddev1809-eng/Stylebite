class AppValidators {
  AppValidators._();

  static String? requiredField(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = requiredField(value, fieldName: 'Email');
    if (requiredError != null) {
      return requiredError;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value!.trim())) {
      return 'Please enter a valid email';
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
