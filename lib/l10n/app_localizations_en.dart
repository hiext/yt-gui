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
  String get pasteLinkDesc => 'Drop a video URL here, we\'ll find downloadable content.';

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
  String get recommendedQualityDesc => 'Automatically select best video and audio streams and merge into one file.';

  @override
  String get videoFormats => 'Video Formats';

  @override
  String get audioFormats => 'Audio Formats';

  @override
  String get checkToSelect => 'Check formats to download. You can select multiple.';

  @override
  String get downloadSelected => 'Download Selected';

  @override
  String get addingTask => 'Adding tasks...';

  @override
  String get taskList => 'Task List';

  @override
  String get taskListDesc => 'Download tasks will appear here after pasting a link and selecting formats.';

  @override
  String get noDownloadTasks => 'No download tasks yet';

  @override
  String get noDownloadTasksHint => 'Go to \'New Download\' and paste a link to start';

  @override
  String get pause => 'Pause';

  @override
  String get cancel => 'Cancel';

  @override
  String get resume => 'Resume';

  @override
  String get retry => 'Retry';

  @override
  String get completed => 'Completed';

  @override
  String get failed => 'Failed';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get waiting => 'Waiting';

  @override
  String get queued => 'Queued';

  @override
  String formatsCount(int count) {
    return '$count formats';
  }

  @override
  String get saveAndQuality => 'Save & Quality';

  @override
  String get saveAndQualityDesc => 'File save location and default download quality.';

  @override
  String get saveDirectory => 'Save Directory';

  @override
  String get defaultQuality => 'Default Quality / Format';

  @override
  String get defaultQualityHint => 'e.g. best, bestvideo+bestaudio, or yt-dlp format id';

  @override
  String get externalTools => 'External Tools';

  @override
  String get externalToolsDesc => 'Paths to yt-dlp and ffmpeg. Leave empty to use bundled versions.';

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
  String get downloadModeDesc => 'Control parallel task count and scheduling strategy.';

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
  String get additionalOptionsDesc => 'Download subtitles and thumbnails along with video.';

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
  String get cookieManagementDesc => 'Log into websites in browser first, then import cookies. Login required for HD formats.';

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
  String get noHistory => 'No History';

  @override
  String get noHistoryDesc => 'Completed or cancelled downloads will appear here.';

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
  String get noRecordsHere => 'No records in this category';

  @override
  String get openFolder => 'Open Folder';

  @override
  String get threeSteps => 'Three Steps';

  @override
  String get threeStepsDesc => 'Download videos in just three steps.';

  @override
  String get step1 => 'Paste Link';

  @override
  String get step1Desc => 'Paste a video URL on the \'New Download\' page (supports YouTube, Bilibili, and thousands more).';

  @override
  String get step2 => 'Select Format';

  @override
  String get step2Desc => 'Click \'Parse Link\' to view available formats, pick your preferred quality or audio format.';

  @override
  String get step3 => 'Download';

  @override
  String get step3Desc => 'Click \'Download Selected\' to add tasks to the queue and start automatically.';

  @override
  String get modeHelp => 'Download Modes';

  @override
  String get modeHelpDesc => 'Switch between three modes on the Settings page.';

  @override
  String get modeSerial => 'Serial Download';

  @override
  String get modeSerialDesc => 'One task at a time. Next starts automatically after completion. Best for limited bandwidth.';

  @override
  String get modeQueue => 'Queue Download';

  @override
  String get modeQueueDesc => 'Manually manage download order. New tasks join the queue tail, won\'t auto-start.';

  @override
  String get modeConcurrent => 'Concurrent Download';

  @override
  String get modeConcurrentDesc => 'Multiple tasks simultaneously. Adjust count (1-8) in Settings. Best for abundant bandwidth.';

  @override
  String get toolConfig => 'Tool Configuration';

  @override
  String get toolConfigDesc => 'The app bundles yt-dlp and ffmpeg, but you can also use system-installed versions.';

  @override
  String get faqYtDlp => 'How to use your own yt-dlp?';

  @override
  String get faqYtDlpAnswer => 'Enter the full path (e.g. /usr/bin/yt-dlp) in Settings > yt-dlp Path. Leave empty for bundled version.';

  @override
  String get faqFfmpeg => 'What is ffmpeg for?';

  @override
  String get faqFfmpegAnswer => 'yt-dlp uses ffmpeg for format conversion and merging (e.g. combining separate video and audio streams). Some features may not work without ffmpeg.';

  @override
  String get faqSites => 'Which websites are supported?';

  @override
  String get faqSitesAnswer => 'yt-dlp supports thousands of sites including YouTube, Bilibili, Twitter/X, TikTok, Instagram, etc. See yt-dlp docs for the full list.';

  @override
  String get resumeHelp => 'Resume Support';

  @override
  String get resumeHelpDesc => 'Downloads can be resumed after interruption without starting over.';

  @override
  String get faqResumePause => 'Will pausing lose progress?';

  @override
  String get faqResumePauseAnswer => 'No. yt-dlp preserves partially downloaded files (.part and .ytdl) when paused. It resumes from the breakpoint.';

  @override
  String get faqResumeCrash => 'Can it recover after a crash?';

  @override
  String get faqResumeCrashAnswer => 'Yes. Restart the app, find the failed task in History, click \'Retry\'. yt-dlp will detect and resume from .part files.';

  @override
  String get openDownloadDir => 'Open Download Folder';

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
  String get expandCompleted => 'Expand Completed';

  @override
  String get collapseCompleted => 'Collapse Completed';

  @override
  String get progress => 'Progress';

  @override
  String get speed => 'Speed';

  @override
  String get remaining => 'Remaining';

  @override
  String get cookieImportFailed => 'Cookie Import Failed';

  @override
  String get saveFailed => 'Save Failed';

  @override
  String get parseFailed => 'Parse Failed';

  @override
  String get addTaskFailed => 'Failed to Add Task';

  @override
  String get pleaseEnterUrl => 'Please enter a complete URL, e.g. https://...';
}
