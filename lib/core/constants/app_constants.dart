class AppConstants {
  AppConstants._();

  static const String appName = 'Bullseye';
  static const String appVersion = '1.5.0';

  // Default timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration pingTimeout = Duration(seconds: 5);

  // Monitor defaults
  static const int defaultCheckInterval = 60; // seconds
  static const int maxSavedConnections = 500;
  static const int maxMonitorHistory = 1000;

  // SSH defaults
  static const int defaultSSHPort = 22;
  static const int defaultFTPPort = 21;
  static const int defaultSFTPPort = 22;
  static const int defaultHTTPPort = 80;
  static const int defaultHTTPSPort = 443;

  // Common ports for scanning
  static const List<int> commonPorts = [
    20, 21, 22, 23, 25, 53, 80, 110, 143, 443,
    465, 587, 993, 995, 3306, 3389, 5432, 5900,
    6379, 8080, 8443, 27017,
  ];

  // Port service names
  static const Map<int, String> portServiceNames = {
    20: 'FTP Data',
    21: 'FTP Control',
    22: 'SSH/SFTP',
    23: 'Telnet',
    25: 'SMTP',
    53: 'DNS',
    80: 'HTTP',
    110: 'POP3',
    143: 'IMAP',
    443: 'HTTPS',
    465: 'SMTPS',
    587: 'SMTP (Submission)',
    993: 'IMAPS',
    995: 'POP3S',
    3306: 'MySQL',
    3389: 'RDP',
    5432: 'PostgreSQL',
    5900: 'VNC',
    6379: 'Redis',
    8080: 'HTTP Alt',
    8443: 'HTTPS Alt',
    27017: 'MongoDB',
  };

  // DNS record types
  static const List<String> dnsRecordTypes = [
    'A', 'AAAA', 'MX', 'TXT', 'NS', 'CNAME', 'SOA', 'SRV', 'PTR',
  ];
}
