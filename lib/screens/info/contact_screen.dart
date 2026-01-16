import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@gmail.com',
      query: 'subject=YallaQR Support Request',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _launchPhone() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+961-76557980');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    final phoneNumber = '96176557980';
    
    // Try WhatsApp app directly (don't check canLaunchUrl as it's unreliable on Android)
    final Uri whatsappAppUri = Uri.parse('whatsapp://send?phone=$phoneNumber');
    
    try {
      // Try launching WhatsApp app directly
      final launched = await launchUrl(
        whatsappAppUri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        // If direct launch failed, try web WhatsApp
        final Uri whatsappWebUri = Uri.parse('https://wa.me/$phoneNumber');
        final webLaunched = await launchUrl(
          whatsappWebUri,
          mode: LaunchMode.externalApplication,
        );
        
        if (!webLaunched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open WhatsApp'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      
      // Try web fallback
      try {
        final Uri whatsappWebUri = Uri.parse('https://wa.me/$phoneNumber');
        await launchUrl(whatsappWebUri, mode: LaunchMode.externalApplication);
      } catch (webError) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp is not installed on this device'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.contact_support,
                      size: 40,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Get in Touch',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'re here to help you',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Contact Methods
            _buildContactCard(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: 'support@gmail.com',
              onTap: _launchEmail,
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              icon: Icons.phone_outlined,
              title: 'Phone',
              subtitle: '+961-76557980',
              onTap: _launchPhone,
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              icon: Icons.chat_bubble_outline,
              title: 'WhatsApp',
              subtitle: '+961-76557980',
              onTap: () => _launchWhatsApp(context),
              color: Colors.green,
            ),
            const SizedBox(height: 20),

            // Business Hours
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Business Hours',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildHoursRow('Monday - Friday', '9:00 AM - 6:00 PM'),
                  _buildHoursRow('Saturday', '10:00 AM - 4:00 PM'),
                  _buildHoursRow('Sunday', 'Closed'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (color ?? Colors.blue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color ?? Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHoursRow(String day, String hours) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            hours,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
