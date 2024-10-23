import 'package:flutter/material.dart';

class ExportToCsvButton extends StatelessWidget {
  const ExportToCsvButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: (){},
      child: const Text("Export to CSV"),
    );
  }
}