import 'package:flutter/material.dart';

class AppTheme {
  // ── Palette extraite de l'image ────────────────────────────────────────────
  static const skyTop    = Color(0xFF0D1B4B); // bleu nuit foncé (haut)
  static const skyMid    = Color(0xFF1A3A7A); // bleu marine (milieu)
  static const skyBottom = Color(0xFF3A7BD5); // bleu ciel (bas)
  static const skyLight  = Color(0xFF5A9BE0); // bleu clair (accent)

  // Palette officielle conservée
  static const c1 = Color(0xFFE0E2E8); // textes
  static const c2 = Color(0xFFB0C0D4); // sous-titres
  static const c3 = Color(0xFF5DA5B3); // accent vert-bleu
  static const c4 = Color(0xFF394054); // bleu marine
  static const c5 = Color(0xFF1C1C1F); // noir

  // Alias
  static const accent    = skyBottom;
  static const accentAlt = skyLight;
  static const textPrimary = c1;
  static const textSub     = c2;
  static const textHint    = Color(0x88B0C0D4);

  // ── DARK — bleu nuit profond ───────────────────────────────────────────────
  static const darkBg      = Color(0xFF0A1535); // plus foncé que skyTop
  static const darkSurface = Color(0xFF0F1E4A); // skyTop
  static const darkCard    = Color(0xFF152258); // légèrement plus clair
  static const darkTopbar  = Color(0xFF080F2A); // très foncé
  static const darkSidebar = Color(0xFF060D22); // le plus foncé

  // ── LIGHT — bleu ciel lumineux ─────────────────────────────────────────────
  static const lightBg      = Color(0xFF1A3A7A); // skyMid
  static const lightSurface = Color(0xFF1F4490); // légèrement plus clair
  static const lightCard    = Color(0xFF254EA8); // card
  static const lightTopbar  = Color(0xFF142E62); // topbar foncé
  static const lightSidebar = Color(0xFF102850); // sidebar

  static ThemeData dark() => _build(
        bg: darkBg, surface: darkSurface,
        card: darkCard, appBarBg: darkTopbar,
        brightness: Brightness.dark,
      );

  static ThemeData light() => _build(
        bg: const Color(0xFF0A1535), surface: darkSurface,
        card: darkCard, appBarBg: darkTopbar,
        brightness: Brightness.light,
      );

  static ThemeData _build({
    required Color bg, required Color surface,
    required Color card, required Color appBarBg,
    required Brightness brightness,
  }) =>
      ThemeData(
        brightness: brightness,
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: skyBottom,
          brightness: brightness,
          surface: surface,
          primary: skyBottom,
          secondary: skyLight,
          onPrimary: c1,
          onSurface: c1,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: card,
        appBarTheme: AppBarTheme(
          backgroundColor: appBarBg,
          foregroundColor: c1,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: c1),
          titleTextStyle: const TextStyle(
              color: c1, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        dialogBackgroundColor: card,
        dividerColor: c2.withOpacity(0.2),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface.withOpacity(0.6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: c2.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: c2.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: skyLight, width: 2),
          ),
          labelStyle: const TextStyle(color: c2),
          hintStyle: TextStyle(color: c2.withOpacity(0.5)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: skyBottom,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: skyLight,
            side: const BorderSide(color: skyTop, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: skyLight,
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? skyBottom : c2),
          trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? skyBottom.withOpacity(0.4)
                  : c2.withOpacity(0.25)),
        ),
        iconTheme: const IconThemeData(color: c1),
        textTheme: const TextTheme(
          bodyLarge:     TextStyle(color: c1),
          bodyMedium:    TextStyle(color: c1),
          bodySmall:     TextStyle(color: c2),
          titleLarge:    TextStyle(color: c1, fontWeight: FontWeight.bold),
          titleMedium:   TextStyle(color: c1),
          headlineLarge: TextStyle(color: c1, fontWeight: FontWeight.bold),
          labelSmall:    TextStyle(color: c2),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: card,
          labelStyle: const TextStyle(color: c2, fontSize: 11),
          side: BorderSide(color: c2.withOpacity(0.25)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: card,
          contentTextStyle: const TextStyle(color: c1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: skyBottom),
      );

  // ── Helpers ────────────────────────────────────────────────────────────────
  static Color bg(bool isDark)             => isDark ? darkBg      : lightBg;
  static Color surface(bool isDark)        => isDark ? darkSurface : lightSurface;
  static Color card(bool isDark)           => isDark ? darkCard    : lightCard;
  static Color topbar(bool isDark)         => isDark ? darkTopbar  : lightTopbar;
  static Color sidebar(bool isDark)        => isDark ? darkSidebar : lightSidebar;
  static Color text(bool isDark)           => c1;
  static Color textSubColor(bool isDark)   => c2;
  static Color primary(bool isDark)        => skyBottom;
  static Color sidebarSelected(bool isDark) => skyBottom.withOpacity(0.3);
  static Color sidebarDivider(bool isDark)  => skyTop.withOpacity(0.4);
  static Color border(bool isDark)          => skyTop.withOpacity(0.5);

  // Couleur bouton bleu foncé (déconnexion, confirmer, lancer diag, envoyer cmds, télécharger)
  static const btnDark = Color(0xFF0D1B4B); // skyTop = bleu nuit
  // Couleur bouton "Terminer" = bleu description
  static const btnTerminer = Color(0xFF1A3A7A); // skyMid

  // Bleu transparent pour les cartes de l'app
  static BoxDecoration cardBlue({double radius = 16}) => BoxDecoration(
    color: const Color(0xFF1A3A7A).withOpacity(0.45),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: skyBottom.withOpacity(0.35), width: 1.2),
  );

  // Transparent clair pour la carte login
  static BoxDecoration loginCard({double radius = 24}) => BoxDecoration(
    color: Colors.white.withOpacity(0.12),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: skyBottom.withOpacity(0.35), width: 1.5),
  );

  // Style card uniforme (style EasyTraceVII)
  static BoxDecoration cardDecoration({double radius = 14}) => BoxDecoration(
    color: darkCard.withOpacity(0.75),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: skyTop.withOpacity(0.5), width: 1.2),
  );

  // Style container section
  static BoxDecoration sectionDecoration({double radius = 16}) => BoxDecoration(
    color: darkSurface.withOpacity(0.6),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: skyTop.withOpacity(0.4), width: 1),
  );

  // Dégradé de l'image — utilisable partout
  static const gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skyTop, skyMid, skyBottom],
    stops: [0.0, 0.5, 1.0],
  );
}
