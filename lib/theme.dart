import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

DefaultStyles archiveDocumentStyles(BuildContext context) => DefaultStyles(
  paragraph: DefaultStyles.getInstance(context).paragraph!
      .copyWith(style: Theme.of(context).textTheme.bodyLarge!),
);

void registerArchiveFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final path in manifest.listAssets().where(
      (path) =>
          path.startsWith('assets/licenses/pdfium/') &&
          !path.endsWith('VERSION'),
    )) {
      yield LicenseEntryWithLineBreaks([
        'PDFium / bundled third-party software',
      ], await rootBundle.loadString(path));
    }
  });
  for (final font in ['NotoSansSC', 'LXGWWenKaiLite']) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        font,
      ], await rootBundle.loadString('assets/fonts/$font-LICENSE.txt'));
    });
  }
}

ThemeData archiveTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'QuietSans',
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      fontFamily: 'QuietDisplay',
      fontSize: 32,
      fontWeight: FontWeight.w400,
      height: 1.3,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'QuietDisplay',
      fontSize: 26,
      fontWeight: FontWeight.w400,
      height: 1.3,
    ),
    titleLarge: TextStyle(
      fontFamily: 'QuietDisplay',
      fontSize: 22,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      fontFamily: 'QuietDisplay',
      fontSize: 18,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.7),
    bodyMedium: TextStyle(fontSize: 14, height: 1.65),
    bodySmall: TextStyle(fontSize: 12, height: 1.5),
    labelLarge: TextStyle(fontSize: 14, letterSpacing: 0),
  ),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff315c56),
    surface: const Color(0xfff7f6f2),
  ),
  scaffoldBackgroundColor: const Color(0xfff7f6f2),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
    ),
  ),
  cardTheme: const CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
    ),
  ),
);
