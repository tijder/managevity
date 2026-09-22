// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Managevity';

  @override
  String get appSubtitle => 'Unofficial client for Sportivity';

  @override
  String get disclaimer => 'Not affiliated with or endorsed by b.o.s.s. or Sportivity.';

  @override
  String get loginUser => 'Email or username';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginRemember => 'Stay signed in';

  @override
  String get loginRememberHint =>
      'Stores your password in this device\'s keychain so an expired session renews itself.';

  @override
  String get loginRememberWeb => 'Your password is never stored in the browser.';

  @override
  String get loginButton => 'Sign in';

  @override
  String get loginForgot => 'Forgot password?';

  @override
  String get loginForgotSent => 'Request sent. Check your email.';

  @override
  String get loginForgotNeedsUser => 'Enter your email or username first.';

  @override
  String get fieldRequired => 'Required';

  @override
  String get locationTitle => 'Choose your location';

  @override
  String get locationNone => 'No locations found.';

  @override
  String get tabSchedule => 'Schedule';

  @override
  String get tabMyLessons => 'My lessons';

  @override
  String get tabBusy => 'Busyness';

  @override
  String get tabMore => 'More';

  @override
  String get today => 'Today';

  @override
  String get scheduleEmpty => 'No lessons on this day.';

  @override
  String get scheduleFilter => 'Filter by activity';

  @override
  String get scheduleFilterAll => 'All';

  @override
  String get myLessonsEmpty => 'You have no booked lessons.';

  @override
  String get lessonBook => 'Book';

  @override
  String get lessonJoinWaitingList => 'Join waiting list';

  @override
  String get lessonCancel => 'Cancel booking';

  @override
  String get lessonCancelConfirm => 'Cancel this booking?';

  @override
  String get lessonBooked => 'Booked';

  @override
  String get lessonWaitingList => 'Waiting list';

  @override
  String get lessonFull => 'Full';

  @override
  String get lessonPast => 'This lesson is over.';

  @override
  String get lessonTrainer => 'Trainer';

  @override
  String get lessonRoom => 'Room';

  @override
  String get lessonLike => 'Favourite';

  @override
  String get lessonBuyTitle => 'This lesson costs money';

  @override
  String get lessonBuyUnknownAmount =>
      'This lesson is not covered by your membership. Booking it means you will be charged.';

  @override
  String get lessonBuyConfirm => 'Buy and book';

  @override
  String get actionDone => 'Done';

  @override
  String get actionFailed => 'Failed';

  @override
  String get back => 'Back';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get busyTitle => 'Busyness';

  @override
  String get busyEmpty => 'No busyness data.';

  @override
  String get busyWeek => 'Typical week';

  @override
  String get busyDay => 'Today by hour';

  @override
  String get moreNews => 'News';

  @override
  String get moreNotifications => 'Notifications';

  @override
  String get moreInvoices => 'Invoices';

  @override
  String get moreProfile => 'My details';

  @override
  String get moreMemberships => 'Memberships';

  @override
  String get moreFavourites => 'Favourite lessons';

  @override
  String get moreContact => 'Contact';

  @override
  String get moreRules => 'House rules';

  @override
  String get moreSync => 'Calendar sync';

  @override
  String get moreLocation => 'Change location';

  @override
  String get moreLogout => 'Sign out';

  @override
  String get moreAbout => 'About this app';

  @override
  String get listEmpty => 'Nothing to show.';

  @override
  String get invoiceOpen => 'Open PDF';

  @override
  String get invoiceMail => 'Email to me';

  @override
  String get profileAddress => 'Address';

  @override
  String get profileHouseNumber => 'House number';

  @override
  String get profileAddition => 'Addition';

  @override
  String get profileZip => 'Postcode';

  @override
  String get profileCity => 'City';

  @override
  String get profilePhone => 'Phone';

  @override
  String get profileMobile => 'Mobile';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileBalance => 'Balance';

  @override
  String get profileSaved => 'Details saved';

  @override
  String get membershipActive => 'Active';

  @override
  String get membershipInactive => 'Inactive';

  @override
  String get membershipUntil => 'Runs until';

  @override
  String get membershipVisitsLeft => 'Visits left';

  @override
  String get membershipCreditsLeft => 'Booking credits left';

  @override
  String get membershipUnlimited => 'Unlimited';

  @override
  String get membershipAddons => 'Add-ons';

  @override
  String get membershipReadOnly =>
      'Changing, freezing or cancelling a membership is only possible in the official app or at the desk.';

  @override
  String get addonOn => 'On';

  @override
  String get addonOff => 'Off';

  @override
  String get syncTarget => 'Sync to';

  @override
  String get syncOff => 'Off';

  @override
  String get syncDevice => 'Calendar on this device';

  @override
  String get syncDeviceHint =>
      'A calendar account on your phone, for example a Nextcloud calendar via DAVx5.';

  @override
  String get syncCalDav => 'CalDAV (Nextcloud)';

  @override
  String get syncCalDavHint => 'Straight to the server, without going through the device.';

  @override
  String get syncServerUrl => 'Server URL';

  @override
  String get syncServerUrlHint => 'https://cloud.example.org';

  @override
  String get syncUsername => 'Username';

  @override
  String get syncAppPassword => 'App password';

  @override
  String get syncAppPasswordHint =>
      'Create an app password in Nextcloud under Settings → Security. Do not use your normal password.';

  @override
  String get syncFindCalendars => 'Find calendars';

  @override
  String get syncChooseCalendar => 'Choose a calendar';

  @override
  String get syncNoCalendars => 'No writable calendars found.';

  @override
  String get syncCurrent => 'Current calendar';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncLastRun => 'Last sync';

  @override
  String get syncNever => 'Never';

  @override
  String get syncExplain =>
      'One way: your booked lessons appear in the calendar and disappear when cancelled. The app only touches events it created itself.';

  @override
  String get syncWebNeedsProxy =>
      'In the browser CalDAV only works if this site\'s administrator configured a Nextcloud server.';

  @override
  String syncResult(int created, int updated, int deleted) {
    return '$created new, $updated updated, $deleted removed';
  }

  @override
  String lessonSpotsFree(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots free',
      one: '1 spot free',
      zero: 'No spots free',
    );
    return '$_temp0';
  }

  @override
  String lessonGoing(int count) {
    return '$count going';
  }

  @override
  String lessonBuyAmount(String amount) {
    return 'This lesson is not covered by your membership and costs $amount.';
  }

  @override
  String get busyMorning => 'Morning';

  @override
  String get busyAfternoon => 'Afternoon';

  @override
  String get busyEvening => 'Evening';

  @override
  String get busyQuiet => 'Quiet';

  @override
  String get busyNormal => 'Average';

  @override
  String get busyBusy => 'Busy';

  @override
  String get busyWeekHint => 'Compared with the busiest moment of the week.';

  @override
  String get invoiceFilterAll => 'All';

  @override
  String get invoiceFilterOpen => 'Outstanding';

  @override
  String get invoicesNoneOpen => 'Everything is paid.';

  @override
  String get invoiceStatusOpen => 'Outstanding';

  @override
  String get invoiceStatusPaid => 'Paid';

  @override
  String invoicesOpenTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invoices outstanding',
      one: '1 invoice outstanding',
    );
    return '$_temp0';
  }

  @override
  String get invoiceFetching => 'Fetching PDF…';

  @override
  String invoiceSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get syncReminder => 'Reminder';

  @override
  String get syncReminderNone => 'None';

  @override
  String syncReminderMinutes(int minutes) {
    return '$minutes minutes before';
  }

  @override
  String get myLessonsUpcoming => 'Upcoming';

  @override
  String get myLessonsHistory => 'History';

  @override
  String get myLessonsHistoryEmpty => 'No earlier lessons found.';

  @override
  String get eventWaitingList => 'Note: you are on the waiting list.';

  @override
  String eventSpots(int max) {
    return 'Participants: at most $max';
  }

  @override
  String get moreSectionLessons => 'Lessons';

  @override
  String get moreSectionGym => 'Gym';

  @override
  String get moreSectionAccount => 'Account';

  @override
  String get moreSectionApp => 'App';

  @override
  String get lessonWhen => 'When';

  @override
  String get lessonParticipants => 'Participants';

  @override
  String get lessonAbout => 'About this lesson';

  @override
  String lessonGoingOfMax(int count, int max) {
    return '$count of $max going';
  }

  @override
  String get membershipPrice => 'Price';

  @override
  String get membershipLocation => 'Location';

  @override
  String get invoiceChartTitle => 'Per month';

  @override
  String invoiceChartTotal(String amount, int months) {
    return '$amount in the last $months months';
  }

  @override
  String get invoiceChartPaid => 'Paid';

  @override
  String get invoiceChartOpen => 'Outstanding';

  @override
  String get errorNotLoggedIn => 'You are not signed in.';

  @override
  String get errorLoginFailed => 'Sign-in failed.';

  @override
  String get errorTokenRejected => 'Signed in, but the server rejects the session.';

  @override
  String get errorNetwork => 'No connection to the server.';

  @override
  String errorServer(int status) {
    return 'The server returned an error ($status).';
  }

  @override
  String get errorLessonNotFound => 'Lesson not found.';

  @override
  String get errorNoPdf => 'No PDF received.';

  @override
  String get errorCalendarUnavailable => 'The calendar is not available.';

  @override
  String get errorCalendarPermission => 'No access to the device calendar.';

  @override
  String get errorCalendarAuth => 'The calendar server rejects the credentials.';

  @override
  String get errorCalendarNotFound => 'No CalDAV server found at this address.';

  @override
  String errorCalendarFailed(int status) {
    return 'The calendar server returned an error ($status).';
  }

  @override
  String get refresh => 'Refresh';

  @override
  String get photoChange => 'Change photo';

  @override
  String get photoCamera => 'Take a photo';

  @override
  String get photoGallery => 'Choose from gallery';

  @override
  String get photoFile => 'Choose a file';

  @override
  String get photoConfirmTitle => 'Use this photo?';

  @override
  String get photoConfirmBody =>
      'This replaces the ID photo your gym has of you. It may be used at the desk or the entrance gate to recognise you: pick a clear photo of your face.';

  @override
  String get photoUpload => 'Upload';

  @override
  String get photoUploaded => 'Photo updated';

  @override
  String get photoInvalid => 'This file is not an image that can be read.';

  @override
  String get errorUnexpected => 'Something unexpected went wrong. Please try again.';

  @override
  String errorRefreshFailed(String reason) {
    return 'Refresh failed: $reason';
  }

  @override
  String get demoBanner => 'Demo environment: made-up data, nothing is really booked.';

  @override
  String get offlineBanner => 'Offline: showing what was loaded earlier.';

  @override
  String syncFailedFor(String subject, String reason) {
    return '$subject: $reason';
  }

  @override
  String get syncRemoveFailed => 'Could not remove an event from the calendar';

  @override
  String get aboutTitle => 'About Managevity';

  @override
  String get aboutLink => 'About this app';

  @override
  String get aboutIntro =>
      'Book your gym classes and get them into your own calendar. An independent, open-source client for gyms that use Sportivity.';

  @override
  String get aboutFeatureDesktopTitle => 'Also on your computer';

  @override
  String get aboutFeatureDesktopBody =>
      'Not just a phone app: it runs on Android, on Linux, and in any browser on any computer. Same features everywhere, and wide screens get a layout that uses the space.';

  @override
  String get aboutFeaturePrivacyTitle => 'Privacy friendly';

  @override
  String get aboutFeaturePrivacyBody =>
      'No ads, no analytics, no tracking, and no server of our own: the app talks only to your gym\'s Sportivity server and, if you turn it on, to your own calendar. Your password is kept in your device\'s keychain and is never stored in a browser. The source code is open for anyone to check.';

  @override
  String get aboutFeatureCalendarTitle => 'Syncs to your calendar';

  @override
  String get aboutFeatureCalendarBody =>
      'Booked classes appear in your calendar and disappear when you cancel: straight to Nextcloud or any other CalDAV server, or to a calendar on your phone. With the trainer, the room, the address and an optional reminder. It only ever touches events it created itself.';

  @override
  String get aboutFeatureMoreTitle => 'And the rest';

  @override
  String get aboutFeatureMoreBody =>
      'Timetable with filters, waiting lists, favourites, your class history with who taught it, how busy the gym is, invoices as PDF with a monthly chart, your details and ID photo, news. Works offline with what was loaded earlier. Dutch and English, light and dark.';

  @override
  String get aboutDemoTitle => 'Try it without an account';

  @override
  String get aboutDemoBody =>
      'Sign in with username demo and password demo for a built-in demo with made-up data. Nothing is really booked.';

  @override
  String get aboutDemoButton => 'Open the demo';

  @override
  String get aboutLicences => 'Open-source licences';

  @override
  String get aboutSource => 'Free software under the GPL-3.0 licence.';

  @override
  String get aboutWebNote =>
      'In the web version, requests pass through the proxy of whoever hosts that website.';
}
