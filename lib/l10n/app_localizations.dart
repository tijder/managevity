import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_nl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('nl')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Managevity'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unofficial client for Sportivity'**
  String get appSubtitle;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Not affiliated with or endorsed by b.o.s.s. or Sportivity.'**
  String get disclaimer;

  /// No description provided for @loginUser.
  ///
  /// In en, this message translates to:
  /// **'Email or username'**
  String get loginUser;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginRemember.
  ///
  /// In en, this message translates to:
  /// **'Stay signed in'**
  String get loginRemember;

  /// No description provided for @loginRememberHint.
  ///
  /// In en, this message translates to:
  /// **'Stores your password in this device\'s keychain so an expired session renews itself.'**
  String get loginRememberHint;

  /// No description provided for @loginRememberWeb.
  ///
  /// In en, this message translates to:
  /// **'Your password is never stored in the browser.'**
  String get loginRememberWeb;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginButton;

  /// No description provided for @loginForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgot;

  /// No description provided for @loginForgotSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent. Check your email.'**
  String get loginForgotSent;

  /// No description provided for @loginForgotNeedsUser.
  ///
  /// In en, this message translates to:
  /// **'Enter your email or username first.'**
  String get loginForgotNeedsUser;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @locationTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your location'**
  String get locationTitle;

  /// No description provided for @locationNone.
  ///
  /// In en, this message translates to:
  /// **'No locations found.'**
  String get locationNone;

  /// No description provided for @tabSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get tabSchedule;

  /// No description provided for @tabMyLessons.
  ///
  /// In en, this message translates to:
  /// **'My lessons'**
  String get tabMyLessons;

  /// No description provided for @tabBusy.
  ///
  /// In en, this message translates to:
  /// **'Busyness'**
  String get tabBusy;

  /// No description provided for @tabMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tabMore;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @scheduleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No lessons on this day.'**
  String get scheduleEmpty;

  /// No description provided for @scheduleFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter by activity'**
  String get scheduleFilter;

  /// No description provided for @scheduleFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get scheduleFilterAll;

  /// No description provided for @myLessonsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have no booked lessons.'**
  String get myLessonsEmpty;

  /// No description provided for @lessonBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get lessonBook;

  /// No description provided for @lessonJoinWaitingList.
  ///
  /// In en, this message translates to:
  /// **'Join waiting list'**
  String get lessonJoinWaitingList;

  /// No description provided for @lessonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get lessonCancel;

  /// No description provided for @lessonCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel this booking?'**
  String get lessonCancelConfirm;

  /// No description provided for @lessonBooked.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get lessonBooked;

  /// No description provided for @lessonWaitingList.
  ///
  /// In en, this message translates to:
  /// **'Waiting list'**
  String get lessonWaitingList;

  /// No description provided for @lessonFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get lessonFull;

  /// No description provided for @lessonAttended.
  ///
  /// In en, this message translates to:
  /// **'Attended'**
  String get lessonAttended;

  /// No description provided for @lessonPast.
  ///
  /// In en, this message translates to:
  /// **'This lesson is over.'**
  String get lessonPast;

  /// No description provided for @lessonTrainer.
  ///
  /// In en, this message translates to:
  /// **'Trainer'**
  String get lessonTrainer;

  /// No description provided for @lessonRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get lessonRoom;

  /// No description provided for @lessonLike.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get lessonLike;

  /// No description provided for @lessonBuyTitle.
  ///
  /// In en, this message translates to:
  /// **'This lesson costs money'**
  String get lessonBuyTitle;

  /// No description provided for @lessonBuyUnknownAmount.
  ///
  /// In en, this message translates to:
  /// **'This lesson is not covered by your membership. Booking it means you will be charged.'**
  String get lessonBuyUnknownAmount;

  /// No description provided for @lessonBuyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Buy and book'**
  String get lessonBuyConfirm;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get actionFailed;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @busyTitle.
  ///
  /// In en, this message translates to:
  /// **'Busyness'**
  String get busyTitle;

  /// No description provided for @busyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No busyness data.'**
  String get busyEmpty;

  /// No description provided for @busyWeek.
  ///
  /// In en, this message translates to:
  /// **'Typical week'**
  String get busyWeek;

  /// No description provided for @busyDay.
  ///
  /// In en, this message translates to:
  /// **'Today by hour'**
  String get busyDay;

  /// No description provided for @moreNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get moreNews;

  /// No description provided for @moreNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get moreNotifications;

  /// No description provided for @moreInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get moreInvoices;

  /// No description provided for @moreProfile.
  ///
  /// In en, this message translates to:
  /// **'My details'**
  String get moreProfile;

  /// No description provided for @moreMemberships.
  ///
  /// In en, this message translates to:
  /// **'Memberships'**
  String get moreMemberships;

  /// No description provided for @moreFavourites.
  ///
  /// In en, this message translates to:
  /// **'Favourite lessons'**
  String get moreFavourites;

  /// No description provided for @moreContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get moreContact;

  /// No description provided for @moreRules.
  ///
  /// In en, this message translates to:
  /// **'House rules'**
  String get moreRules;

  /// No description provided for @moreSync.
  ///
  /// In en, this message translates to:
  /// **'Calendar sync'**
  String get moreSync;

  /// No description provided for @moreLocation.
  ///
  /// In en, this message translates to:
  /// **'Change location'**
  String get moreLocation;

  /// No description provided for @moreLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get moreLogout;

  /// No description provided for @moreAbout.
  ///
  /// In en, this message translates to:
  /// **'About this app'**
  String get moreAbout;

  /// No description provided for @listEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show.'**
  String get listEmpty;

  /// No description provided for @invoiceOpen.
  ///
  /// In en, this message translates to:
  /// **'Open PDF'**
  String get invoiceOpen;

  /// No description provided for @invoiceMail.
  ///
  /// In en, this message translates to:
  /// **'Email to me'**
  String get invoiceMail;

  /// No description provided for @profileAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get profileAddress;

  /// No description provided for @profileHouseNumber.
  ///
  /// In en, this message translates to:
  /// **'House number'**
  String get profileHouseNumber;

  /// No description provided for @profileAddition.
  ///
  /// In en, this message translates to:
  /// **'Addition'**
  String get profileAddition;

  /// No description provided for @profileZip.
  ///
  /// In en, this message translates to:
  /// **'Postcode'**
  String get profileZip;

  /// No description provided for @profileCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileCity;

  /// No description provided for @profilePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profilePhone;

  /// No description provided for @profileMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get profileMobile;

  /// No description provided for @profileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// No description provided for @profileBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get profileBalance;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Details saved'**
  String get profileSaved;

  /// No description provided for @membershipActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get membershipActive;

  /// No description provided for @membershipInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get membershipInactive;

  /// No description provided for @membershipUntil.
  ///
  /// In en, this message translates to:
  /// **'Runs until'**
  String get membershipUntil;

  /// No description provided for @membershipVisitsLeft.
  ///
  /// In en, this message translates to:
  /// **'Visits left'**
  String get membershipVisitsLeft;

  /// No description provided for @membershipCreditsLeft.
  ///
  /// In en, this message translates to:
  /// **'Booking credits left'**
  String get membershipCreditsLeft;

  /// No description provided for @membershipUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get membershipUnlimited;

  /// No description provided for @membershipAddons.
  ///
  /// In en, this message translates to:
  /// **'Add-ons'**
  String get membershipAddons;

  /// No description provided for @membershipReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Freezing, cancelling and withdrawing are requests to your gym; it confirms them. Taking out or converting a membership goes through your gym.'**
  String get membershipReadOnly;

  /// No description provided for @addonOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get addonOn;

  /// No description provided for @addonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get addonOff;

  /// No description provided for @syncTarget.
  ///
  /// In en, this message translates to:
  /// **'Sync to'**
  String get syncTarget;

  /// No description provided for @syncOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get syncOff;

  /// No description provided for @syncDevice.
  ///
  /// In en, this message translates to:
  /// **'Calendar on this device'**
  String get syncDevice;

  /// No description provided for @syncDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'A calendar account on your phone, for example a Nextcloud calendar via DAVx5.'**
  String get syncDeviceHint;

  /// No description provided for @syncCalDav.
  ///
  /// In en, this message translates to:
  /// **'CalDAV (Nextcloud)'**
  String get syncCalDav;

  /// No description provided for @syncCalDavHint.
  ///
  /// In en, this message translates to:
  /// **'Straight to the server, without going through the device.'**
  String get syncCalDavHint;

  /// No description provided for @syncServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get syncServerUrl;

  /// No description provided for @syncServerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://cloud.example.org'**
  String get syncServerUrlHint;

  /// No description provided for @syncUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get syncUsername;

  /// No description provided for @syncAppPassword.
  ///
  /// In en, this message translates to:
  /// **'App password'**
  String get syncAppPassword;

  /// No description provided for @syncAppPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Create an app password in Nextcloud under Settings → Security. Do not use your normal password.'**
  String get syncAppPasswordHint;

  /// No description provided for @syncFindCalendars.
  ///
  /// In en, this message translates to:
  /// **'Find calendars'**
  String get syncFindCalendars;

  /// No description provided for @syncChooseCalendar.
  ///
  /// In en, this message translates to:
  /// **'Choose a calendar'**
  String get syncChooseCalendar;

  /// No description provided for @syncNoCalendars.
  ///
  /// In en, this message translates to:
  /// **'No writable calendars found.'**
  String get syncNoCalendars;

  /// No description provided for @syncCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current calendar'**
  String get syncCurrent;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncLastRun.
  ///
  /// In en, this message translates to:
  /// **'Last sync'**
  String get syncLastRun;

  /// No description provided for @syncNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get syncNever;

  /// No description provided for @syncExplain.
  ///
  /// In en, this message translates to:
  /// **'One way: your booked lessons appear in the calendar and disappear when cancelled. The app only touches events it created itself.'**
  String get syncExplain;

  /// No description provided for @syncWebNeedsProxy.
  ///
  /// In en, this message translates to:
  /// **'In the browser CalDAV only works if this site\'s administrator configured a Nextcloud server.'**
  String get syncWebNeedsProxy;

  /// No description provided for @syncResult.
  ///
  /// In en, this message translates to:
  /// **'{created} new, {updated} updated, {deleted} removed'**
  String syncResult(int created, int updated, int deleted);

  /// No description provided for @lessonSpotsFree.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No spots free} =1{1 spot free} other{{count} spots free}}'**
  String lessonSpotsFree(int count);

  /// How many people have booked the lesson.
  ///
  /// In en, this message translates to:
  /// **'{count} going'**
  String lessonGoing(int count);

  /// No description provided for @lessonBuyAmount.
  ///
  /// In en, this message translates to:
  /// **'This lesson is not covered by your membership and costs {amount}.'**
  String lessonBuyAmount(String amount);

  /// No description provided for @busyMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get busyMorning;

  /// No description provided for @busyAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get busyAfternoon;

  /// No description provided for @busyEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get busyEvening;

  /// No description provided for @busyQuiet.
  ///
  /// In en, this message translates to:
  /// **'Quiet'**
  String get busyQuiet;

  /// No description provided for @busyNormal.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get busyNormal;

  /// No description provided for @busyBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get busyBusy;

  /// No description provided for @busyWeekHint.
  ///
  /// In en, this message translates to:
  /// **'Compared with the busiest moment of the week.'**
  String get busyWeekHint;

  /// No description provided for @invoiceFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get invoiceFilterAll;

  /// No description provided for @invoiceFilterOpen.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get invoiceFilterOpen;

  /// No description provided for @invoicesNoneOpen.
  ///
  /// In en, this message translates to:
  /// **'Everything is paid.'**
  String get invoicesNoneOpen;

  /// No description provided for @invoiceStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get invoiceStatusOpen;

  /// No description provided for @invoiceStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get invoiceStatusPaid;

  /// No description provided for @invoicesOpenTotal.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 invoice outstanding} other{{count} invoices outstanding}}'**
  String invoicesOpenTotal(int count);

  /// No description provided for @invoiceFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching PDF…'**
  String get invoiceFetching;

  /// No description provided for @invoiceSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String invoiceSavedTo(String path);

  /// No description provided for @syncReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get syncReminder;

  /// No description provided for @syncReminderNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get syncReminderNone;

  /// No description provided for @syncReminderMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes before'**
  String syncReminderMinutes(int minutes);

  /// No description provided for @myLessonsUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get myLessonsUpcoming;

  /// No description provided for @myLessonsHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get myLessonsHistory;

  /// No description provided for @myLessonsHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No earlier lessons found.'**
  String get myLessonsHistoryEmpty;

  /// No description provided for @eventWaitingList.
  ///
  /// In en, this message translates to:
  /// **'Note: you are on the waiting list.'**
  String get eventWaitingList;

  /// No description provided for @eventSpots.
  ///
  /// In en, this message translates to:
  /// **'Participants: at most {max}'**
  String eventSpots(int max);

  /// No description provided for @moreSectionLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get moreSectionLessons;

  /// No description provided for @moreSectionGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get moreSectionGym;

  /// No description provided for @moreSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get moreSectionAccount;

  /// No description provided for @moreSectionApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get moreSectionApp;

  /// No description provided for @lessonWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get lessonWhen;

  /// No description provided for @lessonParticipants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get lessonParticipants;

  /// No description provided for @lessonAbout.
  ///
  /// In en, this message translates to:
  /// **'About this lesson'**
  String get lessonAbout;

  /// How many people have booked the lesson, out of the maximum.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} going'**
  String lessonGoingOfMax(int count, int max);

  /// No description provided for @membershipPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get membershipPrice;

  /// No description provided for @membershipLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get membershipLocation;

  /// No description provided for @invoiceChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Per month'**
  String get invoiceChartTitle;

  /// No description provided for @invoiceChartTotal.
  ///
  /// In en, this message translates to:
  /// **'{amount} in the last {months} months'**
  String invoiceChartTotal(String amount, int months);

  /// No description provided for @invoiceChartPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get invoiceChartPaid;

  /// No description provided for @invoiceChartOpen.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get invoiceChartOpen;

  /// No description provided for @errorNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'You are not signed in.'**
  String get errorNotLoggedIn;

  /// No description provided for @errorLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed.'**
  String get errorLoginFailed;

  /// No description provided for @errorTokenRejected.
  ///
  /// In en, this message translates to:
  /// **'Signed in, but the server rejects the session.'**
  String get errorTokenRejected;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server.'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'The server returned an error ({status}).'**
  String errorServer(int status);

  /// No description provided for @errorLessonNotFound.
  ///
  /// In en, this message translates to:
  /// **'Lesson not found.'**
  String get errorLessonNotFound;

  /// No description provided for @errorNoPdf.
  ///
  /// In en, this message translates to:
  /// **'No PDF received.'**
  String get errorNoPdf;

  /// No description provided for @errorCalendarUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The calendar is not available.'**
  String get errorCalendarUnavailable;

  /// No description provided for @errorCalendarPermission.
  ///
  /// In en, this message translates to:
  /// **'No access to the device calendar.'**
  String get errorCalendarPermission;

  /// No description provided for @errorCalendarAuth.
  ///
  /// In en, this message translates to:
  /// **'The calendar server rejects the credentials.'**
  String get errorCalendarAuth;

  /// No description provided for @errorCalendarNotFound.
  ///
  /// In en, this message translates to:
  /// **'No CalDAV server found at this address.'**
  String get errorCalendarNotFound;

  /// No description provided for @errorCalendarFailed.
  ///
  /// In en, this message translates to:
  /// **'The calendar server returned an error ({status}).'**
  String errorCalendarFailed(int status);

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @photoChange.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get photoChange;

  /// No description provided for @photoCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get photoCamera;

  /// No description provided for @photoGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get photoGallery;

  /// No description provided for @photoFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get photoFile;

  /// No description provided for @photoConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Use this photo?'**
  String get photoConfirmTitle;

  /// No description provided for @photoConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This replaces the ID photo your gym has of you. It may be used at the desk or the entrance gate to recognise you: pick a clear photo of your face.'**
  String get photoConfirmBody;

  /// No description provided for @photoUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get photoUpload;

  /// No description provided for @photoUploaded.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get photoUploaded;

  /// No description provided for @photoInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file is not an image that can be read.'**
  String get photoInvalid;

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Something unexpected went wrong. Please try again.'**
  String get errorUnexpected;

  /// No description provided for @errorRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed: {reason}'**
  String errorRefreshFailed(String reason);

  /// No description provided for @demoBanner.
  ///
  /// In en, this message translates to:
  /// **'Demo environment: made-up data, nothing is really booked.'**
  String get demoBanner;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'Offline: showing what was loaded earlier.'**
  String get offlineBanner;

  /// No description provided for @syncFailedFor.
  ///
  /// In en, this message translates to:
  /// **'{subject}: {reason}'**
  String syncFailedFor(String subject, String reason);

  /// No description provided for @syncRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove an event from the calendar'**
  String get syncRemoveFailed;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Managevity'**
  String get aboutTitle;

  /// No description provided for @aboutLink.
  ///
  /// In en, this message translates to:
  /// **'About this app'**
  String get aboutLink;

  /// No description provided for @aboutIntro.
  ///
  /// In en, this message translates to:
  /// **'Book your gym classes and get them into your own calendar. An independent, open-source client for gyms that use Sportivity.'**
  String get aboutIntro;

  /// No description provided for @aboutFeatureDesktopTitle.
  ///
  /// In en, this message translates to:
  /// **'Also on your computer'**
  String get aboutFeatureDesktopTitle;

  /// No description provided for @aboutFeatureDesktopBody.
  ///
  /// In en, this message translates to:
  /// **'Not just a phone app: it runs on Android, on Linux, and in any browser on any computer. Same features everywhere, and wide screens get a layout that uses the space.'**
  String get aboutFeatureDesktopBody;

  /// No description provided for @aboutFeaturePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy friendly'**
  String get aboutFeaturePrivacyTitle;

  /// No description provided for @aboutFeaturePrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'No ads, no analytics, no tracking, and no server of our own: the app talks only to your gym\'s Sportivity server and, if you turn it on, to your own calendar. Your password is kept in your device\'s keychain and is never stored in a browser. The source code is open for anyone to check.'**
  String get aboutFeaturePrivacyBody;

  /// No description provided for @aboutFeatureCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Syncs to your calendar'**
  String get aboutFeatureCalendarTitle;

  /// No description provided for @aboutFeatureCalendarBody.
  ///
  /// In en, this message translates to:
  /// **'Booked classes appear in your calendar and disappear when you cancel: straight to Nextcloud or any other CalDAV server, or to a calendar on your phone. With the trainer, the room, the address and an optional reminder. It only ever touches events it created itself.'**
  String get aboutFeatureCalendarBody;

  /// No description provided for @aboutFeatureMoreTitle.
  ///
  /// In en, this message translates to:
  /// **'And the rest'**
  String get aboutFeatureMoreTitle;

  /// No description provided for @aboutFeatureMoreBody.
  ///
  /// In en, this message translates to:
  /// **'Timetable with filters, waiting lists, favourites, your class history with who taught it, how busy the gym is, invoices as PDF with a monthly chart, your details and ID photo, news. Works offline with what was loaded earlier. Dutch and English, light and dark.'**
  String get aboutFeatureMoreBody;

  /// No description provided for @aboutDemoTitle.
  ///
  /// In en, this message translates to:
  /// **'Try it without an account'**
  String get aboutDemoTitle;

  /// No description provided for @aboutDemoBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in with username demo and password demo for a built-in demo with made-up data. Nothing is really booked.'**
  String get aboutDemoBody;

  /// No description provided for @aboutDemoButton.
  ///
  /// In en, this message translates to:
  /// **'Open the demo'**
  String get aboutDemoButton;

  /// No description provided for @aboutLicences.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get aboutLicences;

  /// No description provided for @aboutSource.
  ///
  /// In en, this message translates to:
  /// **'Free software under the GPL-3.0 licence.'**
  String get aboutSource;

  /// No description provided for @aboutWebNote.
  ///
  /// In en, this message translates to:
  /// **'In the web version, requests pass through the proxy of whoever hosts that website.'**
  String get aboutWebNote;

  /// No description provided for @confirmSureTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get confirmSureTitle;

  /// No description provided for @confirmIrreversible.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone from the app.'**
  String get confirmIrreversible;

  /// No description provided for @moreGuests.
  ///
  /// In en, this message translates to:
  /// **'Guests'**
  String get moreGuests;

  /// No description provided for @guestsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No guests signed up.'**
  String get guestsEmpty;

  /// No description provided for @guestsNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You cannot bring a guest right now.'**
  String get guestsNotAllowed;

  /// No description provided for @guestAdd.
  ///
  /// In en, this message translates to:
  /// **'Sign up a guest'**
  String get guestAdd;

  /// No description provided for @guestName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get guestName;

  /// No description provided for @guestNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get guestNameRequired;

  /// No description provided for @guestEmail.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get guestEmail;

  /// No description provided for @guestMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile (optional)'**
  String get guestMobile;

  /// No description provided for @guestDate.
  ///
  /// In en, this message translates to:
  /// **'Date of visit'**
  String get guestDate;

  /// No description provided for @guestAddConfirm.
  ///
  /// In en, this message translates to:
  /// **'{name} is signed up as your guest for {date}.'**
  String guestAddConfirm(String name, String date);

  /// No description provided for @guestRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get guestRemove;

  /// No description provided for @guestRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from your guests?'**
  String guestRemoveConfirm(String name);

  /// No description provided for @guestVisited.
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get guestVisited;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @profileLookup.
  ///
  /// In en, this message translates to:
  /// **'Look up address'**
  String get profileLookup;

  /// No description provided for @profileLookupNotFound.
  ///
  /// In en, this message translates to:
  /// **'No address found for this postcode and house number.'**
  String get profileLookupNotFound;

  /// No description provided for @profileGymTitle.
  ///
  /// In en, this message translates to:
  /// **'Your gym and you'**
  String get profileGymTitle;

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language of messages from your gym'**
  String get profileLanguage;

  /// No description provided for @profileLanguageSaved.
  ///
  /// In en, this message translates to:
  /// **'The gym will write to you in {language}.'**
  String profileLanguageSaved(String language);

  /// The name of a language code the gym uses.
  ///
  /// In en, this message translates to:
  /// **'{code, select, nl_NL{Dutch} en_GB{English} other{{code}}}'**
  String languageName(String code);

  /// No description provided for @optInTitle.
  ///
  /// In en, this message translates to:
  /// **'Your gym may contact you by'**
  String get optInTitle;

  /// No description provided for @optInEmail.
  ///
  /// In en, this message translates to:
  /// **'Email and newsletters'**
  String get optInEmail;

  /// No description provided for @optInCalls.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get optInCalls;

  /// No description provided for @optInWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get optInWhatsapp;

  /// No description provided for @optInSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved: {what} {state, select, on{on} other{off}}.'**
  String optInSaved(String what, String state);

  /// No description provided for @balanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get balanceTitle;

  /// No description provided for @balanceTopUp.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get balanceTopUp;

  /// No description provided for @balanceTopUpChoose.
  ///
  /// In en, this message translates to:
  /// **'How much do you want to add?'**
  String get balanceTopUpChoose;

  /// No description provided for @balanceTopUpConfirm.
  ///
  /// In en, this message translates to:
  /// **'You top up your credit by {amount}.'**
  String balanceTopUpConfirm(String amount);

  /// No description provided for @paymentInBrowser.
  ///
  /// In en, this message translates to:
  /// **'You pay in your browser, on the payment page of your gym. Come back to the app afterwards.'**
  String get paymentInBrowser;

  /// No description provided for @paymentToPage.
  ///
  /// In en, this message translates to:
  /// **'To the payment page'**
  String get paymentToPage;

  /// No description provided for @paymentOpened.
  ///
  /// In en, this message translates to:
  /// **'Payment page opened. This screen refreshes when you come back.'**
  String get paymentOpened;

  /// No description provided for @paymentCouldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'The payment page could not be opened.'**
  String get paymentCouldNotOpen;

  /// No description provided for @invoicesPay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get invoicesPay;

  /// No description provided for @invoicesPayConfirm.
  ///
  /// In en, this message translates to:
  /// **'You pay the outstanding amount of {amount}.'**
  String invoicesPayConfirm(String amount);

  /// No description provided for @addonTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get addonTurnOn;

  /// No description provided for @addonTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get addonTurnOff;

  /// No description provided for @addonFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get addonFrom;

  /// No description provided for @addonConfirmOn.
  ///
  /// In en, this message translates to:
  /// **'{name} is turned on from {date}.'**
  String addonConfirmOn(String name, String date);

  /// No description provided for @addonConfirmOff.
  ///
  /// In en, this message translates to:
  /// **'{name} is turned off from {date}.'**
  String addonConfirmOff(String name, String date);

  /// No description provided for @addonPrice.
  ///
  /// In en, this message translates to:
  /// **'Price: {price}'**
  String addonPrice(String price);

  /// No description provided for @addonServerSays.
  ///
  /// In en, this message translates to:
  /// **'Your gym says:'**
  String get addonServerSays;

  /// No description provided for @addonMandatory.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get addonMandatory;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @membershipFreeze.
  ///
  /// In en, this message translates to:
  /// **'Freeze'**
  String get membershipFreeze;

  /// No description provided for @membershipCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel membership'**
  String get membershipCancel;

  /// No description provided for @membershipWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get membershipWithdraw;

  /// No description provided for @membershipTerminated.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get membershipTerminated;

  /// No description provided for @changeReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get changeReason;

  /// No description provided for @changeReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a reason'**
  String get changeReasonRequired;

  /// No description provided for @changeFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get changeFrom;

  /// No description provided for @changeUntil.
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get changeUntil;

  /// No description provided for @freezeConfirm.
  ///
  /// In en, this message translates to:
  /// **'{name} is frozen from {from} up to and including {until}.'**
  String freezeConfirm(String name, String from, String until);

  /// No description provided for @cancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'You cancel {name} as of {date}.'**
  String cancelConfirm(String name, String date);

  /// No description provided for @withdrawConfirm.
  ///
  /// In en, this message translates to:
  /// **'You use your right of withdrawal for {name}: the membership is dissolved.'**
  String withdrawConfirm(String name);

  /// No description provided for @changeReasonLine.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String changeReasonLine(String reason);

  /// No description provided for @changeIsRequest.
  ///
  /// In en, this message translates to:
  /// **'This is a request to your gym, which confirms it.'**
  String get changeIsRequest;

  /// No description provided for @changeSend.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get changeSend;

  /// No description provided for @moreOffers.
  ///
  /// In en, this message translates to:
  /// **'Memberships on offer'**
  String get moreOffers;

  /// No description provided for @offersSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch membership'**
  String get offersSwitchTitle;

  /// No description provided for @membershipSeeSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch options'**
  String get membershipSeeSwitch;

  /// No description provided for @offerPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment: {method}'**
  String offerPaymentMethod(String method);

  /// No description provided for @offerPromotion.
  ///
  /// In en, this message translates to:
  /// **'Promotion'**
  String get offerPromotion;

  /// No description provided for @offerStartToday.
  ///
  /// In en, this message translates to:
  /// **'When starting today'**
  String get offerStartToday;

  /// No description provided for @offerTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get offerTotal;

  /// No description provided for @offerConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get offerConditions;

  /// No description provided for @offerRequired.
  ///
  /// In en, this message translates to:
  /// **'required'**
  String get offerRequired;

  /// No description provided for @offerIbanRequired.
  ///
  /// In en, this message translates to:
  /// **'A bank account (IBAN) is required.'**
  String get offerIbanRequired;

  /// No description provided for @offerViaGym.
  ///
  /// In en, this message translates to:
  /// **'Taking out this membership, or switching to it, goes through your gym.'**
  String get offerViaGym;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'nl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'nl':
      return AppLocalizationsNl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
