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
  String get aboutTitle => 'About';

  @override
  String get aboutSubtitle =>
      'Product identity, technical sources, and usage boundaries.';

  @override
  String get aboutAppNameLabel => 'App Name';

  @override
  String get aboutBundleIdLabel => 'Bundle ID / App ID';

  @override
  String get aboutBuiltWithLabel => 'Built With';

  @override
  String get aboutCopyrightLabel => 'Copyright';

  @override
  String get aboutLegalNote =>
      'This tool is only intended for downloading, organizing, and managing content you are legally authorized to use. Do not use it to download, distribute, or obtain pirated digital content.';

  @override
  String get disclaimerTitle => 'Disclaimer';

  @override
  String get disclaimerSubtitle =>
      'Confirm the content source, authorization scope, and intended use comply with local law and platform rules before downloading.';

  @override
  String get disclaimerBody =>
      'This project only provides download and management tools built on yt-dlp and ffmpeg. It does not provide protected content and is not intended for downloading, distributing, or obtaining pirated digital content. Use this tool only when you have the legal right or explicit authorization to do so, and make sure you comply with copyright law, platform terms, and applicable regulations.';

  @override
  String get disclaimerAcknowledge => 'I Understand';

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
  String get recommendedVariantCount => 'Recommended Count';

  @override
  String get recommendedVariantCountHint =>
      'Show 1-5 options in Recommended Quality. Default is 2.';

  @override
  String get externalTools => 'External Tools';

  @override
  String get externalToolsDesc =>
      'Paths to yt-dlp and ffmpeg. Leave empty to use system tools, then bundled versions. Custom paths must validate as the matching tool.';

  @override
  String get ytDlpPath => 'yt-dlp Path';

  @override
  String get ytDlpPathHint =>
      'Highest priority. Must point to yt-dlp; verify with yt-dlp --version';

  @override
  String get ffmpegPath => 'ffmpeg Path';

  @override
  String get ffmpegPathHint =>
      'Highest priority. Must point to ffmpeg; verify with ffmpeg --version';

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
  String get autoClipSection => 'Auto Clip';

  @override
  String get autoClipSectionDesc =>
      'Configure automatic clip cutting after AI analysis';

  @override
  String get autoClipEnabled => 'Enable Auto-Cut';

  @override
  String get autoClipMinConfidence => 'Min Confidence';

  @override
  String get autoClipMaxClips => 'Max Clips/Video';

  @override
  String get autoClipMaxDuration => 'Max Duration';

  @override
  String get autoClipStartOffset => 'Start Offset (ms)';

  @override
  String get autoClipEndOffset => 'End Offset (ms)';

  @override
  String get cutClip => 'Cut';

  @override
  String cutAllClips(int count) {
    return 'Cut All ($count uncut)';
  }

  @override
  String get allClipsCut => 'All clips cut';

  @override
  String cuttingProgress(int completed, int total) {
    return 'Cutting $completed/$total';
  }

  @override
  String get reCut => 'Re-Cut';

  @override
  String get clipCutComplete => 'Cut complete';

  @override
  String get clipCutFailed => 'Cut failed';

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
  String get importCookieFile => 'Import cookies.txt';

  @override
  String get cookieFilePickerTitle => 'Select cookies.txt file';

  @override
  String get cookieManualImportInvalid =>
      'Select a Netscape-format cookies.txt file. Export it from a browser cookie extension, then import it here.';

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
  String cookieImportTimedOut(String browser, int seconds) {
    return '$browser: cookie import exceeded $seconds seconds and was stopped. On macOS release builds this may be waiting for Keychain authorization; check for a system permission prompt, or use Import cookies.txt instead.';
  }

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
  String get downloadingTasks => 'Downloading Tasks';

  @override
  String get failedTasks => 'Failed Tasks';

  @override
  String get failedTasksDesc => 'You can re-add these to the download queue.';

  @override
  String get cancelledTasks => 'Cancelled Tasks';

  @override
  String get cancelledTasksDesc => 'Tasks cancelled by user.';

  @override
  String get pausedTasks => 'Paused Tasks';

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
      'Tool priority: validated settings path, system installation, then bundled version.';

  @override
  String get faqYtDlp => 'How to use your own yt-dlp?';

  @override
  String get faqYtDlpAnswer =>
      'Enter the full path in Settings. It must point to the real yt-dlp executable and pass yt-dlp --version. Leave empty to use system tools first, then bundled versions.';

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
  String get completedStatus => 'Completed';

  @override
  String get enterDomainHint => 'Enter domain then import';

  @override
  String get filePickerSaveDirTitle => 'Select save directory';

  @override
  String get filePickerExecutableTitle => 'Select executable file';

  @override
  String get filePickerUnavailable =>
      'File picker is unavailable in this environment. Enter the path manually.';

  @override
  String moreCookies(int count) {
    return '... $count more cookies';
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

  @override
  String get downloadCompleteTitle => 'Download Complete';

  @override
  String get downloadFailedTitle => 'Download Failed';

  @override
  String get downloadFailedFallback => 'Download failed';

  @override
  String get recommendedOptionLabel => 'Recommended';

  @override
  String get recommendedOptionDesc => 'Good for most downloads';

  @override
  String bestQualityLabel(int height) {
    return 'Best Quality (${height}p video + audio merge)';
  }

  @override
  String get bestQualityDesc =>
      'yt-dlp auto-selects the best video and audio streams and merges them · Recommended';

  @override
  String recommendedQualityWithHeightLabel(int height) {
    return '${height}p Video + Audio Merge';
  }

  @override
  String get recommendedQualityWithHeightDesc =>
      'Use this video stream and auto-select the best audio stream to merge into one file · Recommended';

  @override
  String get recommendedSuffix => 'Recommended';

  @override
  String videoFormatWithHeight(String height) {
    return '${height}p Video';
  }

  @override
  String videoFormatWithId(String id) {
    return 'Video $id';
  }

  @override
  String audioFormatWithId(String id) {
    return 'Audio $id';
  }

  @override
  String get containsAudioTrack => 'With audio';

  @override
  String get videoOnly => 'Video only';

  @override
  String get cookieScriptNotFound => 'extract_cookies.py script not found';

  @override
  String get pythonNotFound => 'Python is not installed or not in PATH';

  @override
  String cookiesExtractedWithBrowserCookie3(String browser, int count) {
    return 'Extracted $count cookies from $browser (browser_cookie3)';
  }

  @override
  String get browserCookie3NotInstalled =>
      'browser_cookie3 is not installed. Run: pip install browser-cookie3';

  @override
  String browserCookie3NoCookies(String browser, String domain) {
    return '$browser: no logged-in cookies found for $domain';
  }

  @override
  String browserCookie3Failed(String browser, String detail) {
    return '$browser: browser_cookie3 failed: $detail';
  }

  @override
  String cookieDecryptFailed(String browser) {
    return '$browser: cookie encryption could not be decrypted';
  }

  @override
  String cookieFileNotGenerated(String browser) {
    return '$browser: cookie file was not created';
  }

  @override
  String loggedInCookiesNotFound(String browser) {
    return '$browser: no logged-in cookies found';
  }

  @override
  String cookiesExtractedFromBrowser(String browser, int count) {
    return 'Extracted $count cookies from $browser';
  }

  @override
  String get cookieSession => 'Session';

  @override
  String get cookieExpired => 'Expired';

  @override
  String cookieExpiresInDays(int count) {
    return 'In $count days';
  }

  @override
  String cookieExpiresInHours(int count) {
    return 'In $count hours';
  }

  @override
  String get cookieExpiresSoon => 'Expires soon';

  @override
  String get ytDlpNonZeroExit => 'yt-dlp exited with a non-zero status';

  @override
  String get clips => 'Clips';

  @override
  String get aiClipAnalysis => 'AI Clip Analysis';

  @override
  String get aiClipAnalysisDesc =>
      'Choose the local analyzer, a Python sidecar, or a cloud model endpoint for semantic clip generation.';

  @override
  String get aiAnalysisProvider => 'Analysis Provider';

  @override
  String get aiProviderBuiltIn => 'Built-in local analyzer';

  @override
  String get aiProviderExternalCommand => 'External command / Python sidecar';

  @override
  String get aiProviderCloudEndpoint => 'Cloud model endpoint';

  @override
  String get builtInClipAnalyzerMode => 'Built-in Strategy';

  @override
  String get builtInBalanced => 'Balanced — visual + audio candidates';

  @override
  String get builtInVisualFocused => 'Visual focused — scene candidates';

  @override
  String get builtInAudioFocused => 'Audio focused — speech candidates';

  @override
  String get aiAnalyzerCommand => 'AI Analyzer Command';

  @override
  String get aiAnalyzerCommandHint =>
      'Optional, e.g. python3 tools/ai_clip_analyzer.py --yolo-model yolov8n.pt --whisper-model small';

  @override
  String get aiCloudProfile => 'Cloud AI Profile';

  @override
  String get aiCloudProfileHint =>
      'Choose the cloud model configuration used for AI clipping';

  @override
  String get aiCloudNoProfiles =>
      'No cloud profiles yet. Pick a vendor, then add a profile.';

  @override
  String get addAiCloudProfile => 'Add Profile';

  @override
  String get deleteAiCloudProfile => 'Delete Profile';

  @override
  String get aiCloudProfileName => 'Profile Name';

  @override
  String get aiCloudVendor => 'Cloud Vendor';

  @override
  String get aiCloudVendorHint =>
      'Switching vendors applies default endpoint and model values; you can still edit them.';

  @override
  String get aiCloudVendorCustom => 'Custom JSON endpoint';

  @override
  String get aiCloudVendorOpenAI => 'OpenAI';

  @override
  String get aiCloudVendorGemini => 'Google Gemini';

  @override
  String get aiCloudVendorAnthropic => 'Anthropic Claude';

  @override
  String get aiCloudVendorGroq => 'Groq';

  @override
  String get aiCloudVendorDeepSeek => 'DeepSeek';

  @override
  String get aiCloudVendorQwen => 'Qwen / DashScope';

  @override
  String get aiCloudVendorOpenRouter => 'OpenRouter';

  @override
  String get aiCloudEndpoint => 'Cloud AI Endpoint';

  @override
  String get aiCloudEndpointHint =>
      'Vendor API URL or custom HTTPS endpoint that returns a segments JSON manifest';

  @override
  String get aiCloudApiKey => 'Cloud AI API Key';

  @override
  String get aiCloudApiKeyHint =>
      'Saved per profile; vendor calls use the matching auth scheme automatically';

  @override
  String get aiCloudModel => 'Cloud AI Model';

  @override
  String get aiCloudModelHint =>
      'For example gpt-4o-mini, gemini-2.0-flash, qwen-plus, or your gateway model id';

  @override
  String get clipLibrary => 'AI Clip Library';

  @override
  String get clipLibraryDesc =>
      'Structured clips generated from visual detection, transcript analysis, and scene boundaries.';

  @override
  String get clipSearch => 'Search Clips';

  @override
  String get clipSearchHint =>
      'Search keywords, objects, transcript text, summaries, or tags';

  @override
  String aiQueuedTasks(int count) {
    return '$count queued';
  }

  @override
  String aiRunningTasks(int count) {
    return '$count analyzing';
  }

  @override
  String clipSegmentsCount(int count) {
    return '$count clips';
  }

  @override
  String get noClipSegments => 'No AI clips yet';

  @override
  String get noClipSegmentsHint =>
      'Downloaded videos with a final media path will be analyzed after download completion.';

  @override
  String get clipReason => 'Reason';

  @override
  String get clipTranscript => 'Transcript';

  @override
  String get clipConfidence => 'Confidence';

  @override
  String get clipStartEarlier => 'Start -1s';

  @override
  String get clipStartLater => 'Start +1s';

  @override
  String get clipEndEarlier => 'End -1s';

  @override
  String get clipEndLater => 'End +1s';

  @override
  String get importing => 'Importing…';

  @override
  String get saveSettingsBtn => 'Save Settings';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get settingsUnsaved => 'Unsaved changes — press Save';

  @override
  String settingsSavedAt(String hour, String minute) {
    return 'Saved at $hour:$minute';
  }

  @override
  String get licenseNavLabel => 'License';

  @override
  String get licenseTitle => 'License & Plans';

  @override
  String get licenseActivate => 'Activate';

  @override
  String get licenseActivating => 'Activating…';

  @override
  String get licenseRefresh => 'Refresh license & devices';

  @override
  String get licenseRefreshing => 'Refreshing…';

  @override
  String get licenseRefreshSuccess => 'License and device status refreshed.';

  @override
  String licenseRefreshFailed(String error) {
    return 'Could not refresh online. Your cached license is kept; check the network and retry. Details: $error';
  }

  @override
  String get licenseCurrentDeviceReleased =>
      'This device was released and the app is now on Free.';

  @override
  String licenseOperationFailed(String error) {
    return 'The operation failed. Nothing was cleared; retry after resolving the issue. Details: $error';
  }

  @override
  String get licensePurchaseStepsTitle => 'Purchase and activation';

  @override
  String get licenseTeamPlanSummary =>
      'Team: ¥298/year · 10 devices · Cloud sync';

  @override
  String get licensePurchaseStepChoose => 'Choose a plan';

  @override
  String get licensePurchaseStepChooseOnline =>
      'Open the official purchase page and complete the order.';

  @override
  String get licensePurchaseStepChooseEmail =>
      'Email orders@hiext.com for payment instructions.';

  @override
  String get licensePurchaseStepChooseMixed =>
      'Configured plans open their secure checkout; plans without one use orders@hiext.com.';

  @override
  String get licensePurchaseStepReceive => 'Receive your code';

  @override
  String get licensePurchaseStepReceiveDescription =>
      'The activation code is delivered to your order email after payment.';

  @override
  String get licensePurchaseStepActivate => 'Activate here';

  @override
  String get licensePurchaseStepActivateDescription =>
      'Paste the code below, then refresh to see license and device status.';

  @override
  String get licenseBuyPro => 'Buy Pro';

  @override
  String get licenseBuyTeam => 'Buy Team';

  @override
  String get licenseEmailBuyPro => 'Email to buy Pro';

  @override
  String get licenseEmailBuyTeam => 'Email to buy Team';

  @override
  String get licensePurchasePageOpened =>
      'The purchase page opened in your browser. Return here with the activation code after checkout.';

  @override
  String get licensePurchaseEmailOpened =>
      'Your mail app opened with purchase details. Send the email, then return here with the activation code you receive.';

  @override
  String licensePurchaseOpenFailed(String url) {
    return 'Could not open the purchase destination. Open this address manually: $url';
  }

  @override
  String get licenseDevicesTitle => 'Active devices';

  @override
  String licenseDeviceUsage(int count, int max) {
    return '$count / $max seats';
  }

  @override
  String get licenseNoDevices => 'No online device list is available yet.';

  @override
  String get licenseNoDevicesHint =>
      'Refresh to load active devices. If the service is temporarily unavailable, the cached license remains unchanged.';

  @override
  String get licenseUnknownDevice => 'Unnamed device';

  @override
  String get licenseCurrentDevice => 'This device';

  @override
  String get licenseDeactivateCurrent => 'Release this device (deactivate)';

  @override
  String licensePlatform(String platform) {
    return 'Platform: $platform';
  }

  @override
  String licenseLastSeen(String date) {
    return 'Last seen: $date';
  }

  @override
  String get licenseReleaseDeviceTitle => 'Release device seat?';

  @override
  String licenseReleaseDeviceConfirm(String name) {
    return 'Release “$name”? That device will lose paid features on its next validation.';
  }

  @override
  String get licenseReleaseDeviceAction => 'Release';

  @override
  String get licenseCancel => 'Cancel';

  @override
  String licenseDeviceReleased(String name) {
    return 'Released $name. The seat can now be used on another device.';
  }

  @override
  String get voiceSwap => 'Voice Swap';

  @override
  String get voiceSwapTitle => 'One-Click Voice Swap';

  @override
  String get voiceSwapDesc =>
      'Fully offline. Replace the video voice with a target voice while keeping the background music intact. Nothing is uploaded.';

  @override
  String get voiceSwapFirstRunNote =>
      'First run downloads ~325MB of models (once). Afterwards everything works offline.';

  @override
  String get voiceSwapPickVideo => 'Pick Video';

  @override
  String get voiceSwapPresetVoiceLabel => 'Target Voice (Preset)';

  @override
  String get voiceSwapStart => 'Start Voice Swap';

  @override
  String get voiceSwapCancel => 'Cancel';

  @override
  String get voiceSwapRunning => 'Processing…';

  @override
  String get voiceSwapDoneTitle => 'Voice Swap Complete';

  @override
  String get voiceSwapOpenOutputFolder => 'Open Output Folder';

  @override
  String get voiceSwapReset => 'Swap Another Video';

  @override
  String get voiceSwapPresetFemale => 'Female';

  @override
  String get voiceSwapPresetMale => 'Male';

  @override
  String get voiceSwapPresetZfXiaobei => 'Xiaobei';

  @override
  String get voiceSwapPresetZfXiaoni => 'Xiaoni';

  @override
  String get voiceSwapPresetZfXiaoxiao => 'Xiaoxiao';

  @override
  String get voiceSwapPresetZfXiaoyi => 'Xiaoyi';

  @override
  String get voiceSwapPresetZmYunjian => 'Yunjian';

  @override
  String get voiceSwapPresetZmYunxi => 'Yunxi';

  @override
  String get voiceSwapPresetZmYunxia => 'Yunxia';

  @override
  String get voiceSwapPresetZmYunyang => 'Yunyang';

  @override
  String get voiceSwapSettingsTitle => 'Voice Swap Settings';

  @override
  String get voiceSwapSettingsModelDir => 'Voice Swap Model Directory';

  @override
  String get voiceSwapSettingsModelDirHint =>
      'Leave empty for the default app-data directory (models live under models/). Models stay local and are not bundled with the app.';

  @override
  String get voiceSwapSettingsPresetVoice => 'Default Voice';

  @override
  String get voiceSwapSettingsAutoDownload => 'Auto-download Models';

  @override
  String get voiceSwapSettingsAutoDownloadHint =>
      'Downloads ~325MB of models on first use. If disabled, missing models fail fast.';

  @override
  String get voiceSwapSettingsSeparationBin => 'Separation CLI Path (optional)';

  @override
  String get voiceSwapSettingsSeparationBinHint =>
      'Highest priority. Must point to the sherpa-onnx-offline-source-separation executable.';

  @override
  String get voiceSwapSettingsLicenseNote =>
      'Model licenses: UVR (MIT, keep attribution), SenseVoice (FunASR, keep model name), Kokoro (Apache-2.0).';
}
