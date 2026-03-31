// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void openPdfInBrowser(List<int> bytes, String fileName) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('target', '_blank')
    ..click();

  html.Url.revokeObjectUrl(url);
}