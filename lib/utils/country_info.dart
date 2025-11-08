import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:Bloomee/routes_and_consts/global_str_consts.dart';
import 'package:Bloomee/services/db/bloomee_db_service.dart';
import 'package:http/http.dart';

Future<String> getCountry() async {
  String localeFallback() {
    try {
      final loc = Platform.localeName; // e.g., de_DE or de-DE
      final parts = loc.split(RegExp(r'[_-]'));
      if (parts.isNotEmpty) {
        final code = parts.last.toUpperCase();
        if (code.length == 2) return code;
      }
    } catch (_) {}
    return "US"; // neutral default
  }

  String countryCode = localeFallback();
  await BloomeeDBService.getSettingBool(GlobalStrConsts.autoGetCountry)
      .then((value) async {
    if (value != null && value == true) {
      try {
        final response = await get(Uri.parse('https://ipapi.co/json/'));
        if (response.statusCode == 200) {
          Map data = jsonDecode(utf8.decode(response.bodyBytes));
          countryCode = (data['country_code'] ?? data['countryCode'] ?? countryCode).toString();
          await BloomeeDBService.putSettingStr(
              GlobalStrConsts.countryCode, countryCode);
        }
      } catch (err) {
        await BloomeeDBService.getSettingStr(GlobalStrConsts.countryCode)
            .then((value) {
          if (value != null) {
            countryCode = value;
          } else {
            countryCode = localeFallback();
          }
        });
      }
    } else {
      await BloomeeDBService.getSettingStr(GlobalStrConsts.countryCode)
          .then((value) {
        if (value != null) {
          countryCode = value;
        } else {
          countryCode = localeFallback();
        }
      });
    }
  });
  log("Country Code: $countryCode");
  return countryCode;
}
