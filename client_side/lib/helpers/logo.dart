import 'package:flutter/material.dart';
import 'package:namer_app/theme/app_colors.dart';

class LiveChatLogo extends StatelessWidget {
  const LiveChatLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppPrimaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppPrimaryColor.withOpacity(0.4),
              width: 2,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.chat_bubble_outline,
              color: AppPrimaryColor,
              size: 50,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
            'LiveChat',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.displayLarge?.color,
            ),
          ),
      ],
    );
  }
}
