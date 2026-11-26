import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const GreenWindowApp());
}

class GreenWindowApp extends StatelessWidget {
  const GreenWindowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Green Window',
      home: Scaffold(body: Center(child: Text('Green Window'))),
    );
  }
}
