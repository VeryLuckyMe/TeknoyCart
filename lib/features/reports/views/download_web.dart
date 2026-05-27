import 'dart:html' as html;

/// Web implementation of file download using dart:html.
void downloadCsvWeb(String csvContent, String filename) {
  final bytes = Uri.encodeComponent(csvContent);
  html.AnchorElement(href: 'data:text/csv;charset=utf-8,$bytes')
    ..setAttribute('download', filename)
    ..click();
}
