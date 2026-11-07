class AppConstants {
  static const String appName = 'CityBus Go';
  static const String currencySymbol = 'Rs.';

  // User roles
  static const String rolePassenger = 'passenger';
  static const String roleConductor = 'conductor';
  static const String roleAdmin = 'admin';

  // Seat statuses
  static const String seatAvailable = 'available';
  static const String seatTaken = 'taken';

  static String money(double v) => '$currencySymbol ${v.toStringAsFixed(2)}';
}
