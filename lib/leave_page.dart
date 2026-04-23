import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hrms_app/attendance_view_page.dart';
import 'package:hrms_app/leave_service.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// 🎨 COLORS
const Color primaryBlue = Color.fromARGB(255, 37, 108, 189);
const Color presentGreen = Color(0xFF2ECC71);
const Color absentRed = Color(0xFFE74C3C);
const Color restGrey = Colors.grey;
const Color holidayPurple = Color(0xFF9B59B6);
const Color leaveOrange = Color(0xFFF39C12);
const Color osdBlue = Color(0xFF3498DB);
const Color halfDayYellow = Color.fromARGB(255, 94, 86, 41); // light yellow
const Color dHalfGrey = Color.fromARGB(255, 204, 158, 158); // light grey (D1/2)

class LeavePage extends StatefulWidget {
  final String empCode;
  const LeavePage({super.key, required this.empCode});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  /// ⭐ START WITH API MONTH

  /// 🔹 API DATA
  Map<int, CalendarDayAttendance> dayStatus = {};

  double totalCL = 0;
  double totalEL = 0;

  double totalPresent = 0;
  double totalAbsent = 0;
  double totalRest = 0;
  double totalHoliday = 0;
  double totalLeave = 0;
  double totalOSD = 0;
  double totalhalf = 0;
  double total2half = 0;

  String recommenderName = '';
  String approverName = '';

  late DateTime _selectedMonth;
  late DateTime currentMonth;
  late DateTime minAllowedMonth;

  bool isLoading = true;

  final List<String> weekDays = const [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  BoxDecoration getTileDecoration(CalendarDayAttendance? attendance) {
    if (attendance == null) {
      return BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      );
    }

    switch (attendance.status) {
      /// ✅ HALF DAY: PRESENT + ABSENT (TIME BASED)
      case 'HD':
        final isAbsentFirst = attendance.halfOrder == 'A-P';

        return BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isAbsentFirst
                ? [absentRed, presentGreen] // A → P
                : [presentGreen, absentRed], // P → A
          ),
        );

      /// ✅ LEAVE FIRST HALF
      case 'L/1':
        return BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [leaveOrange, presentGreen],
          ),
        );

      /// ✅ LEAVE SECOND HALF
      case 'L/2':
        return BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [presentGreen, leaveOrange],
          ),
        );

      /// ✅ FULL DAY STATES
      case 'P':
        return BoxDecoration(
          color: presentGreen,
          borderRadius: BorderRadius.circular(12),
        );
      case 'A':
        return BoxDecoration(
          color: absentRed,
          borderRadius: BorderRadius.circular(12),
        );
      case 'R':
        return BoxDecoration(
          color: restGrey,
          borderRadius: BorderRadius.circular(12),
        );
      case 'N':
        return BoxDecoration(
          color: holidayPurple,
          borderRadius: BorderRadius.circular(12),
        );
      case 'O':
        return BoxDecoration(
          color: osdBlue,
          borderRadius: BorderRadius.circular(12),
        );
      case 'L':
        return BoxDecoration(
          color: leaveOrange,
          borderRadius: BorderRadius.circular(12),
        );

      case 'D/1':
        return BoxDecoration(
          color: dHalfGrey,
          borderRadius: BorderRadius.circular(12),
        );

      default:
        return BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        );
    }
  }

  void processAttendanceForCalendar(List<dynamic> rawAttendance) {
    dayStatus.clear();

    totalPresent = 0;
    totalAbsent = 0;
    totalRest = 0;
    totalHoliday = 0;
    totalLeave = 0;
    totalOSD = 0;
    totalhalf = 0;
    total2half = 0;

    final Map<int, List<dynamic>> groupedByDay = {};

    /// ---------------- GROUP BY DAY ----------------
    for (final item in rawAttendance) {
      if (item['attendanceDate'] == null) continue;

      final date = DateTime.tryParse(item['attendanceDate']);
      if (date == null) continue;

      final day = date.day;

      groupedByDay.putIfAbsent(day, () => []);
      groupedByDay[day]!.add(item);
    }

    /// ---------------- PROCESS EACH DAY ----------------
    groupedByDay.forEach((day, entries) {
      // 🔹 FULL DAY
      if (entries.length == 1 && entries.first['dayNo'] == 1) {
        final status = entries.first['dayStatus'];
        _applyStatus(day, status);
        return;
      }

      bool isHalf(double? v) => v != null && (v - 0.5).abs() < 0.001;

      // 🔹 HALF DAY (0.5 + 0.5)
      if (entries.length == 2 &&
          entries.every((e) => isHalf((e['dayNo'] as num?)?.toDouble()))) {
        final hasAbsent = entries.any((e) => e['dayStatus'] == 'A');
        final hasPresent = entries.any((e) => e['dayStatus'] == 'P');
        final hasHalfLeave = entries.any((e) => e['dayStatus'] == 'L/1');
        final has2ndHalfLeave = entries.any((e) => e['dayStatus'] == 'L/2');

        /// ----------- REAL HALF DAY (P + A) -----------
        if (hasAbsent && hasPresent) {
          final presentEntry = entries.firstWhere((e) => e['dayStatus'] == 'P');

          final String? inStr = presentEntry['inDateTime'];
          final String? hrsStr = presentEntry['timeHrs'];

          if (inStr == null || hrsStr == null) {
            _applyStatus(day, 'A');
            return;
          }

          final cleaned = inStr.replaceAll(' T ', 'T');
          final DateTime? inTime = DateTime.tryParse(cleaned);

          if (inTime == null) {
            _applyStatus(day, 'A');
            return;
          }

          /// Convert "04:16:00" → hours
          final parts = hrsStr.split(':');
          if (parts.length < 2) {
            _applyStatus(day, 'A');
            return;
          }

          final totalHours = int.parse(parts[0]) + (int.parse(parts[1]) / 60);

          if (totalHours >= 4) {
            /// 🔑 13:00 boundary
            final bool isSecondHalfPresent = inTime.hour >= 13;

            final String halfOrder = isSecondHalfPresent ? 'A-P' : 'P-A';

            dayStatus[day] = CalendarDayAttendance(
              status: 'HD',
              color: halfDayYellow,
              halfOrder: halfOrder,
            );

            totalAbsent += 0.5;
            totalPresent += 0.5;
            totalhalf++;
            return;
          }
        }

        /// ----------- HALF LEAVE CASES -----------
        if (hasHalfLeave && hasPresent) {
          dayStatus[day] = CalendarDayAttendance(
            status: 'L/1',
            color: leaveOrange,
          );
          totalLeave += 0.5;
          totalPresent += 0.5;
          return;
        }

        if (has2ndHalfLeave && hasPresent) {
          dayStatus[day] = CalendarDayAttendance(
            status: 'L/2',
            color: leaveOrange,
          );
          totalLeave += 0.5;
          totalPresent += 0.5;
          return;
        }
      }

      /// 🔹 FALLBACK
      final status = entries.first['dayStatus'];
      _applyStatus(day, status);
    });
  }

  void _applyStatus(int day, String status) {
    switch (status) {
      case 'P':
        dayStatus[day] = CalendarDayAttendance(
          status: 'P',
          color: presentGreen,
        );
        totalPresent++;
        break;

      case 'A':
        dayStatus[day] = CalendarDayAttendance(status: 'A', color: absentRed);
        totalAbsent++;
        break;

      case 'R':
        dayStatus[day] = CalendarDayAttendance(status: 'R', color: restGrey);
        totalRest++;
        break;

      case 'N':
        dayStatus[day] = CalendarDayAttendance(
          status: 'N',
          color: holidayPurple,
        );
        totalHoliday++;
        break;

      case 'O':
        dayStatus[day] = CalendarDayAttendance(status: 'O', color: osdBlue);
        totalOSD++;
        break;

      case 'D/1':
        dayStatus[day] = CalendarDayAttendance(status: 'D/1', color: dHalfGrey);
        total2half++;
        break;

      case 'L':
        dayStatus[day] = CalendarDayAttendance(status: 'L', color: leaveOrange);
        totalLeave++;
        break;
    }
  }

  void _showLeaveHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return const _LeaveHistorySheet();
      },
    );
  }

  void _showApplyLeaveSheet(BuildContext context, DateTime selectedDate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ApplyLeaveSheet(
          empCode: widget.empCode,
          initialDate: selectedDate,
          recommenderName: recommenderName,
          approverName: approverName,
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    minAllowedMonth = DateTime(currentMonth.year, currentMonth.month - 15);

    _selectedMonth = currentMonth;
    fetchAttendance();
  }

  double toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  /// 🔹 FETCH API (MONTH DYNAMIC)
  Future<void> fetchAttendance() async {
    setState(() {
      isLoading = true;
      dayStatus.clear();

      totalPresent = 0;
      totalAbsent = 0;
      totalRest = 0;
      totalHoliday = 0;
      totalLeave = 0;
    });

    final formattedMonth = DateFormat('yyyy-MM-01').format(_selectedMonth);

    // ✅ fallback if empCode is null
    final userId = widget.empCode;

    final url = Uri.parse(
      "http://192.168.20.44:81/api/attendance/get"
      "?userId=$userId&month=$formattedMonth",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // =====================================================
        // 🔹 ADD THIS BLOCK EXACTLY HERE (RIGHT AFTER jsonDecode)
        // =====================================================
        recommenderName = '';
        approverName = '';

        if (data['hierarchy'] != null) {
          for (final h in data['hierarchy']) {
            if (h['authFlg'] == 'R') {
              recommenderName = h['authEmpName'] ?? '';
            } else if (h['authFlg'] == 'A') {
              approverName = h['authEmpName'] ?? '';
            }
          }
        }
        // =====================================================
        // 🔹 END OF ADDITION
        // =====================================================

        /// 🔹 LEAVE BALANCE (REMAINING)
        totalCL = toDouble(data['leaveBalance']?['cl']);
        totalEL = toDouble(data['leaveBalance']?['el']);

        /// 🔹 CALENDAR DATA (DO NOT RE-FILTER MONTH)
        processAttendanceForCalendar(data['rawAttendance']);
      }
    } catch (e, stack) {
      debugPrint("======== API FAILED ========");
      debugPrint(e.toString());
      debugPrint(stack.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            content: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                "API ERROR:\n${e.toString()}",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        );
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );

    /// ⭐ FIRST DAY OFFSET (FOR WEEK ALIGNMENT)
    final firstDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );

    /// Sunday = 0 ... Saturday = 6
    final leadingEmptyCells = firstDayOfMonth.weekday % 7;
    final totalGridCells = leadingEmptyCells + daysInMonth;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
        automaticallyImplyLeading: false,
        title: const Text(
          "Leave & Attendance",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: primaryBlue,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  /// 🔹 LEAVE BALANCE
                  _LeaveBalanceCard(cl: totalCL, el: totalEL),

                  const SizedBox(height: 20),

                  /// 🔹 CALENDAR
                  Expanded(
                    child: Column(
                      children: [
                        /// ⭐ MONTH NAVIGATION
                        Row(
                          children: [
                            /// LEFT SPACER
                            const SizedBox(width: 8),

                            /// CENTER MONTH SECTION
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.chevron_left,
                                      color:
                                          _selectedMonth.isAfter(
                                            minAllowedMonth,
                                          )
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                    onPressed:
                                        _selectedMonth.isAfter(minAllowedMonth)
                                        ? () {
                                            setState(() {
                                              _selectedMonth = DateTime(
                                                _selectedMonth.year,
                                                _selectedMonth.month - 1,
                                              );
                                            });
                                            fetchAttendance();
                                          }
                                        : null,
                                  ),
                                  Text(
                                    DateFormat.yMMMM().format(_selectedMonth),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: primaryBlue,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed:
                                        _selectedMonth.isBefore(currentMonth)
                                        ? () {
                                            setState(() {
                                              _selectedMonth = DateTime(
                                                _selectedMonth.year,
                                                _selectedMonth.month + 1,
                                              );
                                            });
                                            fetchAttendance();
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ),

                            /// VIEW BUTTON AT END
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: primaryBlue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: primaryBlue),
                                ),
                              ),
                              icon: const Icon(
                                Icons.table_chart_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                "View",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AttendanceViewPage(
                                      userId: widget.empCode,
                                      month: _selectedMonth,
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(width: 8),
                          ],
                        ),

                        const SizedBox(height: 12),

                        /// 🔹 WEEK DAYS HEADER
                        Row(
                          children: weekDays
                              .map(
                                (day) => Expanded(
                                  child: Center(
                                    child: Text(
                                      day,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),

                        const SizedBox(height: 10),

                        /// 🔹 CALENDAR GRID
                        Expanded(
                          child: GridView.builder(
                            itemCount: totalGridCells,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                ),
                            itemBuilder: (context, index) {
                              /// EMPTY CELL BEFORE DAY 1
                              if (index < leadingEmptyCells) {
                                return const SizedBox();
                              }

                              final day = index - leadingEmptyCells + 1;
                              final attendance = dayStatus[day];
                              final decoration = getTileDecoration(attendance);

                              return GestureDetector(
                                onTap: () {
                                  if (attendance?.status == 'A'||attendance?.status == 'HD') {
                                    final selectedDate = DateTime(
                                      _selectedMonth.year,
                                      _selectedMonth.month,
                                      day,
                                    );
                                    _showApplyLeaveSheet(context, selectedDate);
                                  }
                                },
                                child: Container(
                                  decoration: decoration.copyWith(
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      day.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// 🔹 SUMMARY
                  _AttendanceSummary(
                    present: totalPresent,
                    absent: totalAbsent,
                    rest: totalRest,
                    holiday: totalHoliday,
                    leave: totalLeave,
                    osd: totalOSD,
                    half: totalhalf,
                    dHalf: total2half,
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.event_available,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Leave History",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        _showLeaveHistory(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// 🔹 SUMMARY
class _AttendanceSummary extends StatelessWidget {
  final double present;
  final double absent;
  final double rest;
  final double holiday;
  final double leave;
  final double osd;
  final double half;
  final double dHalf;

  const _AttendanceSummary({
    required this.present,
    required this.absent,
    required this.rest,
    required this.holiday,
    required this.leave,
    required this.osd,
    required this.half,
    required this.dHalf,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      children: [
        _SummaryTile("Present", present, presentGreen),
        _SummaryTile("Absent", absent, absentRed),
        _SummaryTile("Rest", rest, restGrey),
        _SummaryTile("Holiday", holiday, holidayPurple),
        _SummaryTile("Leave", leave, leaveOrange),
        _SummaryTile("OSD", osd, osdBlue),
        _SummaryTile("Half Day", half, halfDayYellow),
        _SummaryTile("D1/2", dHalf, dHalfGrey),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final LinearGradient? bgcolor;

  const _SummaryTile(
    this.label,
    this.value,
    this.color, {
    // ignore: unused_element_parameter
    this.bgcolor, // ✅ optional named parameter
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        bgcolor != null
            ? Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: bgcolor,
                ),
              )
            : CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 8),
        Text(
          "$label: $value",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// 🔹 LEAVE BALANCE CARD
class _LeaveBalanceCard extends StatelessWidget {
  final double cl;
  final double el;

  const _LeaveBalanceCard({required this.cl, required this.el});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _LeaveBox(label: "CL", value: cl, color: Colors.blue),
          _LeaveBox(label: "EL", value: el, color: Colors.green),
        ],
      ),
    );
  }
}

class _LeaveBox extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _LeaveBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ApplyLeaveSheet extends StatefulWidget {
  final DateTime initialDate;
  final String recommenderName;
  final String approverName;
  final String empCode;

  const _ApplyLeaveSheet({
    required this.initialDate,
    required this.recommenderName,
    required this.approverName,
    required this.empCode,
  });

  @override
  State<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<_ApplyLeaveSheet> {
  bool forMyself = true;
  bool halfDay = false;

  String halfDayType = 'First Half';
  String leaveType = 'CL';
  String reason = 'Personal Work';

  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();

  /// CARD ERROR
  DateTime? cardErrorDate;
  String cardErrorType = "In";
  TimeOfDay? cardErrorTime;

  /// OSD
  DateTime? osdFromDate;
  DateTime? osdToDate;
  TimeOfDay? osdFromTime;
  TimeOfDay? osdToTime;
  final TextEditingController osdReasonCtrl = TextEditingController();

  final TextEditingController otherReasonCtrl = TextEditingController();

  int selectedMode = 0; // 0 = Leave, 1 = Card Error, 2 = OSD
  Map<DateTime, Set<String>> halfDaySelections = {};

  int getEmpCodeNumber(String empCode) {
    final numeric = empCode.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(numeric) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    fromDate = widget.initialDate;
    toDate = widget.initialDate;
  }

  Widget _timePickerTile(String label, TimeOfDay? value, VoidCallback onTap) {
    final display = value == null ? "--:--" : value.format(context);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: Colors.blueGrey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              display,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: value == null ? Colors.grey : primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardErrorForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Card Error Request",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 18),

        /// DATE
        _DateTile(
          label: "Select Date",
          date: cardErrorDate ?? DateTime.now(),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2023),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              setState(() => cardErrorDate = picked);
            }
          },
        ),

        const SizedBox(height: 16),

        /// TYPE
        ModernDropdown(
          label: "Card Error Type",
          value: cardErrorType,
          icon: Icons.login_rounded,
          items: const [
            DropdownMenuItem(value: 'In', child: Text("In Punch Missing")),
            DropdownMenuItem(value: 'Out', child: Text("Out Punch Missing")),
          ],
          onChanged: (v) => setState(() => cardErrorType = v!),
        ),

        const SizedBox(height: 16),

        /// TIME
        _timePickerTile("Select Time", cardErrorTime, () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );
          if (picked != null) setState(() => cardErrorTime = picked);
        }),

        const SizedBox(height: 26),
      ],
    );
  }

  Widget _osdForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "On Site Duty (OSD)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: _DateTile(
                label: "From Date",
                date: osdFromDate ?? DateTime.now(),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => osdFromDate = picked);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateTile(
                label: "To Date",
                date: osdToDate ?? DateTime.now(),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => osdToDate = picked);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _timePickerTile("From Time", osdFromTime, () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (t != null) setState(() => osdFromTime = t);
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _timePickerTile("To Time", osdToTime, () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (t != null) setState(() => osdToTime = t);
              }),
            ),
          ],
        ),

        const SizedBox(height: 16),

        TextField(
          controller: osdReasonCtrl,
          maxLines: 3,
          decoration: _inputDecoration("Purpose / Remarks", icon: Icons.work),
        ),

        const SizedBox(height: 26),
      ],
    );
  }

  Future<void> pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
          toDate = picked;
        } else {
          toDate = picked;
        }
      });
    }
  }

  Widget _modeButton(String text, int index, IconData icon) {
    final selected = selectedMode == index;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => selectedMode = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? primaryBlue : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : Colors.black54),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openHalfDayDialog() {
    List<DateTime> dates = [];
    DateTime d = fromDate;

    while (!d.isAfter(toDate)) {
      dates.add(d);
      d = d.add(const Duration(days: 1));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Select Half Days",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: ListView.builder(
                      itemCount: dates.length,
                      itemBuilder: (_, i) {
                        final date = dates[i];
                        final selected = halfDaySelections[date] ?? {};

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.grey.shade50,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE, dd MMM yyyy').format(date),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _halfOption(
                                    "First Half",
                                    "FH",
                                    selected,
                                    date,
                                    setStateDialog,
                                  ),
                                  const SizedBox(width: 12),
                                  _halfOption(
                                    "Second Half",
                                    "SH",
                                    selected,
                                    date,
                                    setStateDialog,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(.35),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Apply Selection",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: .3,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () {
                          setState(
                            () => halfDay = halfDaySelections.isNotEmpty,
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _leaveForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// LEAVE TYPE
        ModernDropdown(
          label: "Leave Type",
          value: leaveType,
          icon: Icons.event_note_outlined,
          items: const [
            DropdownMenuItem(value: 'CL', child: Text("Casual Leave")),
            DropdownMenuItem(value: 'EL', child: Text("Earned Leave")),
            DropdownMenuItem(value: 'CPL', child: Text("Comp Off")),
          ],
          onChanged: (v) => setState(() => leaveType = v!),
        ),

        const SizedBox(height: 16),

        /// DATES
        Row(
          children: [
            Expanded(
              child: _DateTile(
                label: "From Date",
                date: fromDate,
                onTap: () => pickDate(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateTile(
                label: "To Date",
                date: toDate,
                onTap: () => pickDate(false),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        /// HALF DAY
        GestureDetector(
          onTap: _openHalfDayDialog,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  "Select Half Days",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        /// REASON
        ModernDropdown(
          label: "Leave Reason",
          value: reason,
          icon: Icons.info_outline_rounded,
          items: const [
            DropdownMenuItem(
              value: 'Personal Work',
              child: Text("Personal Work"),
            ),
            DropdownMenuItem(value: 'Medical', child: Text("Medical")),
            DropdownMenuItem(
              value: 'Out of Station',
              child: Text("Out of Station"),
            ),
            DropdownMenuItem(
              value: 'Against Holiday',
              child: Text("Against Holiday"),
            ),
            DropdownMenuItem(value: 'Other', child: Text("Other")),
          ],
          onChanged: (v) => setState(() => reason = v!),
        ),

        const SizedBox(height: 12),

        /// OTHER REASON
        if (reason == "Other")
          TextField(
            controller: otherReasonCtrl,
            maxLines: 3,
            decoration: _inputDecoration("Other Reason", icon: Icons.edit),
          ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _halfOption(
    String label,
    String key,
    Set<String> selected,
    DateTime date,
    Function setStateDialog,
  ) {
    final isSelected = selected.contains(key);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setStateDialog(() {
            /// IMPORTANT CHANGE:
            /// only one value allowed per date
            if (isSelected) {
              // unselect if tapped again
              selected.clear();
            } else {
              // replace existing selection
              selected
                ..clear()
                ..add(key);
            }

            halfDaySelections[date] = selected;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.grey.shade100,
            border: Border.all(
              color: isSelected ? Colors.transparent : Colors.grey.shade300,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(.35),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// DRAG HANDLE
            Center(
              child: Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              "Apply Leave",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _AuthInfoTile(
                    icon: Icons.person_outline,
                    label: "Recommender",
                    value: widget.recommenderName.isNotEmpty
                        ? widget.recommenderName
                        : "Not Assigned",
                  ),
                  const SizedBox(height: 10),
                  Divider(color: Colors.grey.shade300, height: 1),
                  const SizedBox(height: 10),
                  _AuthInfoTile(
                    icon: Icons.verified_user_outlined,
                    label: "Approver",
                    value: widget.approverName.isNotEmpty
                        ? widget.approverName
                        : "Not Assigned",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// FOR MYSELF / OTHERS
            Row(
              children: [
                _modeButton("Leave", 0, Icons.event_available),
                const SizedBox(width: 8),
                _modeButton("Card Error", 1, Icons.badge_outlined),
                const SizedBox(width: 8),
                _modeButton("OSD", 2, Icons.business_center_outlined),
              ],
            ),

            const SizedBox(height: 20),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: selectedMode == 0
                  ? _leaveForm()
                  : selectedMode == 1
                  ? _cardErrorForm()
                  : _osdForm(),
            ),

            /// APPLY BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () async {
                  FocusScope.of(context).unfocus();

                  final rootNavigator = Navigator.of(
                    context,
                    rootNavigator: true,
                  );
                  final rootMessenger = ScaffoldMessenger.of(
                    rootNavigator.context,
                  );

                  showDialog(
                    context: rootNavigator.context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    String message = "";

                    /// =========================
                    /// LEAVE
                    /// =========================
                    if (selectedMode == 0) {
                      message = await LeaveService.applyLeave(
                        userId: getEmpCodeNumber(widget.empCode),
                        fromDate: fromDate,
                        toDate: toDate,
                        leaveType: leaveType,
                        isHalfDay: halfDay,
                        halfDayType: halfDayType,
                        remarks: reason == "Other"
                            ? otherReasonCtrl.text.trim()
                            : reason,
                      );
                    }
                    /// =========================
                    /// CARD ERROR
                    /// =========================
                    else if (selectedMode == 1) {
                      if (cardErrorDate == null || cardErrorTime == null) {
                        throw Exception("Please select card error date & time");
                      }

                      message = await LeaveService.applyCardError(
                        userId: getEmpCodeNumber(widget.empCode),
                        date: cardErrorDate!,
                        time: cardErrorTime!,
                        type: cardErrorType,
                      );
                    }
                    /// =========================
                    /// OSD
                    /// =========================
                    else if (selectedMode == 2) {
                      if (osdFromDate == null ||
                          osdToDate == null ||
                          osdFromTime == null ||
                          osdToTime == null ||
                          osdReasonCtrl.text.trim().isEmpty) {
                        throw Exception("Please complete OSD details");
                      }

                      message = await LeaveService.applyOSD(
                        userId: getEmpCodeNumber(widget.empCode),
                        fromDate: osdFromDate!,
                        toDate: osdToDate!,
                        fromTime: osdFromTime!,
                        toTime: osdToTime!,
                        reason: osdReasonCtrl.text.trim(),
                      );
                    }

                    /// CLOSE LOADER
                    rootNavigator.pop();

                    /// CLOSE SHEET
                    Navigator.of(context).pop();

                    rootMessenger.showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: Colors.green.shade600,
                      ),
                    );
                  } catch (e) {
                    rootNavigator.pop();
                    Navigator.of(context).pop();

                    rootMessenger.showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.red.shade600,
                      ),
                    );
                  }
                },

                child: const Text(
                  "Submit",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(date),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class ModernDropdown extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const ModernDropdown({
    required this.label,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      borderRadius: BorderRadius.circular(18),
      dropdownColor: Colors.white,
      elevation: 6,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

class _LeaveHistorySheet extends StatelessWidget {
  const _LeaveHistorySheet();

  @override
  Widget build(BuildContext context) {
    final history = [
      {"date": "15 Feb 2024", "type": "CL", "status": "Pending"},
      {"date": "10 Feb 2024", "type": "EL", "status": "Approved"},
    ];

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// DRAG HANDLE
          Center(
            child: Container(
              height: 4,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          const SizedBox(height: 16),

          /// TITLE
          const Text(
            "Leave History",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),

          const SizedBox(height: 20),

          /// LIST
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = history[index];
              final bool isPending = item['status'] == "Pending";

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  splashColor: primaryBlue.withOpacity(0.08),
                  highlightColor: Colors.transparent,
                  onTap: () {},
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        /// LEFT ICON
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.event_note_outlined,
                            color: primaryBlue,
                          ),
                        ),

                        const SizedBox(width: 14),

                        /// DETAILS
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${item['type']} Leave",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['date']!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        /// STATUS / ACTION
                        isPending
                            ? _CancelButton(
                                onTap: () {
                                  final rootContext = Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).context;
                                  final rootMessenger = ScaffoldMessenger.of(
                                    rootContext,
                                  );

                                  Navigator.of(context).pop(); // close sheet

                                  rootMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text("Leave Cancelled"),
                                    ),
                                  );
                                },
                              )
                            : _StatusPill(
                                text: "Approved",
                                color: Colors.green,
                              ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 🔹 CANCEL BUTTON (MODERN)
class _CancelButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CancelButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.redAccent),
        ),
        child: const Text(
          "Cancel",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// 🔹 STATUS PILL
class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _AuthInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AuthInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: primaryBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CalendarDayAttendance {
  final String status; // P, A, R, NH, O, HD, D1/2
  final Color color;
  final String? halfOrder;

  CalendarDayAttendance({
    required this.status,
    required this.color,
    this.halfOrder,
  });
}
