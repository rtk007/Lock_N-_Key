import 'package:flutter/material.dart';
import 'package:lock_n_key/routes.dart';
import 'dart:async';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Welcome to Lock N\' Key',
      'description': 'Your ultimate personal security vault. Secure, fast, and always accessible.',
      'icon': Icons.lock_outline,
      'image': 'assets/images/tutorial_welcome.png', 
    },
    {
      'title': 'Secure Storage',
      'description': 'All your secrets are encrypted using AES-256 bit encryption. Only you hold the key.',
      'icon': Icons.security,
      'image': 'assets/images/tutorial_secure.png',
    },
    {
      'title': 'Biometric Access',
      'description': 'Unlock your vault instantly with Windows Hello using your fingerprint or face ID.',
      'icon': Icons.fingerprint,
      'image': 'assets/images/tutorial_biometric.png',
    },
    {
      'title': 'Quick Access',
      'description': 'Press Alt + Space anywhere on your computer to search and auto-paste your secrets without opening the app.',
      'icon': Icons.keyboard,
      'image': 'assets/images/tutorial_quick_access.png', 
    },
    {
      'title': 'Save Tokens with Extension',
      'description': 'Use the browser extension to securely SAVEselected text (like API keys or tokens) to your vault. \n\nNOTE: This extension is for SAVING secrets, NOT for auto-filling passwords.',
      'icon': Icons.extension,
      'image': 'assets/images/tutorial_extension.png',
    },
    {
      'title': 'Cross-Device Restoration',
      'description': 'Use our "Clipboard-free Unique File Import" to securely restore your secrets across devices using a generated backup file. No cloud required.',
      'icon': Icons.import_export,
      'image': 'assets/images/tutorial_restore.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentPage < _slides.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        _stopAutoScroll(); // Stop at the end
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _onNext() {
    _stopAutoScroll(); // User interaction stops auto-scroll
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishParams();
    }
  }

  void _onBack() {
    _stopAutoScroll(); // User interaction stops auto-scroll
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishParams() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.dashboard,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip Button
            Padding(
              padding: const EdgeInsets.only(top: 16.0, right: 16.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finishParams,
                  child: const Text('Skip'),
                ),
              ),
            ),
            
            // Main Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  final hasImage = slide['image'] != null;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasImage)
                           Expanded(
                             child: Container(
                               margin: const EdgeInsets.symmetric(vertical: 20),
                               decoration: BoxDecoration(
                                 border: Border.all(color: Colors.grey.shade300),
                                 borderRadius: BorderRadius.circular(12),
                                 boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
                               ),
                               child: ClipRRect(
                                 borderRadius: BorderRadius.circular(12),
                                 child: Image.asset(
                                   slide['image'], 
                                   fit: BoxFit.contain,
                                   errorBuilder: (context, error, stackTrace) {
                                     return Center(
                                       child: Icon(
                                         slide['icon'],
                                         size: 80,
                                         color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                       ),
                                     );
                                   },
                                 ),
                               ),
                             ),
                           )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Icon(
                              slide['icon'],
                              size: 100,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        
                        Text(
                          slide['title'],
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide['description'],
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Controls
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      if (_currentPage > 0)
                        TextButton(
                          onPressed: _onBack,
                          child: const Text('Back'),
                        )
                      else
                        const SizedBox(width: 64), 

                      FilledButton(
                        onPressed: _onNext,
                        child: Text(_currentPage == _slides.length - 1 ? 'Get Started' : 'Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
