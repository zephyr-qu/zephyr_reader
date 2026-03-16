import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.size = 40.0, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child:
              // Lottie.asset(Assets.json.lottieCta)
              Text(
                '加载中...',
                style: TextStyle(
                  fontSize: size * 0.5,
                  color: color ?? Theme.of(context).primaryColor,
                ),
              ),
        ),
      ),
    );
  }
}
