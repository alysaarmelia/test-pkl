import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cipta_vera_mandiri_digital/repositories/news_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/news_section_view_model.dart';

import 'home_theme.dart';

class NewsSection extends StatefulWidget {
  const NewsSection({super.key, this.repository, this.viewModel});

  final NewsRepository? repository;
  final NewsSectionViewModel? viewModel;

  @override
  State<NewsSection> createState() => _NewsSectionState();
}

class _NewsSectionState extends State<NewsSection> {
  late final NewsSectionViewModel _viewModel;
  late final String _viewModelTag;
  late final Future<List<NewsArticle>> _newsFuture;

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'news-section-${identityHashCode(this)}';
    _viewModel = Get.put(
      widget.viewModel ?? NewsSectionViewModel(repository: widget.repository),
      tag: _viewModelTag,
    );
    _newsFuture = _viewModel.loadLatestNews();
  }

  @override
  void dispose() {
    if (Get.isRegistered<NewsSectionViewModel>(tag: _viewModelTag)) {
      Get.delete<NewsSectionViewModel>(tag: _viewModelTag, force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Berita & Artikel Terbaru',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: HomeGlassTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () async {
                final uri = _viewModel.allNewsUri;
                if (!await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                )) {
                  throw Exception('Tidak dapat membuka URL: $uri');
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: HomeGlassTheme.textSecondary,
              ),
              child: const Text('Lihat semua'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<NewsArticle>>(
          future: _newsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (context, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      _NewsSkeletonCard(index: index),
                ),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Gagal memuat berita: ${snapshot.error}',
                    style: const TextStyle(color: HomeGlassTheme.textSecondary),
                  ),
                ),
              );
            }
            final berita = snapshot.data ?? const <NewsArticle>[];
            if (berita.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Tidak ada berita terbaru',
                    style: TextStyle(color: HomeGlassTheme.textSecondary),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(berita.length, (index) {
                  final item = berita[index];
                  return _NewsCard(
                    data: item,
                    resolveOriginalImageUrl: _viewModel.resolveOriginalImageUrl,
                    isFirst: index == 0,
                    isLast: index == berita.length - 1,
                  );
                }),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.data,
    required this.resolveOriginalImageUrl,
    required this.isFirst,
    required this.isLast,
  });

  final NewsArticle data;
  final String Function(String url) resolveOriginalImageUrl;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final imageUrl = data.image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 0, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(19),
            onTap: () async {
              final url = data.link;
              if (url.isEmpty) return;
              final uri = Uri.parse(url);
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                throw Exception('Tidak dapat membuka URL: $url');
              }
            },
            child: Container(
              width: 280,
              height: 170,
              margin: EdgeInsets.only(
                left: isFirst ? 0 : 12,
                right: isLast ? 0 : 0,
              ),
              decoration: BoxDecoration(
                color: HomeGlassTheme.surfaceSoft,
                border: Border.all(color: HomeGlassTheme.surfaceBorder),
                borderRadius: BorderRadius.circular(18),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    if (imageUrl.isNotEmpty)
                      Positioned.fill(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                          // Removed cache constraints to ensure HD quality
                          // cacheWidth: 1200,
                          // cacheHeight: 800,
                          headers: const {
                            'User-Agent':
                                'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                          },
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            final total = progress.expectedTotalBytes;
                            final value = total != null
                                ? progress.cumulativeBytesLoaded / total
                                : null;
                            return Container(
                              color: Colors.grey[200],
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(value: value),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to original URL if upgraded fails
                            final originalUrl = resolveOriginalImageUrl(
                              imageUrl,
                            );
                            if (originalUrl != imageUrl) {
                              return Image.network(
                                originalUrl,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                                gaplessPlayback: true,
                                // Removed cache constraints to ensure HD quality
                                // cacheWidth: 1200,
                                // cacheHeight: 800,
                                headers: const {
                                  'User-Agent':
                                      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: Colors.grey[300],
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                    ),
                              );
                            }
                            return Container(
                              color: Colors.grey[300],
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Positioned.fill(
                        child: Container(
                          color: Colors.grey[300],
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color.fromRGBO(0, 0, 0, 0.72),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black38, blurRadius: 4),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sumber: ${data.source.isNotEmpty ? data.source : 'Banjarmasin Post'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsSkeletonCard extends StatelessWidget {
  const _NewsSkeletonCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final double delay = index * 0.12;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 12),
          child: child,
        ),
      ),
      child: Container(
        width: 250,
        height: 150,
        margin: EdgeInsets.only(left: index == 0 ? 0 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HomeGlassTheme.surfaceBorder),
          color: HomeGlassTheme.surfaceSoft,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: _Shimmer(
                  delay: delay,
                  child: Container(color: Colors.grey[300]),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color.fromRGBO(0, 0, 0, 0.45),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 16,
                        width: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color.fromRGBO(255, 255, 255, 0.25),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 12,
                        width: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color.fromRGBO(255, 255, 255, 0.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child, this.delay = 0});

  final Widget child;
  final double delay;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final slideValue = (_controller.value + widget.delay) % 1.0;
        final gradient = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.grey.shade300,
            Colors.grey.shade100,
            Colors.grey.shade300,
          ],
          stops: const [0.2, 0.5, 0.8],
          transform: _SlidingGradientTransform(slideValue * 2 - 1),
        );
        return ShaderMask(
          shaderCallback: (rect) {
            return gradient.createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slidePercent);

  final double slidePercent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}
