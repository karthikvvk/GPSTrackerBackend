import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSpacing {
  // Spacing values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Edge insets shortcuts
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // Horizontal padding
  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // Vertical padding
  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

/// Border radius constants for consistent rounded corners
class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}

class AppSurfaces {
  static Color translucentPrimary(ColorScheme scheme) {
    return scheme.primary.withValues(alpha: 0.10);
  }
}

// =============================================================================
// TEXT STYLE EXTENSIONS
// =============================================================================

/// Extension to add text style utilities to BuildContext
/// Access via context.textStyles
extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

/// Helper methods for common text style modifications
extension TextStyleExtensions on TextStyle {
  /// Make text bold
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);

  /// Make text semi-bold
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);

  /// Make text medium weight
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);

  /// Make text normal weight
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);

  /// Make text light
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);

  /// Add custom color
  TextStyle withColor(Color color) => copyWith(color: color);

  /// Add custom size
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

// =============================================================================
// COLORS - MOLTEN STEEL THEME
// =============================================================================

/// Light mode colors with border-based design (inspired by Molten Steel)
class LightModeColors {
  // Background - Clean white/light gray
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFF5F5F5);

  // Text colors
  static const lightOnSurface = Color(0xFF1A1A1A);
  static const lightOnSurfaceVariant = Color(0xFF5A5A5A);

  // Primary - Warm gold/yellow (from Molten Steel accent-1)
  static const lightPrimary = Color(0xFFFFD23F);
  static const lightOnPrimary = Color(0xFF000000);
  static const lightPrimaryContainer = Color(0xFFFFF4CC);
  static const lightOnPrimaryContainer = Color(0xFF3D3300);

  // Secondary - Orange (from Molten Steel accent-2)
  static const lightSecondary = Color(0xFFF8961E);
  static const lightOnSecondary = Color(0xFF000000);

  // Tertiary - Red-Orange (from Molten Steel accent-3)
  static const lightTertiary = Color(0xFFF3722C);
  static const lightOnTertiary = Color(0xFFFFFFFF);

  // Borders - Key element of this theme
  static const lightBorder = Color(0xFFE0E0E0);
  static const lightBorderStrong = Color(0xFFBBBBBB);

  // Outline
  static const lightOutline = Color(0xFFBBBBBB);

  // Error colors
  static const lightError = Color(0xFFBA1A1A);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const lightOnErrorContainer = Color(0xFF410002);

  static const lightShadow = Color(0xFF000000);
  static const lightInversePrimary = Color(0xFFFFD23F);
}

/// Dark mode colors - Molten Steel theme with dark background
class DarkModeColors {
  // Background - Dark from Molten Steel (#14141c)
  static const darkBackground = Color.fromARGB(255, 30, 30, 32);
  static const darkSurface = Color.fromARGB(255, 30, 30, 32);
  static const darkSurfaceVariant = Color.fromARGB(255, 30, 30, 32);

  // Text colors - High contrast on dark
  static const darkOnSurface = Color(0xFFE8E8E8);
  static const darkOnSurfaceVariant = Color(0xFFB0B0B0);

  // Primary - Molten Yellow (accent-1: #ffd23f)
  static const darkPrimary = Color.fromARGB(255, 240, 198, 60);
  static const darkOnPrimary = Color(0xFF000000);
  static const darkPrimaryContainer = Color(0xFF5C4900);
  static const darkOnPrimaryContainer = Color(0xFFFFE8A3);

  // Secondary - Molten Orange (accent-2: #f8961e)
  static const darkSecondary = Color(0xFFF8961E);
  static const darkOnSecondary = Color(0xFF000000);

  // Tertiary - Molten Red-Orange (accent-3: #f3722c)
  static const darkTertiary = Color(0xFFF3722C);
  static const darkOnTertiary = Color(0xFF000000);

  // Borders - THE KEY FEATURE matching the screenshot
  static const darkBorder =
      Color(0xFFF8961E); // Orange border like in screenshot
  static const darkBorderSubtle = Color(0xFF3A3A42);

  // Outline
  static const darkOutline = Color(0xFFF8961E);

  // Error colors
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);

  static const darkShadow = Color(0xFF000000);
  static const darkInversePrimary = Color(0xFF5B7C99);
}

/// Font size constants
class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 28.0;
  static const double headlineSmall = 24.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

// =============================================================================
// THEMES
// =============================================================================

/// Light theme with border-based design (no gradients/shadows)
ThemeData get lightTheme => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: LightModeColors.lightPrimary,
        onPrimary: LightModeColors.lightOnPrimary,
        primaryContainer: LightModeColors.lightPrimaryContainer,
        onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
        secondary: LightModeColors.lightSecondary,
        onSecondary: LightModeColors.lightOnSecondary,
        tertiary: LightModeColors.lightTertiary,
        onTertiary: LightModeColors.lightOnTertiary,
        error: LightModeColors.lightError,
        onError: LightModeColors.lightOnError,
        errorContainer: LightModeColors.lightErrorContainer,
        onErrorContainer: LightModeColors.lightOnErrorContainer,
        surface: LightModeColors.lightSurface,
        onSurface: LightModeColors.lightOnSurface,
        surfaceContainerHighest: LightModeColors.lightSurfaceVariant,
        onSurfaceVariant: LightModeColors.lightOnSurfaceVariant,
        outline: LightModeColors.lightOutline,
        shadow: LightModeColors.lightShadow,
        inversePrimary: LightModeColors.lightInversePrimary,
      ),
      brightness: Brightness.light,
      scaffoldBackgroundColor: LightModeColors.lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: LightModeColors.lightOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // Input fields - bordered, no fill
      inputDecorationTheme: InputDecorationTheme(
        filled: false, // No background fill
        fillColor: Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: LightModeColors.lightBorder,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: LightModeColors.lightBorder,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: LightModeColors.lightPrimary,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: LightModeColors.lightError,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: LightModeColors.lightError,
            width: 2.0,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
      ),
      // Buttons - primary uses the molten yellow
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LightModeColors.lightPrimary,
          foregroundColor: LightModeColors.lightOnPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(
            color: LightModeColors.lightBorderStrong,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: LightModeColors.lightPrimaryContainer,
        backgroundColor: LightModeColors.lightSurface,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          _buildTextTheme(Brightness.light).labelMedium,
        ),
      ),
      // Cards - flat with borders (no elevation, no shadow)

      cardTheme: CardThemeData(
        color: AppSurfaces.translucentPrimary(
          const ColorScheme.light(
            primary: LightModeColors.lightPrimary,
          ),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(
            color: LightModeColors.lightBorder,
            width: 1.5,
          ),
        ),
      ),

      // Dialogs - bordered
      dialogTheme: DialogThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(
            color: LightModeColors.lightBorder,
            width: 1.5,
          ),
        ),
      ),
      textTheme: _buildTextTheme(Brightness.light),
    );

/// Dark theme - Molten Steel with prominent orange borders
ThemeData get darkTheme => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: DarkModeColors.darkPrimary,
        onPrimary: DarkModeColors.darkOnPrimary,
        primaryContainer: DarkModeColors.darkPrimaryContainer,
        onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
        secondary: DarkModeColors.darkSecondary,
        onSecondary: DarkModeColors.darkOnSecondary,
        tertiary: DarkModeColors.darkTertiary,
        onTertiary: DarkModeColors.darkOnTertiary,
        error: DarkModeColors.darkError,
        onError: DarkModeColors.darkOnError,
        errorContainer: DarkModeColors.darkErrorContainer,
        onErrorContainer: DarkModeColors.darkOnErrorContainer,
        surface: DarkModeColors.darkSurface,
        onSurface: DarkModeColors.darkOnSurface,
        surfaceContainerHighest: DarkModeColors.darkSurfaceVariant,
        onSurfaceVariant: DarkModeColors.darkOnSurfaceVariant,
        outline: DarkModeColors.darkOutline,
        shadow: DarkModeColors.darkShadow,
        inversePrimary: DarkModeColors.darkInversePrimary,
      ),
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DarkModeColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: DarkModeColors.darkOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // Input fields - orange border like in screenshot
      inputDecorationTheme: InputDecorationTheme(
        filled: false, // No background fill - transparent
        fillColor: Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: DarkModeColors.darkBorder, // Orange border
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: DarkModeColors.darkBorder, // Orange border
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: DarkModeColors.darkPrimary, // Yellow when focused
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: DarkModeColors.darkError,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: DarkModeColors.darkError,
            width: 2.0,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
      ),
      // Buttons - yellow (primary) with black text
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DarkModeColors.darkPrimary, // Yellow
          foregroundColor: DarkModeColors.darkOnPrimary, // Black text
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(
            color: DarkModeColors.darkBorder, // Orange border
            width: 1.5,
          ),
          foregroundColor: DarkModeColors.darkOnSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: DarkModeColors.darkPrimary,
        backgroundColor: DarkModeColors.darkSurface,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          _buildTextTheme(Brightness.dark).labelMedium,
        ),
      ),
      // Cards - flat dark background with orange border (matching screenshot)
      cardTheme: CardThemeData(
        color: DarkModeColors.darkPrimary.withValues(alpha: 0.12),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(
            color: DarkModeColors.darkBorder, // orange outline stays
            width: 1.5,
          ),
        ),
      ),

      // Dialogs - bordered
      dialogTheme: DialogThemeData(
        backgroundColor: DarkModeColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(
            color: DarkModeColors.darkBorder,
            width: 1.5,
          ),
        ),
      ),
      textTheme: _buildTextTheme(Brightness.dark),
    );

/// Build text theme using Inter font family
TextTheme _buildTextTheme(Brightness brightness) {
  return TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w400,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w400,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    ),
  );
}
