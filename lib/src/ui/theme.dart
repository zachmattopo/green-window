import 'package:material_ui/material_ui.dart';

/// Sanzo Wada no. 271 (PRD §16).
const cobalt = Color(0xFF94FF94); // first-screen ground, the window
const slate = Color(0xFF0F261F); // ink, and the ground below the fold
const greenBlue = Color(0xFF2DBC94); // moderate-or-lower bars, placeholders
const purple = Color(0xFFB90078); // dirty bars, "% cleaner", deadline, errors

const condensed = 'Barlow Condensed';
const body = 'Barlow';

/// Narrow screens get the mobile wireframe.
bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < 720;

/// Instant scrolls and charts when the user asks for reduced motion.
Duration motion(BuildContext context, int ms) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);

/// PRD §11: a focus ring keyboard users can see. Purple on the light ground;
/// pass [cobalt] on the dark one, where purple is only 2.5:1.
WidgetStateBorderSide focusRing([Color color = purple]) =>
    WidgetStateBorderSide.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? BorderSide(color: color, width: 3)
          : null,
    );

ThemeData greenWindowTheme() {
  final ring = focusRing();
  const pillText = TextStyle(
    fontFamily: condensed,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
  );
  return ThemeData(
    fontFamily: condensed,
    colorScheme: ColorScheme.fromSeed(
      seedColor: cobalt,
      primary: slate,
      onPrimary: cobalt,
      surface: cobalt,
      onSurface: slate,
      error: purple,
    ),
    scaffoldBackgroundColor: cobalt,
    canvasColor: cobalt, // dropdown menus
    focusColor: slate.withValues(alpha: 0.2),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: slate),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        side: ring,
        backgroundColor: const WidgetStatePropertyAll(slate),
        foregroundColor: const WidgetStatePropertyAll(cobalt),
        textStyle: const WidgetStatePropertyAll(pillText),
        minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 28),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        side: ring,
        foregroundColor: const WidgetStatePropertyAll(slate),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: condensed, fontWeight: FontWeight.w500),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: ButtonStyle(side: ring)),
  );
}
