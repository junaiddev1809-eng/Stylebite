import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:stylebite/core/theme/app_colors.dart';

void successSnackBar({required String message}) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.TOP,
    backgroundColor: AppColors.success,
    textColor: Colors.white,
    fontSize: 16.0,
  );
}

void errorSnackBar({required String message}) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.TOP,
    backgroundColor: AppColors.error,
    textColor: Colors.white,
    fontSize: 16.0,
  );
}

void infoSnackBar({required String message}) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.TOP,
    backgroundColor: Colors.black,
    textColor: Colors.white,
    fontSize: 16.0,
  );
}
