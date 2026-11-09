import 'package:file_picker_web/file_picker_web.dart';

FilePickerWebOptions get browserSaveOptions => FilePickerWebOptions(
  saveMode: supportsShowSaveFileDialog
      ? WebSaveFileMode.dialog
      : WebSaveFileMode.download,
);
