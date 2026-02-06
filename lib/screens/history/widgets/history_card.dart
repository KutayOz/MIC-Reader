import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/models.dart';

/// Card widget for displaying an analysis in the history list
class HistoryCard extends StatelessWidget {
  final PlateAnalysis analysis;
  final VoidCallback onTap;
  final VoidCallback? onEditPatientName;

  const HistoryCard({
    super.key,
    required this.analysis,
    required this.onTap,
    this.onEditPatientName,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: _buildThumbnail(),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Organism
                    Text(
                      analysis.organism ?? 'Unknown organism',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Patient name (from notes field)
                    if (analysis.notes != null && analysis.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                analysis.notes!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),

                    // Date
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(analysis.timestamp),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Stats
                    Row(
                      children: [
                        _StatChip(
                          color: AppColors.growth,
                          count: analysis.growthCount,
                          label: 'G',
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          color: AppColors.inhibition,
                          count: analysis.inhibitionCount,
                          label: 'I',
                        ),
                        const SizedBox(width: 8),
                        if (analysis.partialCount > 0)
                          _StatChip(
                            color: AppColors.warning,
                            count: analysis.partialCount,
                            label: 'P',
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action button
              if (onEditPatientName != null)
                IconButton(
                  onPressed: onEditPatientName,
                  icon: const Icon(Icons.edit_outlined),
                  iconSize: 20,
                  color: AppColors.primary,
                  tooltip: 'Edit patient name',
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final file = File(analysis.imagePath);

    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholderThumbnail(),
          );
        }
        return _placeholderThumbnail();
      },
    );
  }

  Widget _placeholderThumbnail() {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Icon(
          Icons.science_outlined,
          color: AppColors.textSecondary,
          size: 32,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final Color color;
  final int count;
  final String label;

  const _StatChip({
    required this.color,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
