import 'dart:ui';

import 'package:flutter/material.dart';

const List<Color> _backgroundGradient = <Color>[
  Color(0xFF101529),
  Color(0xFF1C2844),
];
const Color _surfaceSoft = Color.fromRGBO(255, 255, 255, 0.12);
const Color _surfaceBorder = Color.fromRGBO(255, 255, 255, 0.35);

class ArchivedChatsPage extends StatelessWidget {
  const ArchivedChatsPage({
    super.key,
    required this.archivedChats,
    required this.chatTileBuilder,
  });

  final List<Map<String, dynamic>> archivedChats;
  final Widget Function(BuildContext, Map<String, dynamic>) chatTileBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 63,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Chat Diarsipkan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: _surfaceSoft,
                border: Border(
                  bottom: BorderSide(
                    color: Color.fromRGBO(255, 255, 255, 0.25),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: _backgroundGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: archivedChats.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada chat di arsip',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
                  itemBuilder: (context, index) =>
                      chatTileBuilder(context, archivedChats[index]),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: archivedChats.length,
                ),
        ),
      ),
    );
  }
}
