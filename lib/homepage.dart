
import 'package:flutter/material.dart';
import 'package:hrms_app/approvals.dart';
import 'package:hrms_app/leave_page.dart';
import 'package:hrms_app/main.dart';
import 'package:hrms_app/profilepage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color primaryBlue = Color.fromARGB(255, 37, 108, 189);

class HomePage extends StatefulWidget {
  final String? fullName;
  final String empCode;
  const HomePage({super.key, this.fullName, required this.empCode});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;


  late String formattedName;

  @override
  void initState() {
    super.initState();

    formattedName = widget.fullName != null && widget.fullName!.isNotEmpty
        ? widget.fullName!
        : "User";

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  String get greetingText {
    final hour = DateTime.now().hour;

    if (hour < 12) return "Good Morning";
    if (hour < 16) return "Good Afternoon";
    return "Good Evening";
  }

  void _logout() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );
}

  void _showLogoutSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout, size: 40, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                "Logout",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                "Are you sure you want to logout?",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _logout,
                    child: const Text(
                      "Logout",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canSeeApprovals =
        widget.empCode.toLowerCase() == "kpl4088" ||
        widget.empCode.toLowerCase() == "kpl1714";
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              /// ✅ STATIC GREETING (NO SLIDESHOW)
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _GreetingCard(
                    text: "Welcome \n$greetingText,  $formattedName",
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// 👤 PROFILE IMAGE
              GestureDetector(
                onTap: _showLogoutSheet,
                child: ClipOval(
                  child: Image.asset(
                    "assets/profile_image.png", // ✅ FULL PATH
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              /// QUICK ACTIONS
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Quick Actions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primaryBlue,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
                children: [
                  _ActionTile(
                    title: "Profile",
                    icon: Icons.person_outline,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => ProfilePage()),
                      );
                    },
                  ),

                  _ActionTile(
                    title: "Leave",
                    icon: Icons.calendar_month_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LeavePage(empCode: widget.empCode),
                        ),
                      );
                    },
                  ),

                  _ActionTile(
                    title: "HR Guidelines",
                    icon: Icons.menu_book_outlined,
                    onTap: () {},
                  ),

                  if (canSeeApprovals)
                    _ActionTile(
                      title: "Approvals",
                      icon: Icons.add_task,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                ApprovalsPage(appCode: widget.empCode),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 💬 Greeting Card
class _GreetingCard extends StatelessWidget {
  final String text;

  const _GreetingCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}

/// 🧱 Action Tile
class _ActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: primaryBlue),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
