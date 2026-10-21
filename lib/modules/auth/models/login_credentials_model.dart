class LoginCredentialsModel {
  const LoginCredentialsModel({
    required this.email,
    required this.password,
    required this.deviceId,
    required this.platform,
    required this.pushToken,
    required this.appVersion,
  });

  final String email;
  final String password;
  final String deviceId;
  final String platform;
  final String pushToken;
  final String appVersion;

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'device_id': deviceId,
      'platform': platform,
      'push_token': pushToken,
      'app_version': appVersion,
    };
  }
}
