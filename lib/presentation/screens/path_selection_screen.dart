import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/app_controller.dart';
import '../models/app_state.dart';

class PathSelectionScreen extends ConsumerWidget {
  const PathSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    final appController = ref.read(appControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.folder,
                size: 80,
                color: Color(0xFF007AFF),
              ),
              const SizedBox(height: 24),
              const Text(
                'CreativeVault',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Discover and manage your creative assets',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6E6E73),
                ),
              ),
              const SizedBox(height: 40),
              if (appState.selectedPath != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Path:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6E6E73),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appState.selectedPath!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (appState.status == AppStatus.scanning) ...[
                  Column(
                    children: [
                      const CupertinoActivityIndicator(),
                      const SizedBox(height: 16),
                      const Text(
                        'Scanning for assets...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6E6E73),
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: appState.scanProgress,
                        backgroundColor: const Color(0xFFE5E5EA),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF007AFF),
                        ),
                      ),
                    ],
                  ),
                ] else if (appState.status == AppStatus.assetsLoaded) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF34C759),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          color: Color(0xFF34C759),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Assets Loaded Successfully!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1D1D1F),
                                ),
                              ),
                              Text(
                                '${appState.assets.length} assets found',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6E6E73),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              if (appState.status != AppStatus.scanning &&
                  appState.status != AppStatus.assetsLoaded) ...[
                const Text(
                  'Select a directory to scan for assets',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6E6E73),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (appState.status == AppStatus.error) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFF3B30),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: Color(0xFFFF3B30),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          appState.errorMessage ?? 'An error occurred',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (appState.selectedPath != null) ...[
                // Show both buttons when there's a cached path
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        onPressed: appState.status == AppStatus.scanning
                            ? null
                            : () => appController.selectPath(),
                        color: const Color(0xFFE5E5EA),
                        child: const Text(
                          'Change Path',
                          style: TextStyle(
                            color: Color(0xFF1D1D1F),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton(
                        onPressed: appState.status == AppStatus.scanning
                            ? null
                            : () => appController.rescanAssets(),
                        color: const Color(0xFF007AFF),
                        child: const Text(
                          'Rescan Assets',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Show single button when no cached path
                CupertinoButton(
                  onPressed: appState.status == AppStatus.scanning
                      ? null
                      : () => appController.selectPath(),
                  color: const Color(0xFF007AFF),
                  child: const Text(
                    'Choose Path',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}