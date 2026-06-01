import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Hiext YT GUI'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'yt-dlp Visual Downloader'**
  String get appSubtitle;

  /// No description provided for @newDownload.
  ///
  /// In en, this message translates to:
  /// **'New Download'**
  String get newDownload;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloading;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @pasteLink.
  ///
  /// In en, this message translates to:
  /// **'Paste Link'**
  String get pasteLink;

  /// No description provided for @pasteLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Paste video link here'**
  String get pasteLinkHint;

  /// No description provided for @pasteLinkDesc.
  ///
  /// In en, this message translates to:
  /// **'Drop a video URL here, we\'ll find downloadable content.'**
  String get pasteLinkDesc;

  /// No description provided for @parseLink.
  ///
  /// In en, this message translates to:
  /// **'Parse Link'**
  String get parseLink;

  /// No description provided for @parsing.
  ///
  /// In en, this message translates to:
  /// **'Parsing...'**
  String get parsing;

  /// No description provided for @selectFormat.
  ///
  /// In en, this message translates to:
  /// **'Select Format'**
  String get selectFormat;

  /// No description provided for @selectFormatDesc.
  ///
  /// In en, this message translates to:
  /// **'After parsing, choose a format to download.'**
  String get selectFormatDesc;

  /// No description provided for @selectFormatHint.
  ///
  /// In en, this message translates to:
  /// **'Please paste a link and parse first.'**
  String get selectFormatHint;

  /// No description provided for @recommendedQuality.
  ///
  /// In en, this message translates to:
  /// **'Recommended Quality'**
  String get recommendedQuality;

  /// No description provided for @recommendedQualityDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-select best video and audio streams and merge into one file.'**
  String get recommendedQualityDesc;

  /// No description provided for @videoFormats.
  ///
  /// In en, this message translates to:
  /// **'Video Formats'**
  String get videoFormats;

  /// No description provided for @audioFormats.
  ///
  /// In en, this message translates to:
  /// **'Audio Formats'**
  String get audioFormats;

  /// No description provided for @checkToSelect.
  ///
  /// In en, this message translates to:
  /// **'Check formats to download. You can select multiple.'**
  String get checkToSelect;

  /// No description provided for @downloadSelected.
  ///
  /// In en, this message translates to:
  /// **'Download Selected'**
  String get downloadSelected;

  /// No description provided for @addingTask.
  ///
  /// In en, this message translates to:
  /// **'Adding tasks...'**
  String get addingTask;

  /// No description provided for @taskList.
  ///
  /// In en, this message translates to:
  /// **'Task List'**
  String get taskList;

  /// No description provided for @taskListDesc.
  ///
  /// In en, this message translates to:
  /// **'Download tasks appear here after pasting a link and selecting formats.'**
  String get taskListDesc;

  /// No description provided for @noDownloadTasks.
  ///
  /// In en, this message translates to:
  /// **'No download tasks yet'**
  String get noDownloadTasks;

  /// No description provided for @noDownloadTasksHint.
  ///
  /// In en, this message translates to:
  /// **'Go to New Download and paste a link to start'**
  String get noDownloadTasksHint;

  /// No description provided for @formatsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} formats'**
  String formatsCount(int count);

  /// No description provided for @saveAndQuality.
  ///
  /// In en, this message translates to:
  /// **'Save & Quality'**
  String get saveAndQuality;

  /// No description provided for @saveAndQualityDesc.
  ///
  /// In en, this message translates to:
  /// **'File save location and default download quality.'**
  String get saveAndQualityDesc;

  /// No description provided for @saveDirectory.
  ///
  /// In en, this message translates to:
  /// **'Save Directory'**
  String get saveDirectory;

  /// No description provided for @defaultQuality.
  ///
  /// In en, this message translates to:
  /// **'Default Quality / Format'**
  String get defaultQuality;

  /// No description provided for @defaultQualityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. best, bestvideo+bestaudio, or yt-dlp format id'**
  String get defaultQualityHint;

  /// No description provided for @externalTools.
  ///
  /// In en, this message translates to:
  /// **'External Tools'**
  String get externalTools;

  /// No description provided for @externalToolsDesc.
  ///
  /// In en, this message translates to:
  /// **'Paths to yt-dlp and ffmpeg. Leave empty to use bundled versions.'**
  String get externalToolsDesc;

  /// No description provided for @ytDlpPath.
  ///
  /// In en, this message translates to:
  /// **'yt-dlp Path'**
  String get ytDlpPath;

  /// No description provided for @ytDlpPathHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use bundled yt-dlp'**
  String get ytDlpPathHint;

  /// No description provided for @ffmpegPath.
  ///
  /// In en, this message translates to:
  /// **'ffmpeg Path'**
  String get ffmpegPath;

  /// No description provided for @ffmpegPathHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use bundled ffmpeg'**
  String get ffmpegPathHint;

  /// No description provided for @downloadMode.
  ///
  /// In en, this message translates to:
  /// **'Download Mode'**
  String get downloadMode;

  /// No description provided for @downloadModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Control parallel task count and scheduling strategy.'**
  String get downloadModeDesc;

  /// No description provided for @scheduleMode.
  ///
  /// In en, this message translates to:
  /// **'Schedule Mode'**
  String get scheduleMode;

  /// No description provided for @serialDownload.
  ///
  /// In en, this message translates to:
  /// **'Serial — one at a time'**
  String get serialDownload;

  /// No description provided for @queueDownload.
  ///
  /// In en, this message translates to:
  /// **'Queue — wait in line'**
  String get queueDownload;

  /// No description provided for @concurrentDownload.
  ///
  /// In en, this message translates to:
  /// **'Concurrent — simultaneously'**
  String get concurrentDownload;

  /// No description provided for @concurrentCount.
  ///
  /// In en, this message translates to:
  /// **'Concurrent Count'**
  String get concurrentCount;

  /// No description provided for @concurrentHint.
  ///
  /// In en, this message translates to:
  /// **'Download {count} tasks simultaneously'**
  String concurrentHint(int count);

  /// No description provided for @concurrentDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Only effective in concurrent mode'**
  String get concurrentDisabledHint;

  /// No description provided for @additionalOptions.
  ///
  /// In en, this message translates to:
  /// **'Additional Options'**
  String get additionalOptions;

  /// No description provided for @downloadSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Download Subtitles'**
  String get downloadSubtitles;

  /// No description provided for @downloadSubtitlesDesc.
  ///
  /// In en, this message translates to:
  /// **'Append --write-subs to yt-dlp'**
  String get downloadSubtitlesDesc;

  /// No description provided for @downloadThumbnail.
  ///
  /// In en, this message translates to:
  /// **'Download Thumbnails'**
  String get downloadThumbnail;

  /// No description provided for @downloadThumbnailDesc.
  ///
  /// In en, this message translates to:
  /// **'Append --write-thumbnail to yt-dlp'**
  String get downloadThumbnailDesc;

  /// No description provided for @restoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore Defaults'**
  String get restoreDefaults;

  /// No description provided for @browseDirectory.
  ///
  /// In en, this message translates to:
  /// **'Browse directory'**
  String get browseDirectory;

  /// No description provided for @browseFile.
  ///
  /// In en, this message translates to:
  /// **'Browse file'**
  String get browseFile;

  /// No description provided for @cookieManagement.
  ///
  /// In en, this message translates to:
  /// **'Cookie Management'**
  String get cookieManagement;

  /// No description provided for @cookieManagementDesc.
  ///
  /// In en, this message translates to:
  /// **'Log into websites in browser first, then import cookies. Login required for HD.'**
  String get cookieManagementDesc;

  /// No description provided for @browser.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get browser;

  /// No description provided for @domain.
  ///
  /// In en, this message translates to:
  /// **'Domain'**
  String get domain;

  /// No description provided for @importBtn.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importBtn;

  /// No description provided for @commonSites.
  ///
  /// In en, this message translates to:
  /// **'Common Sites'**
  String get commonSites;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @reimport.
  ///
  /// In en, this message translates to:
  /// **'Re-import'**
  String get reimport;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @cookieImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Cookie import failed after trying all browsers'**
  String get cookieImportFailed;

  /// No description provided for @cookieImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported cookies for {domain}'**
  String cookieImportSuccess(String domain);

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No History'**
  String get noHistory;

  /// No description provided for @noHistoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Completed or cancelled downloads will appear here.'**
  String get noHistoryDesc;

  /// No description provided for @noHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No history records yet'**
  String get noHistoryYet;

  /// No description provided for @completedTasks.
  ///
  /// In en, this message translates to:
  /// **'Completed Tasks'**
  String get completedTasks;

  /// No description provided for @completedTasksDesc.
  ///
  /// In en, this message translates to:
  /// **'Successfully downloaded tasks.'**
  String get completedTasksDesc;

  /// No description provided for @failedTasks.
  ///
  /// In en, this message translates to:
  /// **'Failed Tasks'**
  String get failedTasks;

  /// No description provided for @failedTasksDesc.
  ///
  /// In en, this message translates to:
  /// **'You can re-add these to the download queue.'**
  String get failedTasksDesc;

  /// No description provided for @cancelledTasks.
  ///
  /// In en, this message translates to:
  /// **'Cancelled Tasks'**
  String get cancelledTasks;

  /// No description provided for @cancelledTasksDesc.
  ///
  /// In en, this message translates to:
  /// **'Tasks cancelled by user.'**
  String get cancelledTasksDesc;

  /// No description provided for @noRecordsHere.
  ///
  /// In en, this message translates to:
  /// **'No records here'**
  String get noRecordsHere;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open Folder'**
  String get openFolder;

  /// No description provided for @threeSteps.
  ///
  /// In en, this message translates to:
  /// **'Three Steps'**
  String get threeSteps;

  /// No description provided for @threeStepsDesc.
  ///
  /// In en, this message translates to:
  /// **'Download videos in just three steps.'**
  String get threeStepsDesc;

  /// No description provided for @step1.
  ///
  /// In en, this message translates to:
  /// **'Paste Link'**
  String get step1;

  /// No description provided for @step1Desc.
  ///
  /// In en, this message translates to:
  /// **'Paste a video URL on the New Download page (supports YouTube, Bilibili, etc).'**
  String get step1Desc;

  /// No description provided for @step2.
  ///
  /// In en, this message translates to:
  /// **'Select Format'**
  String get step2;

  /// No description provided for @step2Desc.
  ///
  /// In en, this message translates to:
  /// **'Click Parse Link to view available formats, pick your preferred quality.'**
  String get step2Desc;

  /// No description provided for @step3.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get step3;

  /// No description provided for @step3Desc.
  ///
  /// In en, this message translates to:
  /// **'Click Download Selected to add tasks to the queue and start automatically.'**
  String get step3Desc;

  /// No description provided for @modeHelp.
  ///
  /// In en, this message translates to:
  /// **'Download Modes'**
  String get modeHelp;

  /// No description provided for @modeHelpDesc.
  ///
  /// In en, this message translates to:
  /// **'Switch between three modes on the Settings page.'**
  String get modeHelpDesc;

  /// No description provided for @modeSerial.
  ///
  /// In en, this message translates to:
  /// **'Serial Download'**
  String get modeSerial;

  /// No description provided for @modeSerialDesc.
  ///
  /// In en, this message translates to:
  /// **'One task at a time. Best for limited bandwidth.'**
  String get modeSerialDesc;

  /// No description provided for @modeQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue Download'**
  String get modeQueue;

  /// No description provided for @modeQueueDesc.
  ///
  /// In en, this message translates to:
  /// **'Manually manage download order, won\'t auto-start next.'**
  String get modeQueueDesc;

  /// No description provided for @modeConcurrent.
  ///
  /// In en, this message translates to:
  /// **'Concurrent Download'**
  String get modeConcurrent;

  /// No description provided for @modeConcurrentDesc.
  ///
  /// In en, this message translates to:
  /// **'Multiple tasks simultaneously (1-8). Best for abundant bandwidth.'**
  String get modeConcurrentDesc;

  /// No description provided for @toolConfig.
  ///
  /// In en, this message translates to:
  /// **'Tool Configuration'**
  String get toolConfig;

  /// No description provided for @toolConfigDesc.
  ///
  /// In en, this message translates to:
  /// **'The app bundles yt-dlp and ffmpeg, or use system-installed versions.'**
  String get toolConfigDesc;

  /// No description provided for @faqYtDlp.
  ///
  /// In en, this message translates to:
  /// **'How to use your own yt-dlp?'**
  String get faqYtDlp;

  /// No description provided for @faqYtDlpAnswer.
  ///
  /// In en, this message translates to:
  /// **'Enter full path in Settings, leave empty for bundled version.'**
  String get faqYtDlpAnswer;

  /// No description provided for @faqFfmpeg.
  ///
  /// In en, this message translates to:
  /// **'What is ffmpeg for?'**
  String get faqFfmpeg;

  /// No description provided for @faqFfmpegAnswer.
  ///
  /// In en, this message translates to:
  /// **'yt-dlp uses ffmpeg for format conversion and merging.'**
  String get faqFfmpegAnswer;

  /// No description provided for @faqSites.
  ///
  /// In en, this message translates to:
  /// **'Which websites are supported?'**
  String get faqSites;

  /// No description provided for @faqSitesAnswer.
  ///
  /// In en, this message translates to:
  /// **'yt-dlp supports thousands of sites: YouTube, Bilibili, Twitter/X, TikTok, Instagram, etc.'**
  String get faqSitesAnswer;

  /// No description provided for @resumeHelp.
  ///
  /// In en, this message translates to:
  /// **'Resume Support'**
  String get resumeHelp;

  /// No description provided for @resumeHelpDesc.
  ///
  /// In en, this message translates to:
  /// **'Downloads can be resumed after interruption.'**
  String get resumeHelpDesc;

  /// No description provided for @faqResumePause.
  ///
  /// In en, this message translates to:
  /// **'Will pausing lose progress?'**
  String get faqResumePause;

  /// No description provided for @faqResumePauseAnswer.
  ///
  /// In en, this message translates to:
  /// **'No. yt-dlp preserves partial files and resumes from breakpoint.'**
  String get faqResumePauseAnswer;

  /// No description provided for @faqResumeCrash.
  ///
  /// In en, this message translates to:
  /// **'Can it recover after a crash?'**
  String get faqResumeCrash;

  /// No description provided for @faqResumeCrashAnswer.
  ///
  /// In en, this message translates to:
  /// **'Yes. Restart the app and click Retry in History.'**
  String get faqResumeCrashAnswer;

  /// No description provided for @expandCompleted.
  ///
  /// In en, this message translates to:
  /// **'Expand Completed'**
  String get expandCompleted;

  /// No description provided for @collapseCompleted.
  ///
  /// In en, this message translates to:
  /// **'Collapse Completed'**
  String get collapseCompleted;

  /// No description provided for @deleteRecord.
  ///
  /// In en, this message translates to:
  /// **'Delete Record Only'**
  String get deleteRecord;

  /// No description provided for @deleteWithFiles.
  ///
  /// In en, this message translates to:
  /// **'Also Delete Files'**
  String get deleteWithFiles;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete History Record'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String confirmDeleteContent(String title);

  /// No description provided for @parseFailed.
  ///
  /// In en, this message translates to:
  /// **'Parse failed: {error}'**
  String parseFailed(String error);

  /// No description provided for @addTaskFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add task: {error}'**
  String addTaskFailed(String error);

  /// No description provided for @pleaseEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a complete URL, e.g. https://...'**
  String get pleaseEnterUrl;

  /// No description provided for @cookiePrompt.
  ///
  /// In en, this message translates to:
  /// **'Login required for HD formats. Log into {host} in browser, then import Cookies in Settings.'**
  String cookiePrompt(String host);

  /// No description provided for @downloadSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'Download Selected ({count} items)'**
  String downloadSelectedCount(int count);

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @fileLabel.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get fileLabel;

  /// No description provided for @alreadyImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get alreadyImported;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// No description provided for @justImported.
  ///
  /// In en, this message translates to:
  /// **'Just imported'**
  String get justImported;

  /// No description provided for @cookiesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} cookies'**
  String cookiesCount(int count);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
