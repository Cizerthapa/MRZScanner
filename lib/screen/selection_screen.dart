import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mrzreader/screen/mrz_scanner_screen.dart';

class SelectionScreen extends StatelessWidget {
  const SelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'SELECT MODE',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0.w,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildOptionCard(
                context,
                title: 'LIVE SCAN',
                description: 'Auto-detect MRZ from camera stream',
                icon: Icons.qr_code_scanner,
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const MRZScannerScreen(scanMode: ScanMode.live),
                    ),
                  );
                },
              ),
              SizedBox(height: 24.h),
              _buildOptionCard(
                context,
                title: 'PHOTO SCAN',
                description: 'Take a photo to process',
                icon: Icons.camera_alt_outlined,
                color: Colors.purpleAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const MRZScannerScreen(scanMode: ScanMode.photo),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: color.withAlpha(76), width: 2.w),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: color.withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32.r),
              ),
              SizedBox(width: 20.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2.w,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withAlpha(178),
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withAlpha(76),
                size: 16.r,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
