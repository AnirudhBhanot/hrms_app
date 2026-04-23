import 'package:flutter/material.dart';

const Color primaryBlue = Color(0xFF256CBD);
const Color accentYellow = Color(0xFFFFC15A);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int selectedIndex = 0;

  /// 🔹 MOCK PROFILE DATA (Later replace with API)
  final Map<String, String> profileData = {
    "Name": "ANIRUDH BHANOT",
    "Gender": "Male",
    "DOB": "09-09-2000",
    "Father": "AKHIL NIRMAL BHANOT",
    "Mother": "AARTI BHANOT",
    "Marital Status": "Single",
    "Religion": "", // EMPTY BUT SHOULD SHOW
    "Blood Group": "O+ve",
    "Nationality": "Indian",
    "Mobile": "9519511537",
    "Email": "anirbhannot1124@gmail.com",
  };

  /// 🔹 POSITION DETAILS (From Image)
  final Map<String, String> positionGeneralDetails = {
    "Emp Category": "PERMANENT",
    "Emp Type": "STAFF",
    "Work Location": "SAILA",
    "Division": "INFOTECH",
    "Department": "INFOTECH - Software",
    "Grade": "TRAINEE-OFF (N) (TR-OFF (N))",
    "Section": "-",
    "Designation": "TRAINEE-OFFICER",
    "Cost Center": "36512",
    "PF Est. ID": "LDJAL0009864000",
    "PF No": "-",
    "ESI No": "2914608814",
    "Biometric ID No": "5403",
    "Mode Of Attendance": "E",
    "Shift Type": "G",
    "Rest Day": "Sunday",
    "Alternate Rest Type": "-",
  };

  final Map<String, String> onboardingDetails = {
    "DOJ": "01.10.2025",
    "DOR": "-",
    "DOE": "-",
  };

  final List<Map<String, String>> experienceData = [
    {
      "Employer": "KUANTUM PAPERS LTD",
      "Designation": "APPRENTICE",
      "Start": "26-09-2024",
      "End": "25-09-2025",
      "Exp": "1",
      "Remarks": "",
    },
    {
      "Employer": "ELEVATE TECH",
      "Designation": "MOBILE APP DEVELOPER",
      "Start": "01-10-2022",
      "End": "19-10-2023",
      "Exp": "1",
      "Remarks": "",
    },
  ];

  final List<Map<String, String>> educationData = [
    {
      "Education": "GRADUATION",
      "Course": "B.Tech.",
      "Specialization": "COMPUTER SCIENCE",
    },
  ];

  final List<Map<String, String>> ctcData = [
    {"Head": "Basic", "Amount": "107760.00", "Mode": "S"},
    {"Head": "HRA", "Amount": "4310.00", "Mode": "S"},
    {"Head": "Ad-Hoc", "Amount": "62660.00", "Mode": "S"},
    {"Head": "CEA", "Amount": "2000.00", "Mode": "S"},
    {"Head": "Gross", "Amount": "215520.00", "Mode": "N"},
    {"Head": "PF", "Amount": "12930.00", "Mode": "N"},
    {"Head": "BONUS", "Amount": "21550.00", "Mode": "N"},
    {"Head": "CTC", "Amount": "250000.00", "Mode": "N"},
  ];

  final List<_ProfileTileData> tiles = const [
    _ProfileTileData("Personal", Icons.person_outline),
    _ProfileTileData("Position", Icons.work_outline),
    _ProfileTileData("Experience", Icons.timeline_outlined),
    _ProfileTileData("Education", Icons.school_outlined),
    _ProfileTileData("CTC", Icons.currency_rupee_outlined),
    _ProfileTileData("Payslip", Icons.receipt_long_outlined),
  ];

  void _openDetails(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🔷 HEADER
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                /// 🔹 PERSONAL TILE CONTENT (UNCHANGED)
                if (title == "Personal") ...[
                  ...profileData.entries.map(
                    (e) => _infoRow(e.key, e.value.isEmpty ? "-" : e.value),
                  ),
                  const SizedBox(height: 20),
                  _addressCard(
                    title: "Residential Address",
                    address:
                        "Saila Khurd, Mahilpur\nHoshiarpur, Punjab\n144529",
                  ),
                  const SizedBox(height: 12),
                  _addressCard(
                    title: "Contact Address",
                    address:
                        "#201C, Leaf Stone Apartments\nHighland Marg, Zirakpur\nPunjab - 140603",
                  ),
                ],

                if (title == "Position") ...[
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Column(
                      children: [
                        /// 🔹 GENERAL DETAILS (MAIN CONTENT)
                        Expanded(
                          flex: 4,
                          child: _sectionCardScrollable(
                            title: "General Details",
                            children: positionGeneralDetails.entries
                                .map(
                                  (e) => _infoRow(
                                    e.key,
                                    e.value.isEmpty ? "-" : e.value,
                                  ),
                                )
                                .toList(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// 🔹 ONBOARDING (COMPACT)
                        _sectionCardCompact(
                          title: "Onboarding",
                          children: onboardingDetails.entries
                              .map(
                                (e) => _infoRow(
                                  e.key,
                                  e.value.isEmpty ? "-" : e.value,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
                if (title == "Experience") ...[_experienceSection()],
                if (title == "Education") ...[_educationSection()],
                if (title == "CTC") ...[_ctcSection()],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _addressCard({required String title, required String address}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(address, style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }

  static Widget _sectionCardScrollable({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔹 SECTION TITLE
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          /// 🔹 FULL-WIDTH SCROLLABLE CONTENT (NO SCROLLBAR)
          Expanded(
            child: ScrollConfiguration(
              behavior: const _NoScrollbarBehavior(),
              child: ListView(
                padding: EdgeInsets.zero,
                children: children
                    .map(
                      (child) => SizedBox(
                        width: double.infinity, // 🔥 THIS FIXES WHITE SPACE
                        child: child,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionCardCompact({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _experienceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// 🔷 HEADER BAR
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            "Experience Details",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),

        const SizedBox(height: 12),

        /// 🔷 TABLE CARD
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 44,
              dataRowHeight: 48,
              headingRowColor: MaterialStateProperty.all(
                primaryBlue.withOpacity(0.95),
              ),
              columns: [
                _tableHeader("Employer Name"),
                _tableHeader("Designation"),
                _tableHeader("Start Date"),
                _tableHeader("End Date"),
                _tableHeader("Experience"),
                _tableHeader("Remarks"),
              ],
              rows: experienceData
                  .map(
                    (e) => DataRow(
                      cells: [
                        _tableCell(e["Employer"]!),
                        _tableCell(e["Designation"]!),
                        _tableCell(e["Start"]!),
                        _tableCell(e["End"]!),
                        _tableCell(e["Exp"]!),
                        _tableCell(e["Remarks"]!.isEmpty ? "-" : e["Remarks"]!),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _educationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// 🔷 HEADER BAR
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            "Education Details",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),

        const SizedBox(height: 12),

        /// 🔷 TABLE CARD
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 44,
              dataRowHeight: 48,
              headingRowColor: MaterialStateProperty.all(
                primaryBlue.withOpacity(0.95),
              ),
              columns: const [
                DataColumn(label: _TableHeader("Education Description")),
                DataColumn(label: _TableHeader("Course")),
                DataColumn(label: _TableHeader("Specialization")),
              ],
              rows: educationData
                  .map(
                    (e) => DataRow(
                      cells: [
                        _tableCell(e["Education"] ?? "-"),
                        _tableCell(e["Course"] ?? "-"),
                        _tableCell(e["Specialization"] ?? "-"),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ctcSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// 🔷 HEADER BAR
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            "CTC Details",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),

        const SizedBox(height: 12),

        /// 🔷 PAYROLL TABLE
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 44,
              dataRowHeight: 46,
              columnSpacing: 40,
              headingRowColor: MaterialStateProperty.all(
                primaryBlue.withOpacity(0.95),
              ),
              columns: const [
                DataColumn(label: _TableHeader("Slip Head")),
                DataColumn(label: _TableHeader("Amount (Rs)")),
                DataColumn(label: _TableHeader("ModePayment")),
              ],
              rows: ctcData
                  .map(
                    (e) => DataRow(
                      cells: [
                        _tableCell(e["Head"] ?? "-"),
                        _tableCell(e["Amount"] ?? "-"),
                        _tableCell(e["Mode"] ?? "-"),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  static DataColumn _tableHeader(String text) {
    return DataColumn(
      label: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  static DataCell _tableCell(String text) {
    return DataCell(
      Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      /// 🔷 APP BAR
      appBar: AppBar(
        backgroundColor: primaryBlue,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),

      body: Column(
        children: [
          const SizedBox(height: 24),

          /// 🔷 USER HEADER
          const CircleAvatar(
            radius: 36,
            backgroundColor: primaryBlue,
            child: Icon(Icons.person, color: Colors.white, size: 38),
          ),
          const SizedBox(height: 10),
          const Text(
            "ANIRUDH BHANOT",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "TRAINEE OFFICER • INFOTECH",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 4),
          const Text(
            "anirbhannot1124@gmail.com",
            style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 30),

          /// 🔷 TILES GRID
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: tiles.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                final isActive = selectedIndex == index;
                final tile = tiles[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setState(() => selectedIndex = index);
                    _openDetails(context, tile.title);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color: isActive ? accentYellow : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tile.icon,
                          size: 30,
                          color: isActive ? Colors.black : primaryBlue,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tile.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.black : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 🔷 TILE MODEL
class _ProfileTileData {
  final String title;
  final IconData icon;

  const _ProfileTileData(this.title, this.icon);
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // 🚫 disables scrollbar completely
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }
}
