import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key, required this.appCode});
  final String appCode;

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  final Color primaryBlue = const Color(0xFF1E3A8A);

  List<Map<String, dynamic>> approvals = [];
  bool isLoading = true;

  late int approverCode;

  int getEmpCodeNumber(String empCode) {
    final numeric = empCode.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(numeric) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    approverCode = getEmpCodeNumber(widget.appCode);
    fetchApprovals();
  }

  Future<String> approveLeave({
    required int rowId,
    required int empCode,
    required bool isApproved,
  }) async {
    final url = Uri.parse("http://192.168.20.44:81/api/leave-approval/approve");

    final body = {
      "rowId": rowId,
      "appCode": getEmpCodeNumber(widget.appCode),// approver code
      "empCD": empCode,
      "appRmk": isApproved ? "Approved by App" : "Rejected By App",
      "appDt": DateTime.now().toUtc().toIso8601String(),
      "isApp": isApproved ? "Y" : "N",
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["message"];
    } else {
      throw Exception("Failed to process approval");
    }
  }

  /// FETCH DATA FROM API
  Future<void> fetchApprovals() async {
    try {
      final approverCode = getEmpCodeNumber(widget.appCode);
      final response = await http.get(
        Uri.parse(
          "http://192.168.20.44:81/api/leave-approval/list?approverCode=$approverCode",
        ),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        setState(() {
          approvals = data.map((e) {
            final from = DateTime.parse(e["dtFrom"]);
            final to = DateTime.parse(e["dtTo"]);
            return {
              "rowId": e["leaveSn"], // important for approve API
              "empCode": int.parse(e["empCode"].toString()),
              "empName": e["empName"],
              "leaveType": e["shcName"],
              "appliedDate": DateFormat(
                "dd-MM-yyyy",
              ).format(DateTime.parse(e["crDate"])),
              "fromDate": DateFormat("dd-MM-yyyy").format(from),
              "toDate": DateFormat("dd-MM-yyyy").format(to),
              "days": to.difference(from).inDays + 1,
            };
          }).toList();

          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  /// SINGLE ACTION
  Future<void> handleAction(int index, bool isAccepted) async {
    final item = approvals[index];

    try {
      final message = await approveLeave(
        rowId: item["rowId"],
        empCode: item["empCode"],
        isApproved: isAccepted,
      );

      setState(() {
        approvals.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isAccepted
              ? Colors.green.shade600
              : Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// ACCEPT / REJECT ALL
  Future<void> handleAll(bool isAccepted) async {
    if (approvals.isEmpty) return;

    try {
      for (final item in approvals) {
        await approveLeave(
          rowId: item["rowId"],
          empCode: item["empCode"],
          isApproved: isAccepted,
        );
      }

      setState(() {
        approvals.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAccepted
                ? "All requests accepted successfully"
                : "All requests rejected successfully",
          ),
          backgroundColor: isAccepted
              ? Colors.green.shade600
              : Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error processing approvals: ${e.toString()}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text(
          "Leave Approvals",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryBlue,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == "accept") {
                handleAll(true);
              } else {
                handleAll(false);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: "accept", child: Text("Accept All")),
              const PopupMenuItem(value: "reject", child: Text("Reject All")),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : approvals.isEmpty
          ? Center(
              child: Text(
                "No Pending Approvals",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: approvals.length,
              itemBuilder: (context, index) {
                final item = approvals[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// HEADER
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item["empName"],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item["leaveType"],
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        Text(
                          "Emp Code: ${item["empCode"]}",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),

                        const Divider(height: 24),

                        _infoRow("Applied On", item["appliedDate"].toString()),
                        _infoRow("From", item["fromDate"].toString()),
                        _infoRow("To", item["toDate"].toString()),
                        _infoRow("No. of Days", item["days"].toString()),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => handleAction(index, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "Accept",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => handleAction(index, false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "Reject",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
