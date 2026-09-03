// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Tadbeer AI';

  @override
  String get tagline => 'Your AI-Powered Financial Intelligence Companion';

  @override
  String get corePromise =>
      'Understand your money. Understand the economy. Plan with confidence.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get onboardingTitleUnderstand => 'Understand';

  @override
  String get onboardingDescUnderstand =>
      'See your money and Pakistan\'s economy in one place — inflation, exchange rates and policy changes, explained simply.';

  @override
  String get onboardingTitleManage => 'Manage';

  @override
  String get onboardingDescManage =>
      'Track income, expenses, budgets and goals with a clear Financial Health Score built from your real numbers.';

  @override
  String get onboardingTitlePlan => 'Plan';

  @override
  String get onboardingDescPlan =>
      'Run what-if scenarios and get AI guidance to plan with confidence — never guess again.';

  @override
  String get loginWelcome => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to continue your financial journey.';

  @override
  String get signupTitle => 'Create your account';

  @override
  String get signupSubtitle => 'Start understanding your money today.';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldFullName => 'Full name';

  @override
  String get fieldConfirmPassword => 'Confirm password';

  @override
  String get actionSignIn => 'Sign In';

  @override
  String get actionCreateAccount => 'Create Account';

  @override
  String get loginNoAccount => 'Don\'t have an account?';

  @override
  String get loginHaveAccount => 'Already have an account?';

  @override
  String get authDemoNote =>
      'Demo mode — accounts are stored locally on this device.';

  @override
  String get validationNameRequired => 'Please enter your name.';

  @override
  String get validationEmailInvalid => 'Please enter a valid email address.';

  @override
  String get validationPasswordShort =>
      'Password must be at least 6 characters.';

  @override
  String get validationPasswordMismatch => 'Passwords do not match.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get tabHome => 'Home';

  @override
  String get tabFinance => 'Finance';

  @override
  String get tabEconomy => 'Economy';

  @override
  String get tabMarket => 'Market';

  @override
  String get tabAskTadbeer => 'Ask Tadbeer';

  @override
  String get homeSectionTitle => 'Your financial home';

  @override
  String get homeSectionBody =>
      'Your daily overview — health score, spending summary, budget progress and the economic pulse that matters to you.';

  @override
  String get financeSectionTitle => 'Your money, organized';

  @override
  String get financeSectionBody =>
      'Income, expenses, budgets and goals with charts that show exactly where your money goes.';

  @override
  String get economySectionTitle => 'Economic Pulse';

  @override
  String get economySectionBody =>
      'Inflation, USD/PKR, policy rate and more — clearly sourced, with what each change means for you.';

  @override
  String get marketSectionTitle => 'Market intelligence';

  @override
  String get marketSectionBody =>
      'PSX indices, watchlists and market movers explained — intelligence, not trading.';

  @override
  String get askSectionTitle => 'Ask Tadbeer';

  @override
  String get askSectionBody =>
      'Your AI financial companion — ask about inflation, your budget, savings goals or anything money.';

  @override
  String greetingMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String greetingAfternoon(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String greetingEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String get demoDataBadge => 'Demo data';

  @override
  String get healthScoreTitle => 'Financial Health';

  @override
  String get thisMonth => 'This month';

  @override
  String get income => 'Income';

  @override
  String get expenses => 'Expenses';

  @override
  String get savings => 'Savings';

  @override
  String get budgetLabel => 'Budget';

  @override
  String budgetUsedOf(String spent, String limit) {
    return '$spent of $limit used';
  }

  @override
  String get savingsTrend => 'Savings trend';

  @override
  String get recentTransactions => 'Recent transactions';

  @override
  String get viewAll => 'View all';

  @override
  String get goalProgressTitle => 'Goal progress';

  @override
  String get insightTitle => 'Insight';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get actionAddExpense => 'Add expense';

  @override
  String get actionAddIncome => 'Add income';

  @override
  String get actionNewGoal => 'New goal';

  @override
  String get actionViewFinances => 'My finances';

  @override
  String monthsLeft(int count) {
    return '$count months left';
  }

  @override
  String get goalReached => 'Goal reached';

  @override
  String get onTrackLabel => 'On track';

  @override
  String get overBudgetShort => 'Over budget';

  @override
  String get financialHealthTitle => 'Financial Health';

  @override
  String get ratingExcellent => 'Excellent';

  @override
  String get ratingGood => 'Good';

  @override
  String get ratingFair => 'Fair';

  @override
  String get ratingNeedsAttention => 'Needs attention';

  @override
  String get componentSavings => 'Savings behavior';

  @override
  String get componentBudget => 'Budget discipline';

  @override
  String get componentEmergency => 'Emergency fund';

  @override
  String get componentGoals => 'Goal progress';

  @override
  String get componentSpending => 'Spending behavior';

  @override
  String healthWeightLabel(String weight) {
    return 'Weight: $weight%';
  }

  @override
  String healthDetailSavings(String rate) {
    return 'You save $rate% of your income.';
  }

  @override
  String healthDetailBudget(String onTrack, String total) {
    return '$onTrack of $total budgets on track.';
  }

  @override
  String healthDetailEmergency(String months) {
    return 'Your savings cover $months months of expenses.';
  }

  @override
  String healthDetailGoals(String percent) {
    return 'Average progress across goals: $percent%.';
  }

  @override
  String healthDetailSpending(String percent) {
    return '$percent% of your income goes to wants.';
  }

  @override
  String get howScoreWorks => 'How this score works';

  @override
  String get howScoreWorksBody =>
      'Your score is calculated deterministically from your finances — savings rate, budget discipline, emergency fund coverage, goal progress and spending mix. No AI is involved in the math; the same inputs always produce the same score.';

  @override
  String get navHealthTitle => 'Financial Health';

  @override
  String get navHealthDesc => 'Your score and what drives it';

  @override
  String get navMyFinancesTitle => 'My Finances';

  @override
  String get navMyFinancesDesc => 'Income, expenses and trends';

  @override
  String get navExpensesTitle => 'Expenses';

  @override
  String get navExpensesDesc => 'Track every transaction';

  @override
  String get navBudgetTitle => 'Budget Planner';

  @override
  String get navBudgetDesc => 'Category limits and alerts';

  @override
  String get navGoalsTitle => 'Goals';

  @override
  String get navGoalsDesc => 'Save with a purpose';

  @override
  String get monthlySummary => 'Monthly summary';

  @override
  String get categoryBreakdown => 'Category breakdown';

  @override
  String get spendingTrend => 'Spending trend';

  @override
  String get availableBalance => 'Available balance';

  @override
  String get totalIncome => 'Total income';

  @override
  String get totalExpenses => 'Total expenses';

  @override
  String get resetDemoData => 'Reset demo data';

  @override
  String get resetDemoDataDone => 'Demo data restored.';

  @override
  String get incomeVsExpenses => 'Income vs expenses';

  @override
  String get searchTransactions => 'Search transactions';

  @override
  String get filterAll => 'All';

  @override
  String get filterIncome => 'Income';

  @override
  String get filterExpense => 'Expense';

  @override
  String get noTransactionsTitle => 'No transactions yet';

  @override
  String get noTransactionsBody =>
      'Add your first transaction to start tracking your money.';

  @override
  String get addTransactionTitle => 'Add transaction';

  @override
  String get editTransactionTitle => 'Edit transaction';

  @override
  String get deleteTransactionTitle => 'Delete transaction';

  @override
  String get deleteTransactionBody =>
      'This transaction will be removed from your demo data.';

  @override
  String get fieldTitle => 'Title';

  @override
  String get fieldAmount => 'Amount';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldDate => 'Date';

  @override
  String get fieldNote => 'Note (optional)';

  @override
  String get validationTitleRequired => 'Please enter a title.';

  @override
  String get validationAmountInvalid => 'Enter an amount greater than 0.';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionAdd => 'Add';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get noResultsTitle => 'No matches';

  @override
  String get noResultsBody => 'Try a different search or filter.';

  @override
  String get monthlyBudgetTitle => 'Monthly budget';

  @override
  String get spentLabel => 'Spent';

  @override
  String get remainingLabel => 'Remaining';

  @override
  String overByLabel(String amount) {
    return 'Over by $amount';
  }

  @override
  String get addBudgetTitle => 'Add budget';

  @override
  String get editBudgetTitle => 'Edit budget';

  @override
  String get fieldMonthlyLimit => 'Monthly limit';

  @override
  String get validationLimitInvalid => 'Enter a limit greater than 0.';

  @override
  String get noBudgetsTitle => 'No budgets yet';

  @override
  String get noBudgetsBody =>
      'Set category limits to keep your spending on track.';

  @override
  String get deleteBudgetTitle => 'Delete budget';

  @override
  String get deleteBudgetBody =>
      'This category limit will be removed from your demo data.';

  @override
  String get totalBudgetLabel => 'Total';

  @override
  String budgetOnTrackDesc(String onTrack, String total) {
    return '$onTrack of $total categories on track';
  }

  @override
  String get savedLabel => 'Saved';

  @override
  String get targetLabel => 'Target';

  @override
  String get targetDateLabel => 'Target date';

  @override
  String requiredMonthlyLabel(String amount) {
    return 'Save $amount per month to finish on time';
  }

  @override
  String get addGoalTitle => 'New goal';

  @override
  String get editGoalTitle => 'Edit goal';

  @override
  String get fieldGoalName => 'Goal name';

  @override
  String get fieldTargetAmount => 'Target amount';

  @override
  String get fieldSavedAmount => 'Already saved';

  @override
  String get validationTargetInvalid => 'Enter a target greater than 0.';

  @override
  String get validationSavedExceeds => 'Saved amount can\'t exceed the target.';

  @override
  String get noGoalsTitle => 'No goals yet';

  @override
  String get noGoalsBody => 'Create a savings goal to see your progress grow.';

  @override
  String get deleteGoalTitle => 'Delete goal';

  @override
  String get deleteGoalBody => 'This goal will be removed from your demo data.';

  @override
  String get addFundsTitle => 'Add funds';

  @override
  String get fieldAmountToAdd => 'Amount to add';

  @override
  String get goalIconLabel => 'Icon';

  @override
  String get catSalary => 'Salary';

  @override
  String get catFreelance => 'Freelance';

  @override
  String get catBusiness => 'Business';

  @override
  String get catOtherIncome => 'Other income';

  @override
  String get catRent => 'Rent';

  @override
  String get catGroceries => 'Groceries';

  @override
  String get catUtilities => 'Utilities';

  @override
  String get catTransport => 'Transport';

  @override
  String get catDining => 'Food & Dining';

  @override
  String get catShopping => 'Shopping';

  @override
  String get catHealth => 'Health';

  @override
  String get catEntertainment => 'Entertainment';

  @override
  String get catEducation => 'Education';

  @override
  String get catOther => 'Other';

  @override
  String get insightOverBudgetTitle => 'Budget check';

  @override
  String insightOverBudgetBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You are over budget in $count categories this month. Review them or adjust the limits.',
      one:
          'You are over budget in one category this month. Review it or adjust the limit.',
    );
    return '$_temp0';
  }

  @override
  String get insightLowSavingsTitle => 'Savings watch';

  @override
  String insightLowSavingsBody(String rate) {
    return 'You are saving $rate% this month. Try to reach 20%.';
  }

  @override
  String get insightEmergencyTitle => 'Emergency fund';

  @override
  String insightEmergencyBody(String months) {
    return 'Your savings cover about $months months of expenses. Aim for 6 months.';
  }

  @override
  String get insightGoodPaceTitle => 'Great pace';

  @override
  String insightGoodPaceBody(String rate) {
    return 'You are saving $rate% of income this month. Keep it up!';
  }

  @override
  String get economyPulseTitle => 'Economic Pulse';

  @override
  String get economyPulseSubtitle => 'What\'s happening in Pakistan\'s economy';

  @override
  String get economyKeyIndicatorsTitle => 'Key indicators';

  @override
  String economyUpdatedAt(String date) {
    return 'Updated $date';
  }

  @override
  String economySourceFooter(String source) {
    return 'Source: $source · Synthetic demo data — not live';
  }

  @override
  String get trendRising => 'Rising';

  @override
  String get trendFalling => 'Falling';

  @override
  String get trendStable => 'Stable';

  @override
  String daysAgoLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get indicatorInflation => 'Inflation';

  @override
  String get indicatorUsdPkr => 'USD / PKR';

  @override
  String get indicatorPolicyRate => 'Policy Rate';

  @override
  String get indicatorKibor => 'KIBOR';

  @override
  String get indicatorFxReserves => 'FX Reserves';

  @override
  String get indicatorRemittances => 'Remittances';

  @override
  String get indicatorInflationDesc =>
      'How quickly prices are rising across the economy.';

  @override
  String get indicatorUsdPkrDesc => 'How many rupees one US dollar buys.';

  @override
  String get indicatorPolicyRateDesc =>
      'The central bank\'s base lending rate.';

  @override
  String get indicatorKiborDesc =>
      'The rate banks charge each other for short-term loans.';

  @override
  String get indicatorFxReservesDesc =>
      'The country\'s foreign currency buffer.';

  @override
  String get indicatorRemittancesDesc =>
      'Money sent home by overseas Pakistanis.';

  @override
  String get indicatorInflationWhy =>
      'Higher inflation shrinks what your salary buys — essentials feel it first.';

  @override
  String get indicatorUsdPkrWhy =>
      'A weaker rupee makes imported goods, fuel and travel cost more.';

  @override
  String get indicatorPolicyRateWhy =>
      'It steers loan and savings rates — up means costlier borrowing.';

  @override
  String get indicatorKiborWhy =>
      'KIBOR moves with the policy rate and feeds into personal loan pricing.';

  @override
  String get indicatorFxReservesWhy =>
      'Healthy reserves steady the rupee and the prices you pay.';

  @override
  String get indicatorRemittancesWhy =>
      'Steady remittances support the rupee and ease price pressure.';

  @override
  String get economyEventsTitle => 'What\'s changing?';

  @override
  String get eventInflationUpTitle => 'Inflation ticks up';

  @override
  String get eventInflationUpDesc => 'Inflation moved higher again this month.';

  @override
  String get eventInflationUpImpact =>
      'Your essentials — groceries and utilities — feel this first.';

  @override
  String get eventRupeeSlipTitle => 'Rupee slips';

  @override
  String get eventRupeeSlipDesc =>
      'USD/PKR edged up, making dollar-linked items pricier.';

  @override
  String get eventRupeeSlipImpact =>
      'Imported goods and fuel tend to pass this through to prices.';

  @override
  String get eventRateCutTitle => 'Policy rate eased';

  @override
  String get eventRateCutDesc => 'The policy rate came down a notch.';

  @override
  String get eventRateCutImpact => 'Borrowing costs should gradually lighten.';

  @override
  String get eventRemittancesUpTitle => 'Remittances climb';

  @override
  String get eventRemittancesUpDesc =>
      'Overseas remittances increased this month.';

  @override
  String get eventRemittancesUpImpact =>
      'A steadier rupee helps stabilize the prices you pay.';

  @override
  String get eventAskAction => 'Ask Tadbeer';

  @override
  String get economyImpactTitle => 'Impact on you';

  @override
  String economyImpactInflationBody(
      int delta, String pressure, String capacity, String savings) {
    String _temp0 = intl.Intl.pluralLogic(
      delta,
      locale: localeName,
      other: '$delta points',
      one: '1 point',
    );
    return 'If inflation rises by $_temp0, your essentials could cost about $pressure more per month — leaving roughly $capacity of your $savings monthly savings.';
  }

  @override
  String economyImpactCurrencyBody(
      int delta, String pressure, String capacity, String savings) {
    return 'If the dollar rises by $delta%, imported goods could add about $pressure to your monthly expenses — leaving roughly $capacity of your $savings monthly savings.';
  }

  @override
  String economyImpactRatesBody(int delta, String loan, String pressure,
      String capacity, String savings) {
    String _temp0 = intl.Intl.pluralLogic(
      delta,
      locale: localeName,
      other: '$delta points',
      one: '1 point',
    );
    return 'If rates rise by $_temp0, a typical $loan loan could cost about $pressure more per month — leaving roughly $capacity of your $savings monthly savings.';
  }

  @override
  String get economyImpactReservesBody =>
      'A comfortable reserves buffer helps keep the rupee steady — good for the prices you pay and the value of your savings.';

  @override
  String get economyImpactRemittancesBody =>
      'Steady remittances support the rupee, easing pressure on everyday prices.';

  @override
  String get economyImpactDisclaimer =>
      'Estimated scenario from your demo finances — not a forecast.';

  @override
  String get economyImpactInflationAction =>
      'Review discretionary spending and preserve an emergency buffer.';

  @override
  String get economyImpactCurrencyAction =>
      'Budget a small buffer for imported and dollar-linked items.';

  @override
  String get economyImpactRatesAction =>
      'Weigh loan costs before big borrowed purchases.';

  @override
  String get economyAskCta => 'Ask Tadbeer what this means for you';

  @override
  String get economyDetailHistory => '6-month trend';

  @override
  String get economyCurrentValue => 'Current';

  @override
  String get economyPreviousValue => 'Previous';

  @override
  String get economyChangeLabel => 'Change';

  @override
  String get economyWhyItMatters => 'Why it matters';

  @override
  String get economySourceLabel => 'Source';

  @override
  String get economyStatusDemo => 'Synthetic / Demo';

  @override
  String economyLastUpdated(String date) {
    return 'Last updated $date';
  }

  @override
  String get economyImpactDetailTitle => 'Impact on me';

  @override
  String get economyYourFinances => 'Your finances';

  @override
  String get economyPossibleImpact => 'Possible impact';

  @override
  String get economySuggestedAction => 'Suggested action';

  @override
  String get askTitle => 'Ask Tadbeer';

  @override
  String get askSubtitle =>
      'Your financial intelligence companion — demo answers, real logic.';

  @override
  String get demoAiBadge => 'Demo AI';

  @override
  String get askEmptyTitle => 'Ask anything about your money or the economy';

  @override
  String get askEmptyBody =>
      'Tadbeer answers from your demo finances — try a question below.';

  @override
  String get askInputHint => 'Ask about your money or the economy…';

  @override
  String get askSend => 'Send';

  @override
  String get askPreparing => 'Preparing your demo financial profile…';

  @override
  String get askTyping => 'Tadbeer is typing…';

  @override
  String get askFollowUps => 'Try asking';

  @override
  String askTrustLine(String percent) {
    return 'Demo answer · rule-based · $percent% match';
  }

  @override
  String get askInsightTitle => 'Personalized insight';

  @override
  String askInsightSavingsBody(String rate) {
    return 'Your savings rate is $rate% — close to the 20% target used by your demo financial-health model.';
  }

  @override
  String get askInsightAction =>
      'Reduce one discretionary category to strengthen savings.';

  @override
  String get askClear => 'Clear chat';

  @override
  String get askPromptInflation => 'How is inflation affecting me?';

  @override
  String get askPromptSavings => 'What can I do to save more?';

  @override
  String get askPromptKibor => 'What is KIBOR?';

  @override
  String get askPromptIncomeDrop => 'What happens if my income drops by 10%?';

  @override
  String get askPromptCurrency => 'Why does the dollar rate matter to me?';

  @override
  String get askPromptHealth => 'How am I doing financially?';

  @override
  String get askPromptGoals => 'How can I reach my savings goal faster?';

  @override
  String get askPromptGeneral => 'Explain today\'s economy simply.';

  @override
  String get askPromptBudget => 'How is my budget doing?';

  @override
  String get askPromptMarket => 'How is the market doing?';

  @override
  String assistantInflationReply(
      String inflation, String essentials, String pressure, String capacity) {
    return 'Inflation is at $inflation% in the demo dataset. Your essentials cost about $essentials a month, so a 2-point rise could add around $pressure — leaving an estimated $capacity of monthly savings. This is a scenario, not a forecast.';
  }

  @override
  String assistantSavingsReply(String savings, String rate,
      String overCategories, String reduction, String newSavings) {
    return 'You save about $savings a month ($rate% of income). Over-budget categories: $overCategories. Trimming them by $reduction could lift your savings to about $newSavings.';
  }

  @override
  String assistantSavingsReplyNoOver(
      String savings, String rate, String reduction, String newSavings) {
    return 'You save about $savings a month ($rate% of income) and every category is within its budget. Setting aside $reduction more would take your savings to about $newSavings.';
  }

  @override
  String assistantBudgetReply(
      String spent, String limit, String overCategories) {
    return 'You have spent $spent of your $limit total budget this month. Over-limit categories: $overCategories. Bringing them back to their limits is the fastest way to free up savings.';
  }

  @override
  String assistantBudgetReplyNoOver(String spent, String limit) {
    return 'You have spent $spent of your $limit total budget this month and every category is within its limit — steady budget discipline.';
  }

  @override
  String assistantHealthReply(String score, String rate, String months) {
    return 'Your Financial Health Score is $score, helped by a $rate% savings rate and about $months months of expenses covered. Staying on budget and growing your buffer keeps the score moving up.';
  }

  @override
  String assistantGoalsReply(String count, String percent, String topGoal,
      String topPercent, String requiredMonthly) {
    return 'You are tracking $count goals, averaging $percent% complete. Your top goal — $topGoal — is at $topPercent%, needing about $requiredMonthly a month to finish on time.';
  }

  @override
  String get assistantGoalsReplyEmpty =>
      'You have no goals yet. Creating one — like an emergency fund — gives your savings a purpose and a deadline.';

  @override
  String assistantKiborReply(
      String kibor, String loanExample, String perPoint) {
    return 'KIBOR is the rate at which banks lend to each other overnight. It sits at $kibor% in the demo dataset and steers loan and savings rates — on a $loanExample loan, each KIBOR point costs roughly $perPoint a year. When KIBOR eases, borrowing usually gets cheaper.';
  }

  @override
  String assistantCurrencyReply(String rate, String change) {
    return 'The dollar buys $rate rupees in the demo dataset, $change this month. A weaker rupee makes imported goods and fuel pricier — the most everyday effect on your budget.';
  }

  @override
  String get assistantMarketReply =>
      'Market data is not part of this demo yet. The Market tab will cover PSX indices and movers in a later phase — for now, ask me about inflation, the dollar or your budget.';

  @override
  String assistantIncomeDropReply(String newIncome, String newSavings,
      String newRate, String cut, String restored) {
    return 'If your income fell 10% to $newIncome, your savings would drop to about $newSavings a month ($newRate% of income). Trimming discretionary spending by $cut would restore savings to about $restored.';
  }

  @override
  String assistantGeneralReply(
      String inflation, String rate, String change, String kibor) {
    return 'Here is today\'s demo economy in one picture: inflation is at $inflation%, the dollar buys $rate rupees ($change this month) and KIBOR sits at $kibor%. Pick a question below to see what these mean for your wallet.';
  }

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get retryAction => 'Retry';

  @override
  String get profileTitle => 'Build Your Financial Profile';

  @override
  String get profileBody =>
      'Tell Tadbeer a little about your finances so your insights can be more relevant.';

  @override
  String get profileWhoAreYou => 'Who are you?';

  @override
  String get profilePersonaStudent => 'Student';

  @override
  String get profilePersonaSalaried => 'Salaried Employee';

  @override
  String get profilePersonaBusinessOwner => 'Business Owner';

  @override
  String get profilePersonaShopOwner => 'Shop Owner';

  @override
  String get profileMonthlyFinances => 'Your typical monthly finances';

  @override
  String get profileIncomeLabel => 'Typical Monthly Income';

  @override
  String get profileIncomeHint =>
      'Approximate amount — zero is fine for students.';

  @override
  String get profileExpensesLabel => 'Essential Monthly Expenses';

  @override
  String get profileExpensesHint => 'Rent, food, bills, and other essentials.';

  @override
  String get profileExpensesWarning =>
      'Your essential expenses are higher than your typical income. That\'s okay — Tadbeer can help you understand the gap and plan around it.';

  @override
  String get profileGoalSection => 'What\'s your main goal?';

  @override
  String get profileGoalEmergencyFund => 'Emergency Fund';

  @override
  String get profileGoalSaveMore => 'Save More';

  @override
  String get profileGoalEducation => 'Education';

  @override
  String get profileGoalNewDevice => 'New Laptop / Device';

  @override
  String get profileGoalBusinessGrowth => 'Business Growth';

  @override
  String get profileGoalReduceSpending => 'Reduce Spending';

  @override
  String get profileGoalOther => 'Other';

  @override
  String get profileSave => 'Save Profile';

  @override
  String get profileNotNow => 'Not now';

  @override
  String get profileSaved => 'Profile saved!';

  @override
  String get profileValidationPersona => 'Please select who you are.';

  @override
  String get profileValidationIncome => 'Please enter a valid income amount.';

  @override
  String get profileValidationIncomeNegative => 'Income cannot be negative.';

  @override
  String get profileValidationExpenses =>
      'Please enter a valid expenses amount.';

  @override
  String get profileValidationExpensesNegative =>
      'Expenses cannot be negative.';

  @override
  String get profileValidationGoal => 'Please select a primary goal.';

  @override
  String get homeProfileCtaTitle => 'Personalize Tadbeer';

  @override
  String get homeProfileCtaBody =>
      'Add a few details about your finances so Tadbeer can give you more relevant insights.';

  @override
  String get homeProfileCtaButton => 'Complete Profile';

  @override
  String get homeProfileCompletedTitle => 'Financial Profile';

  @override
  String get homeProfileCompletedBody => 'Personalized insights enabled';

  @override
  String get homeProfileEditButton => 'Edit';
}
