class ResetPasswordModel {
  const ResetPasswordModel({
    required this.email,
    required this.code,
    required this.password,
    required this.passwordConfirmation,
  });

  final String email;
  final String code;
  final String password;
  final String passwordConfirmation;

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'code': code,
      'password': password,
      'password_confirmation': passwordConfirmation,
    };
  }
}
