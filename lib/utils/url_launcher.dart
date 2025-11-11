import 'dart:developer';

import 'package:url_launcher/url_launcher.dart';

Future<void> launch_Url(dynamic url) async {
  final uri = url is Uri ? url : Uri.parse(url.toString());
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    log('Could not launch $uri', name: "launch_Url");
  }
}
