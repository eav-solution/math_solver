import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_solver/src/widgets/markdown_with_math.dart';
import '../controller/home_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(homeControllerProvider);

    ref.listen(homeControllerProvider, (prev, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('AI Math Solver')),
      body: result.when(
        loading:
            () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (err, _) => Center(child: Text(err.toString())),
        data: (solve) {
          if (solve == null) {
            return const Center(child: Text('Press “Upload” to begin'));
          }

          final screenHeight = MediaQuery.of(context).size.height;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Image block (fixed 30 % height) ----
              SizedBox(
                height: screenHeight * 0.30,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(solve.image.path),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              // ---- Scrollable result block ----
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: MarkdownWithMath(data: solve.markdown),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'uploadBtn',
        child: const Icon(Icons.upload_file),
        onPressed: () => _showPickerSheet(context, ref),
      ),
    );
  }

  void _showPickerSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(homeControllerProvider.notifier).takePhoto();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(homeControllerProvider.notifier).pickFromGallery();
                  },
                ),
              ],
            ),
          ),
    );
  }
}
