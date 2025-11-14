import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({Key? key}) : super(key: key);

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();

    _scrollController.addListener(() {
      if (_scrollController.offset > 100 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 100 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildHeroSection(),
                    _buildFeaturesSection(),
                    _buildAppPreviewSection(),
                    _buildDownloadSection(),
                    _buildFooter(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: _isScrolled
          ? const Color(0xFF0A0A0A).withOpacity(0.95)
          : const Color(0xFF0A0A0A).withOpacity(0.8),
      elevation: 0,
      toolbarHeight: 80,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
          ),
        ),
      ),
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 40, height: 40),
          const SizedBox(width: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ).createShader(bounds),
            child: Text(
              'Tapsakay',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      actions: isMobile
          ? [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => _showMobileMenu(),
              ),
            ]
          : [
              _buildNavLink('Features', () {}),
              _buildNavLink('About', () {}),
              _buildNavLink('Download', () {}),
              const SizedBox(width: 16),
              _buildCTAButton(),
              const SizedBox(width: 24),
            ],
    );
  }

  Widget _buildNavLink(String text, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildCTAButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: Text(
          'Get Started',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        height: size.height - 80,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : size.width * 0.05,
        ),
        child: Stack(
          children: [
            // Animated Background
            Positioned.fill(
              child: CustomPaint(painter: GradientCirclesPainter()),
            ),
            // Content
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Your Journey, Simplified',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 40 : 72,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [Colors.white, Color(0xFF667EEA)],
                          ).createShader(const Rect.fromLTWH(0, 0, 400, 100)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Experience seamless navigation and location-based services with Tapsakay. Your trusted companion for every trip.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 16 : 20,
                        color: const Color(0xFFB0B0B0),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildPrimaryButton('Download Now', () {}),
                        _buildSecondaryButton('Learn More', () {}),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String text, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        side: const BorderSide(color: Color(0xFF667EEA), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF667EEA),
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : size.width * 0.05,
        vertical: 120,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E)],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Powerful Features',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 32 : 56,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Everything you need for a perfect journey',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: const Color(0xFFB0B0B0),
            ),
          ),
          const SizedBox(height: 64),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 900
                    ? 3
                    : constraints.maxWidth > 600
                    ? 2
                    : 1;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: 1.1,
                  children: [
                    _buildFeatureCard(
                      '📍',
                      'Live Tracking',
                      'Track your location in real-time with precision GPS technology and get accurate navigation assistance.',
                    ),
                    _buildFeatureCard(
                      '🗺️',
                      'Smart Maps',
                      'Beautiful, interactive maps with multiple layers and offline support for uninterrupted service.',
                    ),
                    _buildFeatureCard(
                      '📊',
                      'Analytics',
                      'Detailed insights and statistics about your trips, routes, and travel patterns.',
                    ),
                    _buildFeatureCard(
                      '🔒',
                      'Secure',
                      'Your data is protected with enterprise-grade encryption and security measures.',
                    ),
                    _buildFeatureCard(
                      '⚡',
                      'Fast & Reliable',
                      'Lightning-fast performance with optimized caching for smooth user experience.',
                    ),
                    _buildFeatureCard(
                      '🌐',
                      'Always Connected',
                      'Smart connectivity features that work even with limited internet access.',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String emoji, String title, String description) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFFB0B0B0),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppPreviewSection() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : size.width * 0.05,
        vertical: 120,
      ),
      color: const Color(0xFF0A0A0A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: isMobile
            ? Column(
                children: [
                  _buildPreviewText(isMobile),
                  const SizedBox(height: 64),
                  _buildPhoneMockup(),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _buildPreviewText(isMobile)),
                  const SizedBox(width: 64),
                  Expanded(child: _buildPhoneMockup()),
                ],
              ),
      ),
    );
  }

  Widget _buildPreviewText(bool isMobile) {
    return Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          'Designed for Your Lifestyle',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: GoogleFonts.poppins(
            fontSize: isMobile ? 32 : 48,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Tapsakay brings together powerful location services, intuitive design, and smart features in one beautiful app. Whether you\'re commuting, exploring, or planning your next adventure, we\'ve got you covered.',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: const Color(0xFFB0B0B0),
            height: 1.8,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Built with cutting-edge technology including Flutter, Google Maps integration, and real-time data synchronization powered by Supabase.',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: const Color(0xFFB0B0B0),
            height: 1.8,
          ),
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton('Explore Features', () {}),
      ],
    );
  }

  Widget _buildPhoneMockup() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 3),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -20 * (0.5 - (value % 1.0 - 0.5).abs())),
          child: child,
        );
      },
      child: Center(
        child: Container(
          width: 300,
          height: 550,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: const Color(0xFF2A2A2A), width: 8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 80,
                offset: const Offset(0, 30),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Center(
              child: Image.asset(
                'assets/images/logo.png',
                width: 80,
                height: 80,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadSection() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : size.width * 0.05,
        vertical: 120,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Ready to Get Started?',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 32 : 56,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Download Tapsakay now and transform the way you navigate',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildStoreButton('📱', 'Download on', 'App Store', () {}),
              _buildStoreButton('🤖', 'Get it on', 'Google Play', () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreButton(
    String emoji,
    String subtitle,
    String title,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : size.width * 0.05),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFooterSection(
                        'Tapsakay',
                        'Your trusted companion for every journey. Navigate smarter, travel better.',
                      ),
                      const SizedBox(height: 32),
                      _buildFooterLinks('Product', [
                        'Features',
                        'About',
                        'Download',
                        'Pricing',
                      ]),
                      const SizedBox(height: 32),
                      _buildFooterLinks('Company', [
                        'About Us',
                        'Careers',
                        'Blog',
                        'Contact',
                      ]),
                      const SizedBox(height: 32),
                      _buildFooterLinks('Support', [
                        'Help Center',
                        'Privacy Policy',
                        'Terms',
                        'FAQ',
                      ]),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildFooterSection(
                          'Tapsakay',
                          'Your trusted companion for every journey. Navigate smarter, travel better.',
                        ),
                      ),
                      Expanded(
                        child: _buildFooterLinks('Product', [
                          'Features',
                          'About',
                          'Download',
                          'Pricing',
                        ]),
                      ),
                      Expanded(
                        child: _buildFooterLinks('Company', [
                          'About Us',
                          'Careers',
                          'Blog',
                          'Contact',
                        ]),
                      ),
                      Expanded(
                        child: _buildFooterLinks('Support', [
                          'Help Center',
                          'Privacy Policy',
                          'Terms',
                          'FAQ',
                        ]),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.only(top: 32),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
              ),
            ),
            child: Text(
              '© 2024 Tapsakay. All rights reserved.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFFB0B0B0),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSection(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          description,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFFB0B0B0),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLinks(String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...links.map(
          (link) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {},
              child: Text(
                link,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFFB0B0B0),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMobileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Features',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: Text(
                'About',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: Text(
                'Download',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: _buildCTAButton()),
          ],
        ),
      ),
    );
  }
}

class GradientCirclesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF667EEA).withOpacity(0.2),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.2, size.height * 0.5),
              radius: size.width * 0.3,
            ),
          );

    final paint2 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF764BA2).withOpacity(0.2),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.8, size.height * 0.8),
              radius: size.width * 0.3,
            ),
          );

    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.5),
      size.width * 0.3,
      paint1,
    );
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.8),
      size.width * 0.3,
      paint2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
