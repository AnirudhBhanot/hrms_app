import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class LeaveService {
  static const String baseUrl = "http://192.168.20.44:81/api/attendance/";

  static Future<Map<String, String>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();

    String deviceName = "Unknown";
    String deviceHost = "Unknown";

    try {
      if (kIsWeb) {
        // ✅ WEB SAFE
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceName = webInfo.browserName.name;
        deviceHost = "Web";
      } else {
        // ✅ MOBILE / DESKTOP
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = androidInfo.model;
        deviceHost = androidInfo.id ;
      }
    } catch (e) {
      deviceName = "Unknown Device";
      deviceHost = "Unknown Host";
    }

    return {"deviceName": deviceName, "deviceHost": deviceHost};
  }

  static Future<String> applyLeave({
    required int userId,
    required DateTime fromDate,
    required DateTime toDate,
    required String leaveType,
    required bool isHalfDay,
    required String halfDayType,
    required String remarks,
  }) async {
    final deviceData = await getDeviceInfo(); // ✅ STEP 1
    final body = {
      "userId": userId.toString(),
      "fromDate": fromDate.toIso8601String().split('T').first,
      "toDate": toDate.toIso8601String().split('T').first,
      "leaveType": leaveType,
      "halfDayFlag": isHalfDay ? "Y" : "N",
      "halfSession": isHalfDay ? (halfDayType == "First Half" ? 1 : 2) : 0,
      "remarks": remarks,
      // ✅ ADD THESE
      "deviceName": deviceData["deviceName"],
      "deviceHost": deviceData["deviceHost"],
    };

    final response = await http.post(
      Uri.parse("${baseUrl}apply"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");

    /// 🔥 HANDLE EMPTY BODY SAFELY
    final bodyText = response.body.trim();

    /// ✅ HANDLE EMPTY RESPONSE
    if (bodyText.isEmpty) {
      if (response.statusCode == 200) {
        return "Leave applied successfully";
      } else {
        throw "Empty response from server";
      }
    }

    /// ✅ SAFE JSON PARSE
    dynamic decoded;
    try {
      decoded = jsonDecode(bodyText);
    } catch (e) {
      throw "Invalid response from server";
    }

    /// ✅ SUCCESS CASE
    if (response.statusCode == 200) {
      return decoded["message"]?.toString() ?? "Leave applied successfully";
    }

    /// ✅ ERROR CASE
    if (response.statusCode == 400) {
      return decoded["message"]?.toString() ?? "Bad request";
    }

    throw decoded["message"]?.toString() ?? "Something went wrong";
  }

  static Future<String> applyCardError({
    required int userId,
    required DateTime date,
    required TimeOfDay time,
    required String type,
  }) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final formattedTime =
        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

    final response = await http.post(
      Uri.parse("$baseUrl/applyCardError"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": userId,
        "date": formattedDate,
        "time": formattedTime,
        "type": type,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) throw Exception(data["message"]);
    return data["message"];
  }

  static Future<String> applyOSD({
    required int userId,
    required DateTime fromDate,
    required DateTime toDate,
    required TimeOfDay fromTime,
    required TimeOfDay toTime,
    required String reason,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/applyOSD"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": userId,
        "fromDate": DateFormat('yyyy-MM-dd').format(fromDate),
        "toDate": DateFormat('yyyy-MM-dd').format(toDate),
        "fromTime": "${fromTime.hour}:${fromTime.minute}",
        "toTime": "${toTime.hour}:${toTime.minute}",
        "reason": reason,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) throw Exception(data["message"]);
    return data["message"];
  }
}
