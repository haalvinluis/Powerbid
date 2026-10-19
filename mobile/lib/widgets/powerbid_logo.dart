import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PowerBidLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final bool showSubtitle;

  const PowerBidLogo({
    super.key,
    this.iconSize = 56,
    this.fontSize = 32,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Official PowerBid Brand Logo Image
        Container(
          width: iconSize + 70,
          height: iconSize + 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/powerbid_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Graceful fallback to styled vector emblem
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1E293B),
                        Color(0xFF0F172A),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.silver,
                      width: 2.0,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: iconSize * 0.9,
                        color: AppTheme.electricBlue.withValues(alpha: 0.6),
                      ),
                      Icon(
                        Icons.gavel_rounded,
                        size: iconSize * 0.75,
                        color: AppTheme.gold,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Stylized Brand Typography: "Power" (Gold) + "Bid" (Electric Blue)
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Power',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: AppTheme.gold,
                  shadows: [
                    Shadow(
                      color: AppTheme.gold.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              TextSpan(
                text: 'Bid',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: AppTheme.primary,
                  shadows: [
                    Shadow(
                      color: AppTheme.primary.withValues(alpha: 0.5),
                      blurRadius: 14,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 6),
          const Text(
            'REAL-TIME MULTIPLAYER AUCTION',
            style: TextStyle(
              color: AppTheme.silver,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ],
    );
  }
}
