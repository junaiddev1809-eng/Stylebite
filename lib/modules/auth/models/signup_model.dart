class SignUpModel {
  const SignUpModel({
    required this.name,
    required this.username,
    required this.email,
    required this.password,
    required this.passwordConfirmation,
    required this.deviceId,
    required this.platform,
    required this.pushToken,
    required this.appVersion,
  });

  final String name;
  final String username;
  final String email;
  final String password;
  final String passwordConfirmation;
  final String deviceId;
  final String platform;
  final String pushToken;
  final String appVersion;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'username': username,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'device_id': deviceId,
      'platform': platform,
      'push_token': pushToken,
      'app_version': appVersion,
    };
  }
}
