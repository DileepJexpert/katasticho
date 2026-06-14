import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

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
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi')
  ];

  /// Navigation label for dashboard
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Navigation label for sales orders
  ///
  /// In en, this message translates to:
  /// **'Sales Orders'**
  String get salesOrders;

  /// Navigation label for purchases
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get purchases;

  /// Navigation label for inventory
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// Navigation label for accounting
  ///
  /// In en, this message translates to:
  /// **'Accounting'**
  String get accounting;

  /// Navigation label for reports
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// Navigation label for settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Navigation label for contacts
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// Navigation label for items
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// Navigation label for point of sale
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get pos;

  /// Action button to create a new record
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Action button to save changes
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Action button to cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Action button to delete a record
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Action button to edit a record
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Action button to submit a form
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// Action button to approve
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// Action button to reject
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// Action button or hint for search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Action button to refresh data
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Action button to print
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get print;

  /// Action button to export data
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// Action button to close a dialog or screen
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Action button to go back
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Action button to go to next step
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Action button to go to previous step
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// Action button to confirm an action
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Action button to retry a failed operation
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Status label for draft records
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// Status label for sent records
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// Status label for paid records
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// Status label for overdue records
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// Status label for pending records
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Status label for approved records
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// Status label for rejected records
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// Status label for completed records
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// Status label for cancelled records
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// Status label for posted journal entries
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get posted;

  /// Status label for voided records
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get voided;

  /// Status label for records in progress
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// POS action to add item to cart
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// POS action to proceed to checkout
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// POS label for payment section
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// POS label for receipt
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receipt;

  /// POS label for customer field
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// POS label for discount
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// POS label for total amount
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// POS label for subtotal amount
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// POS label for tax amount
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get tax;

  /// POS label for change returned to customer
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// POS label for item quantity
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// POS label for item price
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// POS label for shopping cart
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// POS message when cart has no items
  ///
  /// In en, this message translates to:
  /// **'Cart is empty'**
  String get emptyCart;

  /// POS hint text for item search field
  ///
  /// In en, this message translates to:
  /// **'Search items'**
  String get searchItems;

  /// Common loading indicator label
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Common error label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Common message when there is no data to display
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// Common affirmative response
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// Common negative response
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Common confirmation button label
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Name of the application
  ///
  /// In en, this message translates to:
  /// **'Katasticho ERP'**
  String get appName;

  /// Common label for date picker button
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// Common label for date range start
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// Common label for date range end
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// Common label for monetary amount field
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// Common label for description field
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// Common label for notes field
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Common label for date field
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
