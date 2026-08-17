class Time {
    final int year;
    final int month;
    final int day;

    final int hour;
    final int minute;
    final int second;

    final int hoursInDay;
    final int daysInMonth;
    final int monthsInYear;

    final int daysPassedFromStart;

    Time({required this.year, required this.month, required this.day, 
        required this.hour, required this.minute, required this.second, 
        this.hoursInDay = 24, this.daysInMonth = 30, this.monthsInYear = 12,
        this.daysPassedFromStart = 0});

    int get _getTotalDays => year * daysInYear + (month - 1) * daysInMonth + day - 1;
    
    int get overalSeconds => year * daysInYear * hoursInDay * 60 * 60 +
        month * daysInMonth * hoursInDay * 60 * 60 +
        day * hoursInDay * 60 * 60 +
        hour * 60 * 60 +
        minute * 60 +
        second;

    int get daysInYear => monthsInYear * daysInMonth;
    
    String get shortTime => '${year}Y${month}M${day}D $hour:$minute:$second';

    int compare(Time other) {
        return overalSeconds - other.overalSeconds;
    }

    Time addSeconds(int seconds) {
        var totalSeconds = second + seconds;
        
        if (totalSeconds < 60) {
            return Time(year: year, month: month, day: day, 
                hour: hour, minute: minute, second: totalSeconds, 
                hoursInDay: hoursInDay, daysInMonth: daysInMonth, monthsInYear: monthsInYear,
                daysPassedFromStart: daysPassedFromStart);
        }

        var totalMinutes = minute + (totalSeconds ~/ 60);
        totalSeconds = totalSeconds % 60;
        
        if (totalMinutes < 60) {
            return Time(year: year, month: month, day: day, 
                hour: hour, minute: totalMinutes, second: totalSeconds, 
                hoursInDay: hoursInDay, daysInMonth: daysInMonth, monthsInYear: monthsInYear,
                daysPassedFromStart: daysPassedFromStart);
        }

        var totalHours = hour + (totalMinutes ~/ 60);
        totalMinutes = totalMinutes % 60;

        if (totalHours < hoursInDay) {
            return Time(year: year, month: month, day: day, 
                hour: totalHours, minute: totalMinutes, second: totalSeconds, 
                hoursInDay: hoursInDay, daysInMonth: daysInMonth, monthsInYear: monthsInYear,
                daysPassedFromStart: daysPassedFromStart);
        }

        final daysPassed = totalHours ~/ hoursInDay;

        totalHours = totalHours % hoursInDay;

        var totalDays = _getTotalDays + daysPassed;
        final totalYears = totalDays ~/ daysInYear;
        final totalMonth = (totalDays % daysInYear) ~/ daysInMonth;
        totalDays = totalDays - totalYears * daysInYear - totalMonth * daysInMonth + 1;

        return Time(year: totalYears, month: totalMonth + 1, day: totalDays, 
            hour: totalHours, minute: totalMinutes, second: totalSeconds, 
            hoursInDay: hoursInDay, daysInMonth: daysInMonth, monthsInYear: monthsInYear,
            daysPassedFromStart: daysPassedFromStart + daysPassed);
    }

    factory Time.fromJson(Map<String, dynamic> json) {
        return Time(
            year: json['year'] as int? ?? 0, 
            month: json['month'] as int? ?? 1, 
            day: json['day'] as int? ?? 1, 
            
            hour: json['hour'] as int? ?? 0, 
            minute: json['minute'] as int? ?? 0, 
            second: json['second'] as int? ?? 0,
            
            hoursInDay: json['hoursInDay'] as int? ?? 24,
            daysInMonth: json['daysInMonth'] as int? ?? 30,
            monthsInYear: json['monthsInYear'] as int? ?? 12,
            
            daysPassedFromStart: json['daysPassedFromStart'] as int? ?? 0
        );
    }

    Map<String, dynamic> toJson() {
        return {
            'year': year,
            'month': month,
            'day': day,

            'hour': hour,
            'minute': minute,
            'second': second,

            'hoursInDay': hoursInDay,
            'daysInMonth': daysInMonth,
            'monthsInYear': monthsInYear,

            'daysPassedFromStart': daysPassedFromStart
        };
    }
}