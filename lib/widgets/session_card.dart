import 'package:cps_dragonfly_4_mobile_app/widgets/styled_card.dart';
import 'package:flutter/material.dart';

class SessionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String details;
  final List<Widget> actions;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final List<Widget> children;

  const SessionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.actions,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleExpand,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[600],
                    ),
                    ...actions,
                  ],
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const Divider(),
            ...children,
          ],
        ],
      ),
    );
  }
}