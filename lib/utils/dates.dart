DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// [days] calendar days after [d], at midnight (or at [hour]). Not
/// `d.add(Duration(days: …))`: that adds 24-hour blocks, and across the end of summer time
/// midnight plus 24 hours is still the same day (23:00) — the API then gets
/// StartDate == EndDate.
DateTime addDays(DateTime d, int days, {int hour = 0}) =>
    DateTime(d.year, d.month, d.day + days, hour);

/// The Monday of the week [day] falls in.
DateTime weekOf(DateTime day) => addDays(day, -(day.weekday - 1));
