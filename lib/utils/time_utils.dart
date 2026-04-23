class TimeUtils {
  static String formatMinutes(double totalMinutes) {
    if (totalMinutes <= 0) return "0 mins";
    
    int hours = totalMinutes ~/ 60;
    int mins = (totalMinutes % 60).round();
    
    if (hours > 0) {
      return "${hours}hr ${mins}mins";
    } else {
      return "${mins}mins";
    }
  }
}
