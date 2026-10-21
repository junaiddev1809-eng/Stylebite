import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../utils/app_back_navigation.dart';
import 'app_hero_icon.dart';

class AppWebView extends StatefulWidget {
  final String title;
  final String url;

  const AppWebView({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<AppWebView> createState() => _AppWebViewState();
}

class _AppWebViewState extends State<AppWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: AppBackNavigation.handleBack,
                  borderRadius: BorderRadius.circular(999),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: AppHeroIconData(
                      Icons.arrow_back_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      widget.title,
                      style: AppFonts.plusJakarta(
                        size: 18,
                        weight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}
