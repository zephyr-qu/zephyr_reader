import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:zephyr_reader/gen/assets.gen.dart';

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
        child: Center(child: Lottie.asset(Assets.json.lottieCta)),
      ),
    );
  }
}
