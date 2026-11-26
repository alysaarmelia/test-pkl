import 'dart:ui' show ImageFilter;
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/repositories/media_docs_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/media_docs_view_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaDocsPage extends StatefulWidget {
  final String chatId;
  final MediaDocsRepository? repository;
  final MediaDocsViewModel? viewModel;

  const MediaDocsPage({
    super.key,
    required this.chatId,
    this.repository,
    this.viewModel,
  });

  @override
  State<MediaDocsPage> createState() => _MediaDocsPageState();
}

// Full-screen image preview with pinch-zoom
class ImagePreviewPage extends StatelessWidget {
  const ImagePreviewPage({
    super.key,
    required this.tag,
    required this.imageUrl,
  });

  final String tag;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: tag,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: Image.network(imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaDocsPageState extends State<MediaDocsPage>
    with SingleTickerProviderStateMixin {
  late final MediaDocsViewModel _viewModel;
  late final String _viewModelTag;
  late TabController _tabController;

  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};

  void _enterSelection(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    await _viewModel.deleteMessages(
      chatId: widget.chatId,
      messageIds: _selectedIds.toList(growable: false),
    );
    _clearSelection();
  }

  Future<void> _selectAllCurrentTab() async {
    final ids = await _viewModel.loadIdsForTab(
      chatId: widget.chatId,
      tabIndex: _tabController.index,
    );
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..addAll(ids);
    });
  }

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'media-docs-${identityHashCode(this)}';
    _viewModel = Get.put(
        widget.viewModel ??
            MediaDocsViewModel(
              repository: widget.repository ?? MediaDocsRepositoryImpl(),
            ),
        tag: _viewModelTag,
    );
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    if (Get.isRegistered<MediaDocsViewModel>(tag: _viewModelTag)) {
      Get.delete<MediaDocsViewModel>(tag: _viewModelTag, force: true);
    }
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildGlassAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: Colors.white,
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.16),
                  Colors.white.withOpacity(0.10),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 0.8,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 0),
                  const Center(
                    child: Text(
                      'Media & Dokumen',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 0),
                  TabBar(
                    controller: _tabController,
                    indicator: const UnderlineTabIndicator(
                      borderSide: BorderSide(width: 3.0, color: Colors.white),
                      insets: EdgeInsets.symmetric(horizontal: 24.0),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: 'Media'),
                      Tab(text: 'Dokumen'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: null,
      title: null, // handled in flexibleSpace
      bottom: null, // handled in flexibleSpace
    );
  }

  Widget _buildMediaGrid() {
    return StreamBuilder<List<MediaDocsMessageRecord>>(
      stream: _viewModel.watchMediaMessages(widget.chatId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading media'));
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data ?? const <MediaDocsMessageRecord>[];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No media found',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final item = docs[index];
            final imageUrl = item.imageUrl;
            final docId = item.id;
            final bool selected = _selectedIds.contains(docId);
            return KeyedSubtree(
              key: ValueKey(docId),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onLongPress: () => _enterSelection(docId),
                  onTap: () {
                    if (_selectionMode) {
                      _toggleSelection(docId);
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ImagePreviewPage(tag: item.id, imageUrl: imageUrl),
                      ),
                    );
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: item.id,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                              ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: _selectionMode ? 1 : 0,
                        child: Container(
                          color: selected
                              ? Colors.black.withOpacity(0.35)
                              : Colors.black.withOpacity(0.20),
                        ),
                      ),
                      if (_selectionMode)
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDocsList() {
    return StreamBuilder<List<MediaDocsMessageRecord>>(
      stream: _viewModel.watchFileMessages(widget.chatId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading documents'));
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data ?? const <MediaDocsMessageRecord>[];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No documents found',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final item = docs[index];
            final fileName = item.fileName;
            final fileUrl = item.fileUrl;
            final docId = item.id;
            final bool selected = _selectedIds.contains(docId);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Material(
                  color: selected
                      ? Colors.white.withOpacity(0.22)
                      : Colors.white.withOpacity(0.12),
                  child: InkWell(
                    splashFactory: NoSplash.splashFactory,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    overlayColor: const MaterialStatePropertyAll(
                      Colors.transparent,
                    ),
                    onLongPress: () => _enterSelection(docId),
                    onTap: () async {
                      if (_selectionMode) {
                        _toggleSelection(docId);
                        return;
                      }
                      if (fileUrl.isNotEmpty) {
                        final uri = Uri.tryParse(fileUrl);
                        if (uri != null) {
                          try {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } catch (_) {}
                        }
                      }
                    },
                    child: ListTile(
                      leading: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white.withOpacity(0.18),
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.22),
                                width: selected ? 1.2 : 0.8,
                              ),
                            ),
                            child: const Icon(
                              Icons.insert_drive_file,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                          if (selected)
                            const Positioned(
                              right: -2,
                              top: -2,
                              child: Icon(
                                Icons.check_circle,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: _selectionMode
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.white70,
                            )
                          : const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.white70,
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSelectionBar() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 180),
      offset: _selectionMode ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _selectionMode ? 1 : 0,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedIds.length} dipilih',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Pilih semua',
                      onPressed: _selectAllCurrentTab,
                      icon: const Icon(Icons.select_all, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      onPressed: _deleteSelected,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.redAccent.withOpacity(0.85),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Hapus'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _clearSelection,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Batal'),
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

  @override
  Widget build(BuildContext context) {
    final double statusBarTop = MediaQuery.of(context).padding.top;
    final double appBarContentHeight =
        kToolbarHeight + 30; // matches PreferredSize height
    final double bodyTopPadding = statusBarTop + appBarContentHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 40),
        child: _buildGlassAppBar(),
      ),
      body: HomeGlassTheme.background(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: bodyTopPadding),
                child: Column(
                  children: [
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [_buildMediaGrid(), _buildDocsList()],
                      ),
                    ),
                    const SizedBox(height: 0), // space for bottom glass card
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildSelectionBar(),
            ),
          ],
        ),
      ),
    );
  }
}
