import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

const Color primaryBlue = Color.fromARGB(255, 37, 108, 189);

class AttendanceViewPage extends StatefulWidget {
  final String userId;
  final DateTime month;

  const AttendanceViewPage({
    super.key,
    required this.userId,
    required this.month,
  });

  @override
  State<AttendanceViewPage> createState() => _AttendanceViewPageState();
}

class _AttendanceViewPageState extends State<AttendanceViewPage> {
  bool loading = true;
  List<Map<String, dynamic>> rows = [];

  final ScrollController verticalController = ScrollController();
  final ScrollController horizontalController = ScrollController();

  late DateTime _selectedMonth;
  late DateTime currentMonth;

  @override
  void initState() {
    super.initState();
    currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _selectedMonth = currentMonth;
    fetch();
  }

  @override
  void dispose() {
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  Future<void> fetch() async {
    final formattedMonth = DateFormat('yyyy-MM-01').format(_selectedMonth);

    final url = Uri.parse(
      "http://192.168.20.44:81/api/attendance/get?userId=${widget.userId}&month=$formattedMonth",
    );

    try {
      final res = await http.get(url);
      final data = jsonDecode(res.body);

      final List raw = data['rawAttendance'] ?? [];

      rows = raw.map<Map<String, dynamic>>((e) {
        String formatDate(String? d) {
          if (d == null) return '-';
          final dt = DateTime.tryParse(d);
          if (dt == null) return '-';
          return DateFormat('dd MMM yyyy').format(dt);
        }

        String formatTime(String? d) {
          if (d == null) return '-';
          final clean = d.replaceAll(' T ', 'T');
          final dt = DateTime.tryParse(clean);
          if (dt == null) return '-';
          return DateFormat('hh:mm a').format(dt);
        }

        return {
          'date': formatDate(e['attendanceDate']),
          'status': e['dayStatus'] ?? '-',
          'in': formatTime(e['inDateTime']),
          'out': formatTime(e['outDateTime']),
          'hrs': e['timeHrs'] ?? '-',
        };
      }).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: primaryBlue,
        title: Text(
          "${DateFormat.yMMMM().format(widget.month)} Attendance",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Scrollbar(
                      controller: verticalController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: verticalController,
                        scrollDirection: Axis.vertical,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          child: DataTable(
                            columnSpacing: 28,
                            dataRowHeight: 52,
                            headingRowHeight: 56,
                            headingRowColor: MaterialStateProperty.all(
                              primaryBlue.withOpacity(.08),
                            ),
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('In Time')),
                              DataColumn(label: Text('Out Time')),
                              DataColumn(label: Text('Work Hrs')),
                            ],
                            rows: rows.map((r) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(r['date'].toString())),
                                  DataCell(Text(r['status'].toString())),
                                  DataCell(Text(r['in'].toString())),
                                  DataCell(Text(r['out'].toString())),
                                  DataCell(Text(r['hrs'].toString())),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
