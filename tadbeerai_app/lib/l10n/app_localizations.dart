import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('ur'),
    Locale.fromSubtags(languageCode: 'ur', scriptCode: 'Latn')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Tadbeer AI'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your AI-Powered Financial Intelligence Companion'**
  String get tagline;

  /// No description provided for @corePromise.
  ///
  /// In en, this message translates to:
  /// **'Understand your money. Understand the economy. Plan with confidence.'**
  String get corePromise;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingTitleUnderstand.
  ///
  /// In en, this message translates to:
  /// **'Understand'**
  String get onboardingTitleUnderstand;

  /// No description provided for @onboardingDescUnderstand.
  ///
  /// In en, this message translates to:
  /// **'See your money and Pakistan\'s economy in one place — inflation, exchange rates and policy changes, explained simply.'**
  String get onboardingDescUnderstand;

  /// No description provided for @onboardingTitleManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get onboardingTitleManage;

  /// No description provided for @onboardingDescManage.
  ///
  /// In en, this message translates to:
  /// **'Track income, expenses, budgets and goals with a clear Financial Health Score built from your real numbers.'**
  String get onboardingDescManage;

  /// No description provided for @onboardingTitlePlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get onboardingTitlePlan;

  /// No description provided for @onboardingDescPlan.
  ///
  /// In en, this message translates to:
  /// **'Run what-if scenarios and get AI guidance to plan with confidence — never guess again.'**
  String get onboardingDescPlan;

  /// No description provided for @loginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your financial journey.'**
  String get loginSubtitle;

  /// No description provided for @signupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signupTitle;

  /// No description provided for @signupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start understanding your money today.'**
  String get signupSubtitle;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @fieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fieldFullName;

  /// No description provided for @fieldConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get fieldConfirmPassword;

  /// No description provided for @actionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get actionSignIn;

  /// No description provided for @actionCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get actionCreateAccount;

  /// No description provided for @loginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get loginNoAccount;

  /// No description provided for @loginHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get loginHaveAccount;

  /// No description provided for @authDemoNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — accounts are stored locally on this device.'**
  String get authDemoNote;

  /// No description provided for @validationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get validationNameRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get validationEmailInvalid;

  /// No description provided for @validationPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get validationPasswordShort;

  /// No description provided for @validationPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get validationPasswordMismatch;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get tabFinance;

  /// No description provided for @tabEconomy.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get tabEconomy;

  /// No description provided for @tabMarket.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get tabMarket;

  /// No description provided for @tabAskTadbeer.
  ///
  /// In en, this message translates to:
  /// **'Ask Tadbeer'**
  String get tabAskTadbeer;

  /// No description provided for @homeSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Your financial home'**
  String get homeSectionTitle;

  /// No description provided for @homeSectionBody.
  ///
  /// In en, this message translates to:
  /// **'Your daily overview — health score, spending summary, budget progress and the economic pulse that matters to you.'**
  String get homeSectionBody;

  /// No description provided for @financeSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Your money, organized'**
  String get financeSectionTitle;

  /// No description provided for @financeSectionBody.
  ///
  /// In en, this message translates to:
  /// **'Income, expenses, budgets and goals with charts that show exactly where your money goes.'**
  String get financeSectionBody;

  /// No description provided for @economySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Economic Pulse'**
  String get economySectionTitle;

  /// No description provided for @economySectionBody.
  ///
  /// In en, this message translates to:
  /// **'Inflation, USD/PKR, policy rate and more — clearly sourced, with what each change means for you.'**
  String get economySectionBody;

  /// No description provided for @marketSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Market intelligence'**
  String get marketSectionTitle;

  /// No description provided for @marketSectionBody.
  ///
  /// In en, this message translates to:
  /// **'PSX indices, watchlists and market movers explained — intelligence, not trading.'**
  String get marketSectionBody;

  /// No description provided for @askSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask Tadbeer'**
  String get askSectionTitle;

  /// No description provided for @askSectionBody.
  ///
  /// In en, this message translates to:
  /// **'Your AI financial companion — ask about inflation, your budget, savings goals or anything money.'**
  String get askSectionBody;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String greetingMorning(String name);

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String greetingAfternoon(String name);

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String greetingEvening(String name);

  /// No description provided for @demoDataBadge.
  ///
  /// In en, this message translates to:
  /// **'Demo data'**
  String get demoDataBadge;

  /// No description provided for @healthScoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Health'**
  String get healthScoreTitle;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @savings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get savings;

  /// No description provided for @budgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetLabel;

  /// No description provided for @budgetUsedOf.
  ///
  /// In en, this message translates to:
  /// **'{spent} of {limit} used'**
  String budgetUsedOf(String spent, String limit);

  /// No description provided for @savingsTrend.
  ///
  /// In en, this message translates to:
  /// **'Savings trend'**
  String get savingsTrend;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get recentTransactions;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @goalProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal progress'**
  String get goalProgressTitle;

  /// No description provided for @insightTitle.
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get insightTitle;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @actionAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get actionAddExpense;

  /// No description provided for @actionAddIncome.
  ///
  /// In en, this message translates to:
  /// **'Add income'**
  String get actionAddIncome;

  /// No description provided for @actionNewGoal.
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get actionNewGoal;

  /// No description provided for @actionViewFinances.
  ///
  /// In en, this message translates to:
  /// **'My finances'**
  String get actionViewFinances;

  /// No description provided for @monthsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} months left'**
  String monthsLeft(int count);

  /// No description provided for @goalReached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached'**
  String get goalReached;

  /// No description provided for @onTrackLabel.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get onTrackLabel;

  /// No description provided for @overBudgetShort.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get overBudgetShort;

  /// No description provided for @financialHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Health'**
  String get financialHealthTitle;

  /// No description provided for @ratingExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get ratingExcellent;

  /// No description provided for @ratingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get ratingGood;

  /// No description provided for @ratingFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get ratingFair;

  /// No description provided for @ratingNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get ratingNeedsAttention;

  /// No description provided for @componentSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings behavior'**
  String get componentSavings;

  /// No description provided for @componentBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget discipline'**
  String get componentBudget;

  /// No description provided for @componentEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency fund'**
  String get componentEmergency;

  /// No description provided for @componentGoals.
  ///
  /// In en, this message translates to:
  /// **'Goal progress'**
  String get componentGoals;

  /// No description provided for @componentSpending.
  ///
  /// In en, this message translates to:
  /// **'Spending behavior'**
  String get componentSpending;

  /// No description provided for @healthWeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight: {weight}%'**
  String healthWeightLabel(String weight);

  /// No description provided for @healthDetailSavings.
  ///
  /// In en, this message translates to:
  /// **'You save {rate}% of your income.'**
  String healthDetailSavings(String rate);

  /// No description provided for @healthDetailBudget.
  ///
  /// In en, this message translates to:
  /// **'{onTrack} of {total} budgets on track.'**
  String healthDetailBudget(String onTrack, String total);

  /// No description provided for @healthDetailEmergency.
  ///
  /// In en, this message translates to:
  /// **'Your savings cover {months} months of expenses.'**
  String healthDetailEmergency(String months);

  /// No description provided for @healthDetailGoals.
  ///
  /// In en, this message translates to:
  /// **'Average progress across goals: {percent}%.'**
  String healthDetailGoals(String percent);

  /// No description provided for @healthDetailSpending.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of your income goes to wants.'**
  String healthDetailSpending(String percent);

  /// No description provided for @howScoreWorks.
  ///
  /// In en, this message translates to:
  /// **'How this score works'**
  String get howScoreWorks;

  /// No description provided for @howScoreWorksBody.
  ///
  /// In en, this message translates to:
  /// **'Your score is calculated deterministically from your finances — savings rate, budget discipline, emergency fund coverage, goal progress and spending mix. No AI is involved in the math; the same inputs always produce the same score.'**
  String get howScoreWorksBody;

  /// No description provided for @navHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Health'**
  String get navHealthTitle;

  /// No description provided for @navHealthDesc.
  ///
  /// In en, this message translates to:
  /// **'Your score and what drives it'**
  String get navHealthDesc;

  /// No description provided for @navMyFinancesTitle.
  ///
  /// In en, this message translates to:
  /// **'My Finances'**
  String get navMyFinancesTitle;

  /// No description provided for @navMyFinancesDesc.
  ///
  /// In en, this message translates to:
  /// **'Income, expenses and trends'**
  String get navMyFinancesDesc;

  /// No description provided for @navExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get navExpensesTitle;

  /// No description provided for @navExpensesDesc.
  ///
  /// In en, this message translates to:
  /// **'Track every transaction'**
  String get navExpensesDesc;

  /// No description provided for @navBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget Planner'**
  String get navBudgetTitle;

  /// No description provided for @navBudgetDesc.
  ///
  /// In en, this message translates to:
  /// **'Category limits and alerts'**
  String get navBudgetDesc;

  /// No description provided for @navGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get navGoalsTitle;

  /// No description provided for @navGoalsDesc.
  ///
  /// In en, this message translates to:
  /// **'Save with a purpose'**
  String get navGoalsDesc;

  /// No description provided for @monthlySummary.
  ///
  /// In en, this message translates to:
  /// **'Monthly summary'**
  String get monthlySummary;

  /// No description provided for @categoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Category breakdown'**
  String get categoryBreakdown;

  /// No description provided for @spendingTrend.
  ///
  /// In en, this message translates to:
  /// **'Spending trend'**
  String get spendingTrend;

  /// No description provided for @availableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available balance'**
  String get availableBalance;

  /// No description provided for @totalIncome.
  ///
  /// In en, this message translates to:
  /// **'Total income'**
  String get totalIncome;

  /// No description provided for @totalExpenses.
  ///
  /// In en, this message translates to:
  /// **'Total expenses'**
  String get totalExpenses;

  /// No description provided for @resetDemoData.
  ///
  /// In en, this message translates to:
  /// **'Reset demo data'**
  String get resetDemoData;

  /// No description provided for @resetDemoDataDone.
  ///
  /// In en, this message translates to:
  /// **'Demo data restored.'**
  String get resetDemoDataDone;

  /// No description provided for @incomeVsExpenses.
  ///
  /// In en, this message translates to:
  /// **'Income vs expenses'**
  String get incomeVsExpenses;

  /// No description provided for @searchTransactions.
  ///
  /// In en, this message translates to:
  /// **'Search transactions'**
  String get searchTransactions;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get filterIncome;

  /// No description provided for @filterExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get filterExpense;

  /// No description provided for @noTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactionsTitle;

  /// No description provided for @noTransactionsBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first transaction to start tracking your money.'**
  String get noTransactionsBody;

  /// No description provided for @addTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add transaction'**
  String get addTransactionTitle;

  /// No description provided for @editTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get editTransactionTitle;

  /// No description provided for @deleteTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete transaction'**
  String get deleteTransactionTitle;

  /// No description provided for @deleteTransactionBody.
  ///
  /// In en, this message translates to:
  /// **'This transaction will be removed from your demo data.'**
  String get deleteTransactionBody;

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @fieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fieldAmount;

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @fieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldDate;

  /// No description provided for @fieldNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get fieldNote;

  /// No description provided for @validationTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title.'**
  String get validationTitleRequired;

  /// No description provided for @validationAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than 0.'**
  String get validationAmountInvalid;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @noResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noResultsTitle;

  /// No description provided for @noResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or filter.'**
  String get noResultsBody;

  /// No description provided for @monthlyBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly budget'**
  String get monthlyBudgetTitle;

  /// No description provided for @spentLabel.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spentLabel;

  /// No description provided for @remainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remainingLabel;

  /// No description provided for @overByLabel.
  ///
  /// In en, this message translates to:
  /// **'Over by {amount}'**
  String overByLabel(String amount);

  /// No description provided for @addBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add budget'**
  String get addBudgetTitle;

  /// No description provided for @editBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit budget'**
  String get editBudgetTitle;

  /// No description provided for @fieldMonthlyLimit.
  ///
  /// In en, this message translates to:
  /// **'Monthly limit'**
  String get fieldMonthlyLimit;

  /// No description provided for @validationLimitInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a limit greater than 0.'**
  String get validationLimitInvalid;

  /// No description provided for @noBudgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'No budgets yet'**
  String get noBudgetsTitle;

  /// No description provided for @noBudgetsBody.
  ///
  /// In en, this message translates to:
  /// **'Set category limits to keep your spending on track.'**
  String get noBudgetsBody;

  /// No description provided for @deleteBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete budget'**
  String get deleteBudgetTitle;

  /// No description provided for @deleteBudgetBody.
  ///
  /// In en, this message translates to:
  /// **'This category limit will be removed from your demo data.'**
  String get deleteBudgetBody;

  /// No description provided for @totalBudgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalBudgetLabel;

  /// No description provided for @budgetOnTrackDesc.
  ///
  /// In en, this message translates to:
  /// **'{onTrack} of {total} categories on track'**
  String budgetOnTrackDesc(String onTrack, String total);

  /// No description provided for @savedLabel.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedLabel;

  /// No description provided for @targetLabel.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get targetLabel;

  /// No description provided for @targetDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Target date'**
  String get targetDateLabel;

  /// No description provided for @requiredMonthlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Save {amount} per month to finish on time'**
  String requiredMonthlyLabel(String amount);

  /// No description provided for @addGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get addGoalTitle;

  /// No description provided for @editGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get editGoalTitle;

  /// No description provided for @fieldGoalName.
  ///
  /// In en, this message translates to:
  /// **'Goal name'**
  String get fieldGoalName;

  /// No description provided for @fieldTargetAmount.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get fieldTargetAmount;

  /// No description provided for @fieldSavedAmount.
  ///
  /// In en, this message translates to:
  /// **'Already saved'**
  String get fieldSavedAmount;

  /// No description provided for @validationTargetInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a target greater than 0.'**
  String get validationTargetInvalid;

  /// No description provided for @validationSavedExceeds.
  ///
  /// In en, this message translates to:
  /// **'Saved amount can\'t exceed the target.'**
  String get validationSavedExceeds;

  /// No description provided for @noGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'No goals yet'**
  String get noGoalsTitle;

  /// No description provided for @noGoalsBody.
  ///
  /// In en, this message translates to:
  /// **'Create a savings goal to see your progress grow.'**
  String get noGoalsBody;

  /// No description provided for @deleteGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete goal'**
  String get deleteGoalTitle;

  /// No description provided for @deleteGoalBody.
  ///
  /// In en, this message translates to:
  /// **'This goal will be removed from your demo data.'**
  String get deleteGoalBody;

  /// No description provided for @addFundsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add funds'**
  String get addFundsTitle;

  /// No description provided for @fieldAmountToAdd.
  ///
  /// In en, this message translates to:
  /// **'Amount to add'**
  String get fieldAmountToAdd;

  /// No description provided for @goalIconLabel.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get goalIconLabel;

  /// No description provided for @catSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get catSalary;

  /// No description provided for @catFreelance.
  ///
  /// In en, this message translates to:
  /// **'Freelance'**
  String get catFreelance;

  /// No description provided for @catBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get catBusiness;

  /// No description provided for @catOtherIncome.
  ///
  /// In en, this message translates to:
  /// **'Other income'**
  String get catOtherIncome;

  /// No description provided for @catRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get catRent;

  /// No description provided for @catGroceries.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get catGroceries;

  /// No description provided for @catUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get catUtilities;

  /// No description provided for @catTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get catTransport;

  /// No description provided for @catDining.
  ///
  /// In en, this message translates to:
  /// **'Food & Dining'**
  String get catDining;

  /// No description provided for @catShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get catShopping;

  /// No description provided for @catHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get catHealth;

  /// No description provided for @catEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get catEntertainment;

  /// No description provided for @catEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get catEducation;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @insightOverBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget check'**
  String get insightOverBudgetTitle;

  /// No description provided for @insightOverBudgetBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You are over budget in one category this month. Review it or adjust the limit.} other{You are over budget in {count} categories this month. Review them or adjust the limits.}}'**
  String insightOverBudgetBody(int count);

  /// No description provided for @insightLowSavingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings watch'**
  String get insightLowSavingsTitle;

  /// No description provided for @insightLowSavingsBody.
  ///
  /// In en, this message translates to:
  /// **'You are saving {rate}% this month. Try to reach 20%.'**
  String insightLowSavingsBody(String rate);

  /// No description provided for @insightEmergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency fund'**
  String get insightEmergencyTitle;

  /// No description provided for @insightEmergencyBody.
  ///
  /// In en, this message translates to:
  /// **'Your savings cover about {months} months of expenses. Aim for 6 months.'**
  String insightEmergencyBody(String months);

  /// No description provided for @insightGoodPaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Great pace'**
  String get insightGoodPaceTitle;

  /// No description provided for @insightGoodPaceBody.
  ///
  /// In en, this message translates to:
  /// **'You are saving {rate}% of income this month. Keep it up!'**
  String insightGoodPaceBody(String rate);

  /// No description provided for @economyPulseTitle.
  ///
  /// In en, this message translates to:
  /// **'Economic Pulse'**
  String get economyPulseTitle;

  /// No description provided for @economyPulseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s happening in Pakistan\'s economy'**
  String get economyPulseSubtitle;

  /// No description provided for @economyKeyIndicatorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Key indicators'**
  String get economyKeyIndicatorsTitle;

  /// No description provided for @economyUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String economyUpdatedAt(String date);

  /// No description provided for @economySourceFooter.
  ///
  /// In en, this message translates to:
  /// **'Source: {source} · Synthetic demo data — not live'**
  String economySourceFooter(String source);

  /// No description provided for @trendRising.
  ///
  /// In en, this message translates to:
  /// **'Rising'**
  String get trendRising;

  /// No description provided for @trendFalling.
  ///
  /// In en, this message translates to:
  /// **'Falling'**
  String get trendFalling;

  /// No description provided for @trendStable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get trendStable;

  /// No description provided for @daysAgoLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String daysAgoLabel(int count);

  /// No description provided for @indicatorInflation.
  ///
  /// In en, this message translates to:
  /// **'Inflation'**
  String get indicatorInflation;

  /// No description provided for @indicatorUsdPkr.
  ///
  /// In en, this message translates to:
  /// **'USD / PKR'**
  String get indicatorUsdPkr;

  /// No description provided for @indicatorPolicyRate.
  ///
  /// In en, this message translates to:
  /// **'Policy Rate'**
  String get indicatorPolicyRate;

  /// No description provided for @indicatorKibor.
  ///
  /// In en, this message translates to:
  /// **'KIBOR'**
  String get indicatorKibor;

  /// No description provided for @indicatorFxReserves.
  ///
  /// In en, this message translates to:
  /// **'FX Reserves'**
  String get indicatorFxReserves;

  /// No description provided for @indicatorRemittances.
  ///
  /// In en, this message translates to:
  /// **'Remittances'**
  String get indicatorRemittances;

  /// No description provided for @indicatorInflationDesc.
  ///
  /// In en, this message translates to:
  /// **'How quickly prices are rising across the economy.'**
  String get indicatorInflationDesc;

  /// No description provided for @indicatorUsdPkrDesc.
  ///
  /// In en, this message translates to:
  /// **'How many rupees one US dollar buys.'**
  String get indicatorUsdPkrDesc;

  /// No description provided for @indicatorPolicyRateDesc.
  ///
  /// In en, this message translates to:
  /// **'The central bank\'s base lending rate.'**
  String get indicatorPolicyRateDesc;

  /// No description provided for @indicatorKiborDesc.
  ///
  /// In en, this message translates to:
  /// **'The rate banks charge each other for short-term loans.'**
  String get indicatorKiborDesc;

  /// No description provided for @indicatorFxReservesDesc.
  ///
  /// In en, this message translates to:
  /// **'The country\'s foreign currency buffer.'**
  String get indicatorFxReservesDesc;

  /// No description provided for @indicatorRemittancesDesc.
  ///
  /// In en, this message translates to:
  /// **'Money sent home by overseas Pakistanis.'**
  String get indicatorRemittancesDesc;

  /// No description provided for @indicatorInflationWhy.
  ///
  /// In en, this message translates to:
  /// **'Higher inflation shrinks what your salary buys — essentials feel it first.'**
  String get indicatorInflationWhy;

  /// No description provided for @indicatorUsdPkrWhy.
  ///
  /// In en, this message translates to:
  /// **'A weaker rupee makes imported goods, fuel and travel cost more.'**
  String get indicatorUsdPkrWhy;

  /// No description provided for @indicatorPolicyRateWhy.
  ///
  /// In en, this message translates to:
  /// **'It steers loan and savings rates — up means costlier borrowing.'**
  String get indicatorPolicyRateWhy;

  /// No description provided for @indicatorKiborWhy.
  ///
  /// In en, this message translates to:
  /// **'KIBOR moves with the policy rate and feeds into personal loan pricing.'**
  String get indicatorKiborWhy;

  /// No description provided for @indicatorFxReservesWhy.
  ///
  /// In en, this message translates to:
  /// **'Healthy reserves steady the rupee and the prices you pay.'**
  String get indicatorFxReservesWhy;

  /// No description provided for @indicatorRemittancesWhy.
  ///
  /// In en, this message translates to:
  /// **'Steady remittances support the rupee and ease price pressure.'**
  String get indicatorRemittancesWhy;

  /// No description provided for @economyEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s changing?'**
  String get economyEventsTitle;

  /// No description provided for @eventInflationUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Inflation ticks up'**
  String get eventInflationUpTitle;

  /// No description provided for @eventInflationUpDesc.
  ///
  /// In en, this message translates to:
  /// **'Inflation moved higher again this month.'**
  String get eventInflationUpDesc;

  /// No description provided for @eventInflationUpImpact.
  ///
  /// In en, this message translates to:
  /// **'Your essentials — groceries and utilities — feel this first.'**
  String get eventInflationUpImpact;

  /// No description provided for @eventRupeeSlipTitle.
  ///
  /// In en, this message translates to:
  /// **'Rupee slips'**
  String get eventRupeeSlipTitle;

  /// No description provided for @eventRupeeSlipDesc.
  ///
  /// In en, this message translates to:
  /// **'USD/PKR edged up, making dollar-linked items pricier.'**
  String get eventRupeeSlipDesc;

  /// No description provided for @eventRupeeSlipImpact.
  ///
  /// In en, this message translates to:
  /// **'Imported goods and fuel tend to pass this through to prices.'**
  String get eventRupeeSlipImpact;

  /// No description provided for @eventRateCutTitle.
  ///
  /// In en, this message translates to:
  /// **'Policy rate eased'**
  String get eventRateCutTitle;

  /// No description provided for @eventRateCutDesc.
  ///
  /// In en, this message translates to:
  /// **'The policy rate came down a notch.'**
  String get eventRateCutDesc;

  /// No description provided for @eventRateCutImpact.
  ///
  /// In en, this message translates to:
  /// **'Borrowing costs should gradually lighten.'**
  String get eventRateCutImpact;

  /// No description provided for @eventRemittancesUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Remittances climb'**
  String get eventRemittancesUpTitle;

  /// No description provided for @eventRemittancesUpDesc.
  ///
  /// In en, this message translates to:
  /// **'Overseas remittances increased this month.'**
  String get eventRemittancesUpDesc;

  /// No description provided for @eventRemittancesUpImpact.
  ///
  /// In en, this message translates to:
  /// **'A steadier rupee helps stabilize the prices you pay.'**
  String get eventRemittancesUpImpact;

  /// No description provided for @eventAskAction.
  ///
  /// In en, this message translates to:
  /// **'Ask Tadbeer'**
  String get eventAskAction;

  /// No description provided for @economyImpactTitle.
  ///
  /// In en, this message translates to:
  /// **'Impact on you'**
  String get economyImpactTitle;

  /// No description provided for @economyImpactInflationBody.
  ///
  /// In en, this message translates to:
  /// **'If inflation rises by {delta, plural, =1{1 point} other{{delta} points}}, your essentials could cost about {pressure} more per month — leaving roughly {capacity} of your {savings} monthly savings.'**
  String economyImpactInflationBody(
      int delta, String pressure, String capacity, String savings);

  /// No description provided for @economyImpactCurrencyBody.
  ///
  /// In en, this message translates to:
  /// **'If the dollar rises by {delta}%, imported goods could add about {pressure} to your monthly expenses — leaving roughly {capacity} of your {savings} monthly savings.'**
  String economyImpactCurrencyBody(
      int delta, String pressure, String capacity, String savings);

  /// No description provided for @economyImpactRatesBody.
  ///
  /// In en, this message translates to:
  /// **'If rates rise by {delta, plural, =1{1 point} other{{delta} points}}, a typical {loan} loan could cost about {pressure} more per month — leaving roughly {capacity} of your {savings} monthly savings.'**
  String economyImpactRatesBody(
      int delta, String loan, String pressure, String capacity, String savings);

  /// No description provided for @economyImpactReservesBody.
  ///
  /// In en, this message translates to:
  /// **'A comfortable reserves buffer helps keep the rupee steady — good for the prices you pay and the value of your savings.'**
  String get economyImpactReservesBody;

  /// No description provided for @economyImpactRemittancesBody.
  ///
  /// In en, this message translates to:
  /// **'Steady remittances support the rupee, easing pressure on everyday prices.'**
  String get economyImpactRemittancesBody;

  /// No description provided for @economyImpactDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Estimated scenario from your demo finances — not a forecast.'**
  String get economyImpactDisclaimer;

  /// No description provided for @economyImpactInflationAction.
  ///
  /// In en, this message translates to:
  /// **'Review discretionary spending and preserve an emergency buffer.'**
  String get economyImpactInflationAction;

  /// No description provided for @economyImpactCurrencyAction.
  ///
  /// In en, this message translates to:
  /// **'Budget a small buffer for imported and dollar-linked items.'**
  String get economyImpactCurrencyAction;

  /// No description provided for @economyImpactRatesAction.
  ///
  /// In en, this message translates to:
  /// **'Weigh loan costs before big borrowed purchases.'**
  String get economyImpactRatesAction;

  /// No description provided for @economyAskCta.
  ///
  /// In en, this message translates to:
  /// **'Ask Tadbeer what this means for you'**
  String get economyAskCta;

  /// No description provided for @economyDetailHistory.
  ///
  /// In en, this message translates to:
  /// **'6-month trend'**
  String get economyDetailHistory;

  /// No description provided for @economyCurrentValue.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get economyCurrentValue;

  /// No description provided for @economyPreviousValue.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get economyPreviousValue;

  /// No description provided for @economyChangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get economyChangeLabel;

  /// No description provided for @economyWhyItMatters.
  ///
  /// In en, this message translates to:
  /// **'Why it matters'**
  String get economyWhyItMatters;

  /// No description provided for @economySourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get economySourceLabel;

  /// No description provided for @economyStatusDemo.
  ///
  /// In en, this message translates to:
  /// **'Synthetic / Demo'**
  String get economyStatusDemo;

  /// No description provided for @economyLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated {date}'**
  String economyLastUpdated(String date);

  /// No description provided for @economyImpactDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Impact on me'**
  String get economyImpactDetailTitle;

  /// No description provided for @economyYourFinances.
  ///
  /// In en, this message translates to:
  /// **'Your finances'**
  String get economyYourFinances;

  /// No description provided for @economyPossibleImpact.
  ///
  /// In en, this message translates to:
  /// **'Possible impact'**
  String get economyPossibleImpact;

  /// No description provided for @economySuggestedAction.
  ///
  /// In en, this message translates to:
  /// **'Suggested action'**
  String get economySuggestedAction;

  /// No description provided for @askTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask Tadbeer'**
  String get askTitle;

  /// No description provided for @askSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your financial intelligence companion — demo answers, real logic.'**
  String get askSubtitle;

  /// No description provided for @demoAiBadge.
  ///
  /// In en, this message translates to:
  /// **'Demo AI'**
  String get demoAiBadge;

  /// No description provided for @askEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about your money or the economy'**
  String get askEmptyTitle;

  /// No description provided for @askEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tadbeer answers from your demo finances — try a question below.'**
  String get askEmptyBody;

  /// No description provided for @askInputHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about your money or the economy…'**
  String get askInputHint;

  /// No description provided for @askSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get askSend;

  /// No description provided for @askPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing your demo financial profile…'**
  String get askPreparing;

  /// No description provided for @askTyping.
  ///
  /// In en, this message translates to:
  /// **'Tadbeer is typing…'**
  String get askTyping;

  /// No description provided for @askFollowUps.
  ///
  /// In en, this message translates to:
  /// **'Try asking'**
  String get askFollowUps;

  /// No description provided for @askTrustLine.
  ///
  /// In en, this message translates to:
  /// **'Demo answer · rule-based · {percent}% match'**
  String askTrustLine(String percent);

  /// No description provided for @askInsightTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalized insight'**
  String get askInsightTitle;

  /// No description provided for @askInsightSavingsBody.
  ///
  /// In en, this message translates to:
  /// **'Your savings rate is {rate}% — close to the 20% target used by your demo financial-health model.'**
  String askInsightSavingsBody(String rate);

  /// No description provided for @askInsightAction.
  ///
  /// In en, this message translates to:
  /// **'Reduce one discretionary category to strengthen savings.'**
  String get askInsightAction;

  /// No description provided for @askClear.
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get askClear;

  /// No description provided for @askPromptInflation.
  ///
  /// In en, this message translates to:
  /// **'How is inflation affecting me?'**
  String get askPromptInflation;

  /// No description provided for @askPromptSavings.
  ///
  /// In en, this message translates to:
  /// **'What can I do to save more?'**
  String get askPromptSavings;

  /// No description provided for @askPromptKibor.
  ///
  /// In en, this message translates to:
  /// **'What is KIBOR?'**
  String get askPromptKibor;

  /// No description provided for @askPromptIncomeDrop.
  ///
  /// In en, this message translates to:
  /// **'What happens if my income drops by 10%?'**
  String get askPromptIncomeDrop;

  /// No description provided for @askPromptCurrency.
  ///
  /// In en, this message translates to:
  /// **'Why does the dollar rate matter to me?'**
  String get askPromptCurrency;

  /// No description provided for @askPromptHealth.
  ///
  /// In en, this message translates to:
  /// **'How am I doing financially?'**
  String get askPromptHealth;

  /// No description provided for @askPromptGoals.
  ///
  /// In en, this message translates to:
  /// **'How can I reach my savings goal faster?'**
  String get askPromptGoals;

  /// No description provided for @askPromptGeneral.
  ///
  /// In en, this message translates to:
  /// **'Explain today\'s economy simply.'**
  String get askPromptGeneral;

  /// No description provided for @askPromptBudget.
  ///
  /// In en, this message translates to:
  /// **'How is my budget doing?'**
  String get askPromptBudget;

  /// No description provided for @askPromptMarket.
  ///
  /// In en, this message translates to:
  /// **'How is the market doing?'**
  String get askPromptMarket;

  /// No description provided for @assistantInflationReply.
  ///
  /// In en, this message translates to:
  /// **'Inflation is at {inflation}% in the demo dataset. Your essentials cost about {essentials} a month, so a 2-point rise could add around {pressure} — leaving an estimated {capacity} of monthly savings. This is a scenario, not a forecast.'**
  String assistantInflationReply(
      String inflation, String essentials, String pressure, String capacity);

  /// No description provided for @assistantSavingsReply.
  ///
  /// In en, this message translates to:
  /// **'You save about {savings} a month ({rate}% of income). Over-budget categories: {overCategories}. Trimming them by {reduction} could lift your savings to about {newSavings}.'**
  String assistantSavingsReply(String savings, String rate,
      String overCategories, String reduction, String newSavings);

  /// No description provided for @assistantSavingsReplyNoOver.
  ///
  /// In en, this message translates to:
  /// **'You save about {savings} a month ({rate}% of income) and every category is within its budget. Setting aside {reduction} more would take your savings to about {newSavings}.'**
  String assistantSavingsReplyNoOver(
      String savings, String rate, String reduction, String newSavings);

  /// No description provided for @assistantBudgetReply.
  ///
  /// In en, this message translates to:
  /// **'You have spent {spent} of your {limit} total budget this month. Over-limit categories: {overCategories}. Bringing them back to their limits is the fastest way to free up savings.'**
  String assistantBudgetReply(
      String spent, String limit, String overCategories);

  /// No description provided for @assistantBudgetReplyNoOver.
  ///
  /// In en, this message translates to:
  /// **'You have spent {spent} of your {limit} total budget this month and every category is within its limit — steady budget discipline.'**
  String assistantBudgetReplyNoOver(String spent, String limit);

  /// No description provided for @assistantHealthReply.
  ///
  /// In en, this message translates to:
  /// **'Your Financial Health Score is {score}, helped by a {rate}% savings rate and about {months} months of expenses covered. Staying on budget and growing your buffer keeps the score moving up.'**
  String assistantHealthReply(String score, String rate, String months);

  /// No description provided for @assistantGoalsReply.
  ///
  /// In en, this message translates to:
  /// **'You are tracking {count} goals, averaging {percent}% complete. Your top goal — {topGoal} — is at {topPercent}%, needing about {requiredMonthly} a month to finish on time.'**
  String assistantGoalsReply(String count, String percent, String topGoal,
      String topPercent, String requiredMonthly);

  /// No description provided for @assistantGoalsReplyEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have no goals yet. Creating one — like an emergency fund — gives your savings a purpose and a deadline.'**
  String get assistantGoalsReplyEmpty;

  /// No description provided for @assistantKiborReply.
  ///
  /// In en, this message translates to:
  /// **'KIBOR is the rate at which banks lend to each other overnight. It sits at {kibor}% in the demo dataset and steers loan and savings rates — on a {loanExample} loan, each KIBOR point costs roughly {perPoint} a year. When KIBOR eases, borrowing usually gets cheaper.'**
  String assistantKiborReply(String kibor, String loanExample, String perPoint);

  /// No description provided for @assistantCurrencyReply.
  ///
  /// In en, this message translates to:
  /// **'The dollar buys {rate} rupees in the demo dataset, {change} this month. A weaker rupee makes imported goods and fuel pricier — the most everyday effect on your budget.'**
  String assistantCurrencyReply(String rate, String change);

  /// No description provided for @assistantMarketReply.
  ///
  /// In en, this message translates to:
  /// **'Market data is not part of this demo yet. The Market tab will cover PSX indices and movers in a later phase — for now, ask me about inflation, the dollar or your budget.'**
  String get assistantMarketReply;

  /// No description provided for @assistantIncomeDropReply.
  ///
  /// In en, this message translates to:
  /// **'If your income fell 10% to {newIncome}, your savings would drop to about {newSavings} a month ({newRate}% of income). Trimming discretionary spending by {cut} would restore savings to about {restored}.'**
  String assistantIncomeDropReply(String newIncome, String newSavings,
      String newRate, String cut, String restored);

  /// No description provided for @assistantGeneralReply.
  ///
  /// In en, this message translates to:
  /// **'Here is today\'s demo economy in one picture: inflation is at {inflation}%, the dollar buys {rate} rupees ({change} this month) and KIBOR sits at {kibor}%. Pick a question below to see what these mean for your wallet.'**
  String assistantGeneralReply(
      String inflation, String rate, String change, String kibor);

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryAction;

  /// No description provided for @errorAssistantNetwork.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach Tadbeer right now. Please check your connection and try again.'**
  String get errorAssistantNetwork;

  /// No description provided for @errorAssistantTimeout.
  ///
  /// In en, this message translates to:
  /// **'Tadbeer is taking longer than expected. Please try again.'**
  String get errorAssistantTimeout;

  /// No description provided for @errorAssistantServer.
  ///
  /// In en, this message translates to:
  /// **'Tadbeer\'s service hit a problem. Please try again in a moment.'**
  String get errorAssistantServer;

  /// No description provided for @errorAssistantMalformed.
  ///
  /// In en, this message translates to:
  /// **'Tadbeer couldn\'t complete its answer. Please try again.'**
  String get errorAssistantMalformed;

  /// No description provided for @liveAiBadge.
  ///
  /// In en, this message translates to:
  /// **'Tadbeer AI'**
  String get liveAiBadge;

  /// No description provided for @dataStatusLive.
  ///
  /// In en, this message translates to:
  /// **'Live economic data'**
  String get dataStatusLive;

  /// No description provided for @dataStatusPartial.
  ///
  /// In en, this message translates to:
  /// **'Some indicators use demo data'**
  String get dataStatusPartial;

  /// No description provided for @dataStatusDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo economic data'**
  String get dataStatusDemo;

  /// No description provided for @dataStatusScenario.
  ///
  /// In en, this message translates to:
  /// **'What-If — your assumption, not a forecast'**
  String get dataStatusScenario;

  /// No description provided for @dataStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live data currently unavailable'**
  String get dataStatusUnavailable;

  /// No description provided for @keyNumbersTitle.
  ///
  /// In en, this message translates to:
  /// **'Key numbers'**
  String get keyNumbersTitle;

  /// No description provided for @apiSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get apiSourcesTitle;

  /// No description provided for @apiRecommendationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get apiRecommendationsTitle;

  /// No description provided for @metricMonthlySavings.
  ///
  /// In en, this message translates to:
  /// **'Monthly savings'**
  String get metricMonthlySavings;

  /// No description provided for @metricSavingsRate.
  ///
  /// In en, this message translates to:
  /// **'Savings rate'**
  String get metricSavingsRate;

  /// No description provided for @metricExpenseRatio.
  ///
  /// In en, this message translates to:
  /// **'Expense ratio'**
  String get metricExpenseRatio;

  /// No description provided for @metricRunwayMonths.
  ///
  /// In en, this message translates to:
  /// **'Emergency runway'**
  String get metricRunwayMonths;

  /// No description provided for @metricUnitMonths.
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get metricUnitMonths;

  /// No description provided for @metricUnitBnUsd.
  ///
  /// In en, this message translates to:
  /// **'bn USD'**
  String get metricUnitBnUsd;

  /// No description provided for @scenarioLabel.
  ///
  /// In en, this message translates to:
  /// **'What-If Scenario'**
  String get scenarioLabel;

  /// No description provided for @scenarioNotForecast.
  ///
  /// In en, this message translates to:
  /// **'Based on your assumption — not a forecast.'**
  String get scenarioNotForecast;

  /// No description provided for @scenarioAssumption.
  ///
  /// In en, this message translates to:
  /// **'Assumption'**
  String get scenarioAssumption;

  /// No description provided for @scenarioCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current situation'**
  String get scenarioCurrent;

  /// No description provided for @scenarioChanges.
  ///
  /// In en, this message translates to:
  /// **'What changes'**
  String get scenarioChanges;

  /// No description provided for @scenarioImpact.
  ///
  /// In en, this message translates to:
  /// **'Estimated impact'**
  String get scenarioImpact;

  /// No description provided for @scenarioNextSteps.
  ///
  /// In en, this message translates to:
  /// **'Next steps'**
  String get scenarioNextSteps;

  /// No description provided for @scenarioLimitations.
  ///
  /// In en, this message translates to:
  /// **'Limitations'**
  String get scenarioLimitations;

  /// No description provided for @scenarioSaveMoreAssumption.
  ///
  /// In en, this message translates to:
  /// **'Save {amount} more each month'**
  String scenarioSaveMoreAssumption(String amount);

  /// No description provided for @scenarioExpenseAssumptionIncrease.
  ///
  /// In en, this message translates to:
  /// **'Expenses increase by {percent}%'**
  String scenarioExpenseAssumptionIncrease(String percent);

  /// No description provided for @scenarioExpenseAssumptionDecrease.
  ///
  /// In en, this message translates to:
  /// **'Expenses decrease by {percent}%'**
  String scenarioExpenseAssumptionDecrease(String percent);

  /// No description provided for @scenarioRateAssumptionIncrease.
  ///
  /// In en, this message translates to:
  /// **'Interest rates increase by {points} percentage points'**
  String scenarioRateAssumptionIncrease(String points);

  /// No description provided for @scenarioRateAssumptionDecrease.
  ///
  /// In en, this message translates to:
  /// **'Interest rates decrease by {points} percentage points'**
  String scenarioRateAssumptionDecrease(String points);

  /// No description provided for @scenarioRowCurrentSavings.
  ///
  /// In en, this message translates to:
  /// **'Current monthly savings'**
  String get scenarioRowCurrentSavings;

  /// No description provided for @scenarioRowNewSavings.
  ///
  /// In en, this message translates to:
  /// **'New monthly savings'**
  String get scenarioRowNewSavings;

  /// No description provided for @scenarioRowAdditional.
  ///
  /// In en, this message translates to:
  /// **'Additional savings / month'**
  String get scenarioRowAdditional;

  /// No description provided for @scenarioRowAfterMonths.
  ///
  /// In en, this message translates to:
  /// **'After {months} months'**
  String scenarioRowAfterMonths(num months);

  /// No description provided for @scenarioRowCurrentRate.
  ///
  /// In en, this message translates to:
  /// **'Current savings rate'**
  String get scenarioRowCurrentRate;

  /// No description provided for @scenarioRowNewRate.
  ///
  /// In en, this message translates to:
  /// **'Projected savings rate'**
  String get scenarioRowNewRate;

  /// No description provided for @scenarioRowCurrentExpenses.
  ///
  /// In en, this message translates to:
  /// **'Current monthly expenses'**
  String get scenarioRowCurrentExpenses;

  /// No description provided for @scenarioRowNewExpenses.
  ///
  /// In en, this message translates to:
  /// **'New monthly expenses'**
  String get scenarioRowNewExpenses;

  /// No description provided for @scenarioRowAdditionalExpense.
  ///
  /// In en, this message translates to:
  /// **'Additional monthly expense'**
  String get scenarioRowAdditionalExpense;

  /// No description provided for @scenarioRowCurrentSurplus.
  ///
  /// In en, this message translates to:
  /// **'Current monthly surplus'**
  String get scenarioRowCurrentSurplus;

  /// No description provided for @scenarioRowProjectedSurplus.
  ///
  /// In en, this message translates to:
  /// **'Projected monthly surplus'**
  String get scenarioRowProjectedSurplus;

  /// No description provided for @scenarioRowCurrentRunway.
  ///
  /// In en, this message translates to:
  /// **'Current emergency runway'**
  String get scenarioRowCurrentRunway;

  /// No description provided for @scenarioRowProjectedRunway.
  ///
  /// In en, this message translates to:
  /// **'Projected emergency runway'**
  String get scenarioRowProjectedRunway;

  /// No description provided for @whatIfButton.
  ///
  /// In en, this message translates to:
  /// **'What-If'**
  String get whatIfButton;

  /// No description provided for @whatIfTitle.
  ///
  /// In en, this message translates to:
  /// **'Build a What-If question'**
  String get whatIfTitle;

  /// No description provided for @whatIfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set your assumption — Tadbeer calculates the impact deterministically. It is an illustration, not a forecast.'**
  String get whatIfSubtitle;

  /// No description provided for @whatIfSaveMore.
  ///
  /// In en, this message translates to:
  /// **'Save more'**
  String get whatIfSaveMore;

  /// No description provided for @whatIfExpenseChange.
  ///
  /// In en, this message translates to:
  /// **'Expense change'**
  String get whatIfExpenseChange;

  /// No description provided for @whatIfRateChange.
  ///
  /// In en, this message translates to:
  /// **'Rate change'**
  String get whatIfRateChange;

  /// No description provided for @whatIfAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Extra monthly savings (PKR)'**
  String get whatIfAmountLabel;

  /// No description provided for @whatIfMonthsLabel.
  ///
  /// In en, this message translates to:
  /// **'Months (optional)'**
  String get whatIfMonthsLabel;

  /// No description provided for @whatIfMonthsHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for 6 and 12 months'**
  String get whatIfMonthsHint;

  /// No description provided for @whatIfPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Change (%)'**
  String get whatIfPercentLabel;

  /// No description provided for @whatIfPointsLabel.
  ///
  /// In en, this message translates to:
  /// **'Change (percentage points)'**
  String get whatIfPointsLabel;

  /// No description provided for @whatIfIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get whatIfIncrease;

  /// No description provided for @whatIfDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get whatIfDecrease;

  /// No description provided for @whatIfRun.
  ///
  /// In en, this message translates to:
  /// **'Run What-If'**
  String get whatIfRun;

  /// No description provided for @whatIfInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than zero.'**
  String get whatIfInvalidAmount;

  /// No description provided for @whatIfInvalidPercent.
  ///
  /// In en, this message translates to:
  /// **'Enter a percentage between 0.1 and 100.'**
  String get whatIfInvalidPercent;

  /// No description provided for @whatIfMonthsInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number of months between 1 and 600.'**
  String get whatIfMonthsInvalid;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Build Your Financial Profile'**
  String get profileTitle;

  /// No description provided for @profileBody.
  ///
  /// In en, this message translates to:
  /// **'Tell Tadbeer a little about your finances so your insights can be more relevant.'**
  String get profileBody;

  /// No description provided for @profileWhoAreYou.
  ///
  /// In en, this message translates to:
  /// **'Who are you?'**
  String get profileWhoAreYou;

  /// No description provided for @profilePersonaStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get profilePersonaStudent;

  /// No description provided for @profilePersonaSalaried.
  ///
  /// In en, this message translates to:
  /// **'Salaried Employee'**
  String get profilePersonaSalaried;

  /// No description provided for @profilePersonaBusinessOwner.
  ///
  /// In en, this message translates to:
  /// **'Business Owner'**
  String get profilePersonaBusinessOwner;

  /// No description provided for @profilePersonaShopOwner.
  ///
  /// In en, this message translates to:
  /// **'Shop Owner'**
  String get profilePersonaShopOwner;

  /// No description provided for @profileMonthlyFinances.
  ///
  /// In en, this message translates to:
  /// **'Your typical monthly finances'**
  String get profileMonthlyFinances;

  /// No description provided for @profileIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Typical Monthly Income'**
  String get profileIncomeLabel;

  /// No description provided for @profileIncomeHint.
  ///
  /// In en, this message translates to:
  /// **'Approximate amount — zero is fine for students.'**
  String get profileIncomeHint;

  /// No description provided for @profileExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'Essential Monthly Expenses'**
  String get profileExpensesLabel;

  /// No description provided for @profileExpensesHint.
  ///
  /// In en, this message translates to:
  /// **'Rent, food, bills, and other essentials.'**
  String get profileExpensesHint;

  /// No description provided for @profileExpensesWarning.
  ///
  /// In en, this message translates to:
  /// **'Your essential expenses are higher than your typical income. That\'s okay — Tadbeer can help you understand the gap and plan around it.'**
  String get profileExpensesWarning;

  /// No description provided for @profileGoalSection.
  ///
  /// In en, this message translates to:
  /// **'What\'s your main goal?'**
  String get profileGoalSection;

  /// No description provided for @profileGoalEmergencyFund.
  ///
  /// In en, this message translates to:
  /// **'Emergency Fund'**
  String get profileGoalEmergencyFund;

  /// No description provided for @profileGoalSaveMore.
  ///
  /// In en, this message translates to:
  /// **'Save More'**
  String get profileGoalSaveMore;

  /// No description provided for @profileGoalEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get profileGoalEducation;

  /// No description provided for @profileGoalNewDevice.
  ///
  /// In en, this message translates to:
  /// **'New Laptop / Device'**
  String get profileGoalNewDevice;

  /// No description provided for @profileGoalBusinessGrowth.
  ///
  /// In en, this message translates to:
  /// **'Business Growth'**
  String get profileGoalBusinessGrowth;

  /// No description provided for @profileGoalReduceSpending.
  ///
  /// In en, this message translates to:
  /// **'Reduce Spending'**
  String get profileGoalReduceSpending;

  /// No description provided for @profileGoalOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get profileGoalOther;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save Profile'**
  String get profileSave;

  /// No description provided for @profileNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get profileNotNow;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved!'**
  String get profileSaved;

  /// No description provided for @profileValidationPersona.
  ///
  /// In en, this message translates to:
  /// **'Please select who you are.'**
  String get profileValidationPersona;

  /// No description provided for @profileValidationIncome.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid income amount.'**
  String get profileValidationIncome;

  /// No description provided for @profileValidationIncomeNegative.
  ///
  /// In en, this message translates to:
  /// **'Income cannot be negative.'**
  String get profileValidationIncomeNegative;

  /// No description provided for @profileValidationExpenses.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid expenses amount.'**
  String get profileValidationExpenses;

  /// No description provided for @profileValidationExpensesNegative.
  ///
  /// In en, this message translates to:
  /// **'Expenses cannot be negative.'**
  String get profileValidationExpensesNegative;

  /// No description provided for @profileValidationGoal.
  ///
  /// In en, this message translates to:
  /// **'Please select a primary goal.'**
  String get profileValidationGoal;

  /// No description provided for @homeProfileCtaTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalize Tadbeer'**
  String get homeProfileCtaTitle;

  /// No description provided for @homeProfileCtaBody.
  ///
  /// In en, this message translates to:
  /// **'Add a few details about your finances so Tadbeer can give you more relevant insights.'**
  String get homeProfileCtaBody;

  /// No description provided for @homeProfileCtaButton.
  ///
  /// In en, this message translates to:
  /// **'Complete Profile'**
  String get homeProfileCtaButton;

  /// No description provided for @homeProfileCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Profile'**
  String get homeProfileCompletedTitle;

  /// No description provided for @homeProfileCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'Personalized insights enabled'**
  String get homeProfileCompletedBody;

  /// No description provided for @homeProfileEditButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get homeProfileEditButton;

  /// No description provided for @essentialPricesTitle.
  ///
  /// In en, this message translates to:
  /// **'Essential Prices'**
  String get essentialPricesTitle;

  /// No description provided for @essentialPricesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everyday items affecting household budgets'**
  String get essentialPricesSubtitle;

  /// No description provided for @essentialPricesWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why Everyday Prices Matter'**
  String get essentialPricesWhyTitle;

  /// No description provided for @essentialPricesWhyBody.
  ///
  /// In en, this message translates to:
  /// **'Weekly shifts in staple commodities like onions, chicken, and flour directly alter kitchen cash flow. Ask Tadbeer how these trends impact your personal surplus or test a grocery price shock.'**
  String get essentialPricesWhyBody;

  /// No description provided for @essentialPricesAskImpact.
  ///
  /// In en, this message translates to:
  /// **'Ask Tadbeer'**
  String get essentialPricesAskImpact;

  /// No description provided for @essentialPricesTryWhatIf.
  ///
  /// In en, this message translates to:
  /// **'Try What-If'**
  String get essentialPricesTryWhatIf;

  /// No description provided for @essentialPricesViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get essentialPricesViewAll;

  /// No description provided for @essentialPricesShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get essentialPricesShowLess;

  /// No description provided for @essentialPricesCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get essentialPricesCategoryAll;

  /// No description provided for @essentialPricesCategoryVegetables.
  ///
  /// In en, this message translates to:
  /// **'Vegetables'**
  String get essentialPricesCategoryVegetables;

  /// No description provided for @essentialPricesCategoryDairy.
  ///
  /// In en, this message translates to:
  /// **'Dairy & Poultry'**
  String get essentialPricesCategoryDairy;

  /// No description provided for @essentialPricesCategoryStaples.
  ///
  /// In en, this message translates to:
  /// **'Food & Staples'**
  String get essentialPricesCategoryStaples;

  /// No description provided for @essentialPricesCategoryPulses.
  ///
  /// In en, this message translates to:
  /// **'Pulses'**
  String get essentialPricesCategoryPulses;

  /// No description provided for @essentialPricesCategoryCookingFuel.
  ///
  /// In en, this message translates to:
  /// **'Cooking & Fuel'**
  String get essentialPricesCategoryCookingFuel;

  /// No description provided for @essentialPricesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Essential price data temporarily unavailable'**
  String get essentialPricesUnavailable;

  /// No description provided for @actionContinueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get actionContinueAsGuest;

  /// No description provided for @loginGuestMode.
  ///
  /// In en, this message translates to:
  /// **'Guest Mode'**
  String get loginGuestMode;

  /// No description provided for @loginGuestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Instant access to Economy & Finance tools'**
  String get loginGuestSubtitle;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address to receive a secure 6-digit verification code.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @actionForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get actionForgotPassword;

  /// No description provided for @actionSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Code'**
  String get actionSendCode;

  /// No description provided for @actionResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get actionResetPassword;

  /// No description provided for @actionResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get actionResendCode;

  /// No description provided for @verifyCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get verifyCodeTitle;

  /// No description provided for @verifyCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to your email.'**
  String get verifyCodeSubtitle;

  /// No description provided for @codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Code sent to'**
  String get codeSentTo;

  /// No description provided for @demoCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Demo code: 842196'**
  String get demoCodeHint;

  /// No description provided for @fieldVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get fieldVerificationCode;

  /// No description provided for @validationCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the 6-digit code.'**
  String get validationCodeRequired;

  /// No description provided for @validationCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired verification code.'**
  String get validationCodeInvalid;

  /// No description provided for @newPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPasswordTitle;

  /// No description provided for @newPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a strong new password for your account.'**
  String get newPasswordSubtitle;

  /// No description provided for @passwordResetSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Password Reset Successfully!'**
  String get passwordResetSuccessTitle;

  /// No description provided for @passwordResetSuccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your password has been securely updated. You can now sign in with your new password.'**
  String get passwordResetSuccessSubtitle;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get backToSignIn;

  /// No description provided for @codeResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String codeResendIn(int seconds);
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
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'ur':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return AppLocalizationsUrLatn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
