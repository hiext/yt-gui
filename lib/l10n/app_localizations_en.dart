// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hiext YT GUI';

  @override
  String get appSubtitle => 'yt-dlp Visual Downloader';

  @override
  String get newDownload => 'New Download';

  @override
  String get downloading => 'Downloads';

  @override
  String get history => 'History';

  @override
  String get settings => 'Settings';

  @override
  String get help => 'Help';

  @override
  String get pasteLink => 'Paste Link';

  @override
  String get pasteLinkHint => 'Paste video link here';

  @override
  String get pasteLinkDesc =>
      'Drop a video URL here, we\'ll find downloadable content.';

  @override
  String get parseLink => 'Parse Link';

  @override
  String get parsing => 'Parsing...';

  @override
  String get selectFormat => 'Select Format';

  @override
  String get selectFormatDesc => 'After parsing, choose a format to download.';

  @override
  String get selectFormatHint => 'Please paste a link and parse first.';

  @override
  String get recommendedQuality => 'Recommended Quality';

  @override
  String get recommendedQualityDesc =>
      'Auto-select best video and audio streams and merge into one file.';

  @override
  String get videoFormats => 'Video Formats';

  @override
  String get audioFormats => 'Audio Formats';

  @override
  String get checkToSelect =>
      'Check formats to download. You can select multiple.';

  @override
  String get downloadSelected => 'Download Selected';

  @override
  String get addingTask => 'Adding tasks...';

  @override
  String get taskList => 'Task List';

  @override
  String get taskListDesc =>
      'Download tasks appear here after pasting a link and selecting formats.';

  @override
  String get noDownloadTasks => 'No download tasks yet';

  @override
  String get noDownloadTasksHint =>
      'Go to New Download and paste a link to start';

  @override
  String formatsCount(int count) {
    return '$count formats';
  }

  @override
  String get saveAndQuality => 'Save & Quality';

  @override
  String get saveAndQualityDesc =>
      'File save location and default download quality.';

  @override
  String get saveDirectory => 'Save Directory';

  @override
  String get defaultQuality => 'Default Quality / Format';

  @override
  String get defaultQualityHint =>
      'e.g. best, bestvideo+bestaudio, or yt-dlp format id';

  @override
  String get externalTools => 'External Tools';

  @override
  String get externalToolsDesc =>
      'Paths to yt-dlp and ffmpeg. Leave empty to use bundled versions.';

  @override
  String get ytDlpPath => 'yt-dlp Path';

  @override
  String get ytDlpPathHint => 'Leave empty to use bundled yt-dlp';

  @override
  String get ffmpegPath => 'ffmpeg Path';

  @override
  String get ffmpegPathHint => 'Leave empty to use bundled ffmpeg';

  @override
  String get downloadMode => 'Download Mode';

  @override
  String get downloadModeDesc =>
      'Control parallel task count and scheduling strategy.';

  @override
  String get scheduleMode => 'Schedule Mode';

  @override
  String get serialDownload => 'Serial — one at a time';

  @override
  String get queueDownload => 'Queue — wait in line';

  @override
  String get concurrentDownload => 'Concurrent — simultaneously';

  @override
  String get concurrentCount => 'Concurrent Count';

  @override
  String concurrentHint(int count) {
    return 'Download $count tasks simultaneously';
  }

  @override
  String get concurrentDisabledHint => 'Only effective in concurrent mode';

  @override
  String get additionalOptions => 'Additional Options';

  @override
  String get downloadSubtitles => 'Download Subtitles';

  @override
  String get downloadSubtitlesDesc => 'Append --write-subs to yt-dlp';

  @override
  String get downloadThumbnail => 'Download Thumbnails';

  @override
  String get downloadThumbnailDesc => 'Append --write-thumbnail to yt-dlp';

  @override
  String get restoreDefaults => 'Restore Defaults';

  @override
  String get browseDirectory => 'Browse directory';

  @override
  String get browseFile => 'Browse file';

  @override
  String get cookieManagement => 'Cookie Management';

  @override
  String get cookieManagementDesc =>
      'Log into websites in browser first, then import cookies. Login required for HD.';

  @override
  String get browser => 'Browser';

  @override
  String get domain => 'Domain';

  @override
  String get importBtn => 'Import';

  @override
  String get commonSites => 'Common Sites';

  @override
  String get delete => 'Delete';

  @override
  String get reimport => 'Re-import';

  @override
  String get viewDetails => 'View Details';

  @override
  String get cookieImportFailed =>
      'Cookie import failed after trying all browsers';

  @override
  String cookieImportSuccess(String domain) {
    return 'Imported cookies for $domain';
  }

  @override
  String get noHistory => 'No History';

  @override
  String get noHistoryDesc =>
      'Completed or cancelled downloads will appear here.';

  @override
  String get noHistoryYet => 'No history records yet';

  @override
  String get completedTasks => 'Completed Tasks';

  @override
  String get completedTasksDesc => 'Successfully downloaded tasks.';

  @override
  String get failedTasks => 'Failed Tasks';

  @override
  String get failedTasksDesc => 'You can re-add these to the download queue.';

  @override
  String get cancelledTasks => 'Cancelled Tasks';

  @override
  String get cancelledTasksDesc => 'Tasks cancelled by user.';

  @override
  String get noRecordsHere => 'No records here';

  @override
  String get openFolder => 'Open Folder';

  @override
  String get threeSteps => 'Three Steps';

  @override
  String get threeStepsDesc => 'Download videos in just three steps.';

  @override
  String get step1 => 'Paste Link';

  @override
  String get step1Desc =>
      'Paste a video URL on the New Download page (supports YouTube, Bilibili, etc).';

  @override
  String get step2 => 'Select Format';

  @override
  String get step2Desc =>
      'Click Parse Link to view available formats, pick your preferred quality.';

  @override
  String get step3 => 'Download';

  @override
  String get step3Desc =>
      'Click Download Selected to add tasks to the queue and start automatically.';

  @override
  String get modeHelp => 'Download Modes';

  @override
  String get modeHelpDesc => 'Switch between three modes on the Settings page.';

  @override
  String get modeSerial => 'Serial Download';

  @override
  String get modeSerialDesc =>
      'One task at a time. Best for limited bandwidth.';

  @override
  String get modeQueue => 'Queue Download';

  @override
  String get modeQueueDesc =>
      'Manually manage download order, won\'t auto-start next.';

  @override
  String get modeConcurrent => 'Concurrent Download';

  @override
  String get modeConcurrentDesc =>
      'Multiple tasks simultaneously (1-8). Best for abundant bandwidth.';

  @override
  String get toolConfig => 'Tool Configuration';

  @override
  String get toolConfigDesc =>
      'The app bundles yt-dlp and ffmpeg, or use system-installed versions.';

  @override
  String get faqYtDlp => 'How to use your own yt-dlp?';

  @override
  String get faqYtDlpAnswer =>
      'Enter full path in Settings, leave empty for bundled version.';

  @override
  String get faqFfmpeg => 'What is ffmpeg for?';

  @override
  String get faqFfmpegAnswer =>
      'yt-dlp uses ffmpeg for format conversion and merging.';

  @override
  String get faqSites => 'Which websites are supported?';

  @override
  String get faqSitesAnswer =>
      'yt-dlp supports thousands of sites: YouTube, Bilibili, Twitter/X, TikTok, Instagram, etc.';

  @override
  String get resumeHelp => 'Resume Support';

  @override
  String get resumeHelpDesc => 'Downloads can be resumed after interruption.';

  @override
  String get faqResumePause => 'Will pausing lose progress?';

  @override
  String get faqResumePauseAnswer =>
      'No. yt-dlp preserves partial files and resumes from breakpoint.';

  @override
  String get faqResumeCrash => 'Can it recover after a crash?';

  @override
  String get faqResumeCrashAnswer =>
      'Yes. Restart the app and click Retry in History.';

  @override
  String get expandCompleted => 'Expand Completed';

  @override
  String get collapseCompleted => 'Collapse Completed';

  @override
  String get deleteRecord => 'Delete Record Only';

  @override
  String get deleteWithFiles => 'Also Delete Files';

  @override
  String get confirmDelete => 'Delete History Record';

  @override
  String confirmDeleteContent(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String parseFailed(String error) {
    return 'Parse failed: $error';
  }

  @override
  String addTaskFailed(String error) {
    return 'Failed to add task: $error';
  }

  @override
  String get pleaseEnterUrl => 'Please enter a complete URL, e.g. https://...';

  @override
  String cookiePrompt(String host) {
    return 'Login required for HD formats. Log into $host in browser, then import Cookies in Settings.';
  }

  @override
  String downloadSelectedCount(int count) {
    return 'Download Selected ($count items)';
  }

  @override
  String get video => 'Video';

  @override
  String get audio => 'Audio';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get fileLabel => 'File';

  @override
  String get alreadyImported => 'Imported';

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get justImported => 'Just imported';

  @override
  String cookiesCount(int count) {
    return '$count cookies';
  }

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get additionalOptionsDesc =>
      'Download subtitles and thumbnails along with video.';

  @override
  String get openDownloadDir => 'Open Download Folder';
}
