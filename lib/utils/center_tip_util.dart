import 'package:flutter/material.dart';

Future<void> showCenterTip(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    builder: (ctx) {
      Future.delayed(const Duration(seconds: 2), () {
        if (ctx.mounted) Navigator.of(ctx).pop();
      });
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    },
  );
}
