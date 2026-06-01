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
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'Hiext YT GUI'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'yt-dlp 可视化下载器'**
  String get appSubtitle;

  /// No description provided for @newDownload.
  ///
  /// In zh, this message translates to:
  /// **'新建下载'**
  String get newDownload;

  /// No description provided for @downloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get downloading;

  /// No description provided for @history.
  ///
  /// In zh, this message translates to:
  /// **'历史记录'**
  String get history;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @help.
  ///
  /// In zh, this message translates to:
  /// **'帮助'**
  String get help;

  /// No description provided for @pasteLink.
  ///
  /// In zh, this message translates to:
  /// **'粘贴链接'**
  String get pasteLink;

  /// No description provided for @pasteLinkHint.
  ///
  /// In zh, this message translates to:
  /// **'在这里粘贴视频链接'**
  String get pasteLinkHint;

  /// No description provided for @pasteLinkDesc.
  ///
  /// In zh, this message translates to:
  /// **'把视频页面地址放进来，我们帮你找可下载内容。'**
  String get pasteLinkDesc;

  /// No description provided for @parseLink.
  ///
  /// In zh, this message translates to:
  /// **'解析链接'**
  String get parseLink;

  /// No description provided for @parsing.
  ///
  /// In zh, this message translates to:
  /// **'正在解析'**
  String get parsing;

  /// No description provided for @selectFormat.
  ///
  /// In zh, this message translates to:
  /// **'选择格式'**
  String get selectFormat;

  /// No description provided for @selectFormatDesc.
  ///
  /// In zh, this message translates to:
  /// **'解析成功后在这里选择要下载的格式。'**
  String get selectFormatDesc;

  /// No description provided for @selectFormatHint.
  ///
  /// In zh, this message translates to:
  /// **'请先粘贴链接并解析可下载格式。'**
  String get selectFormatHint;

  /// No description provided for @recommendedQuality.
  ///
  /// In zh, this message translates to:
  /// **'推荐品质'**
  String get recommendedQuality;

  /// No description provided for @recommendedQualityDesc.
  ///
  /// In zh, this message translates to:
  /// **'自动选取最佳视频和音频流合并输出单个文件。'**
  String get recommendedQualityDesc;

  /// No description provided for @videoFormats.
  ///
  /// In zh, this message translates to:
  /// **'视频格式'**
  String get videoFormats;

  /// No description provided for @audioFormats.
  ///
  /// In zh, this message translates to:
  /// **'音频格式'**
  String get audioFormats;

  /// No description provided for @checkToSelect.
  ///
  /// In zh, this message translates to:
  /// **'勾选要下载的格式，可以多选。'**
  String get checkToSelect;

  /// No description provided for @downloadSelected.
  ///
  /// In zh, this message translates to:
  /// **'下载所选'**
  String get downloadSelected;

  /// No description provided for @addingTask.
  ///
  /// In zh, this message translates to:
  /// **'正在加入任务'**
  String get addingTask;

  /// No description provided for @taskList.
  ///
  /// In zh, this message translates to:
  /// **'任务列表'**
  String get taskList;

  /// No description provided for @taskListDesc.
  ///
  /// In zh, this message translates to:
  /// **'粘贴链接并选择格式后，下载任务会显示在这里。'**
  String get taskListDesc;

  /// No description provided for @noDownloadTasks.
  ///
  /// In zh, this message translates to:
  /// **'还没有下载任务'**
  String get noDownloadTasks;

  /// No description provided for @noDownloadTasksHint.
  ///
  /// In zh, this message translates to:
  /// **'回到「新建下载」页粘贴链接开始'**
  String get noDownloadTasksHint;

  /// No description provided for @formatsCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个格式'**
  String formatsCount(int count);

  /// No description provided for @saveAndQuality.
  ///
  /// In zh, this message translates to:
  /// **'保存与画质'**
  String get saveAndQuality;

  /// No description provided for @saveAndQualityDesc.
  ///
  /// In zh, this message translates to:
  /// **'文件保存位置和默认下载质量。'**
  String get saveAndQualityDesc;

  /// No description provided for @saveDirectory.
  ///
  /// In zh, this message translates to:
  /// **'保存目录'**
  String get saveDirectory;

  /// No description provided for @defaultQuality.
  ///
  /// In zh, this message translates to:
  /// **'默认画质 / 格式'**
  String get defaultQuality;

  /// No description provided for @defaultQualityHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 best、bestvideo+bestaudio 或 yt-dlp format id'**
  String get defaultQualityHint;

  /// No description provided for @externalTools.
  ///
  /// In zh, this message translates to:
  /// **'外部工具'**
  String get externalTools;

  /// No description provided for @externalToolsDesc.
  ///
  /// In zh, this message translates to:
  /// **'yt-dlp 和 ffmpeg 的路径，留空则使用应用内置版本。'**
  String get externalToolsDesc;

  /// No description provided for @ytDlpPath.
  ///
  /// In zh, this message translates to:
  /// **'yt-dlp 路径'**
  String get ytDlpPath;

  /// No description provided for @ytDlpPathHint.
  ///
  /// In zh, this message translates to:
  /// **'留空时使用应用内置 yt-dlp'**
  String get ytDlpPathHint;

  /// No description provided for @ffmpegPath.
  ///
  /// In zh, this message translates to:
  /// **'ffmpeg 路径'**
  String get ffmpegPath;

  /// No description provided for @ffmpegPathHint.
  ///
  /// In zh, this message translates to:
  /// **'留空时使用应用内置 ffmpeg'**
  String get ffmpegPathHint;

  /// No description provided for @downloadMode.
  ///
  /// In zh, this message translates to:
  /// **'下载模式'**
  String get downloadMode;

  /// No description provided for @downloadModeDesc.
  ///
  /// In zh, this message translates to:
  /// **'控制并行任务数量和调度策略。'**
  String get downloadModeDesc;

  /// No description provided for @scheduleMode.
  ///
  /// In zh, this message translates to:
  /// **'调度模式'**
  String get scheduleMode;

  /// No description provided for @serialDownload.
  ///
  /// In zh, this message translates to:
  /// **'串行下载 — 一个一个来'**
  String get serialDownload;

  /// No description provided for @queueDownload.
  ///
  /// In zh, this message translates to:
  /// **'队列下载 — 排队等待'**
  String get queueDownload;

  /// No description provided for @concurrentDownload.
  ///
  /// In zh, this message translates to:
  /// **'并发下载 — 同时进行'**
  String get concurrentDownload;

  /// No description provided for @concurrentCount.
  ///
  /// In zh, this message translates to:
  /// **'并发数量'**
  String get concurrentCount;

  /// No description provided for @concurrentHint.
  ///
  /// In zh, this message translates to:
  /// **'同时下载 {count} 个任务'**
  String concurrentHint(int count);

  /// No description provided for @concurrentDisabledHint.
  ///
  /// In zh, this message translates to:
  /// **'仅并发模式下生效'**
  String get concurrentDisabledHint;

  /// No description provided for @additionalOptions.
  ///
  /// In zh, this message translates to:
  /// **'附加选项'**
  String get additionalOptions;

  /// No description provided for @downloadSubtitles.
  ///
  /// In zh, this message translates to:
  /// **'下载字幕'**
  String get downloadSubtitles;

  /// No description provided for @downloadSubtitlesDesc.
  ///
  /// In zh, this message translates to:
  /// **'启动 yt-dlp 时追加 --write-subs'**
  String get downloadSubtitlesDesc;

  /// No description provided for @downloadThumbnail.
  ///
  /// In zh, this message translates to:
  /// **'下载封面'**
  String get downloadThumbnail;

  /// No description provided for @downloadThumbnailDesc.
  ///
  /// In zh, this message translates to:
  /// **'启动 yt-dlp 时追加 --write-thumbnail'**
  String get downloadThumbnailDesc;

  /// No description provided for @restoreDefaults.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get restoreDefaults;

  /// No description provided for @browseDirectory.
  ///
  /// In zh, this message translates to:
  /// **'浏览目录'**
  String get browseDirectory;

  /// No description provided for @browseFile.
  ///
  /// In zh, this message translates to:
  /// **'浏览文件'**
  String get browseFile;

  /// No description provided for @cookieManagement.
  ///
  /// In zh, this message translates to:
  /// **'Cookie 管理'**
  String get cookieManagement;

  /// No description provided for @cookieManagementDesc.
  ///
  /// In zh, this message translates to:
  /// **'先在浏览器中登录目标网站，再导入 cookies。登录后才能获取高清格式。'**
  String get cookieManagementDesc;

  /// No description provided for @browser.
  ///
  /// In zh, this message translates to:
  /// **'浏览器'**
  String get browser;

  /// No description provided for @domain.
  ///
  /// In zh, this message translates to:
  /// **'域名'**
  String get domain;

  /// No description provided for @importBtn.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importBtn;

  /// No description provided for @commonSites.
  ///
  /// In zh, this message translates to:
  /// **'常用网站'**
  String get commonSites;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @reimport.
  ///
  /// In zh, this message translates to:
  /// **'重新导入'**
  String get reimport;

  /// No description provided for @viewDetails.
  ///
  /// In zh, this message translates to:
  /// **'查看详情'**
  String get viewDetails;

  /// No description provided for @cookieImportFailed.
  ///
  /// In zh, this message translates to:
  /// **'Cookie 导入失败（已尝试所有浏览器）'**
  String get cookieImportFailed;

  /// No description provided for @cookieImportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {domain} 的 cookies'**
  String cookieImportSuccess(String domain);

  /// No description provided for @noHistory.
  ///
  /// In zh, this message translates to:
  /// **'没有历史'**
  String get noHistory;

  /// No description provided for @noHistoryDesc.
  ///
  /// In zh, this message translates to:
  /// **'完成或取消下载后，记录会显示在这里。'**
  String get noHistoryDesc;

  /// No description provided for @noHistoryYet.
  ///
  /// In zh, this message translates to:
  /// **'还没有历史记录'**
  String get noHistoryYet;

  /// No description provided for @completedTasks.
  ///
  /// In zh, this message translates to:
  /// **'已完成任务'**
  String get completedTasks;

  /// No description provided for @completedTasksDesc.
  ///
  /// In zh, this message translates to:
  /// **'下载成功的任务。'**
  String get completedTasksDesc;

  /// No description provided for @failedTasks.
  ///
  /// In zh, this message translates to:
  /// **'失败任务'**
  String get failedTasks;

  /// No description provided for @failedTasksDesc.
  ///
  /// In zh, this message translates to:
  /// **'可以从这里重新加入下载队列。'**
  String get failedTasksDesc;

  /// No description provided for @cancelledTasks.
  ///
  /// In zh, this message translates to:
  /// **'已取消任务'**
  String get cancelledTasks;

  /// No description provided for @cancelledTasksDesc.
  ///
  /// In zh, this message translates to:
  /// **'用户取消的任务。'**
  String get cancelledTasksDesc;

  /// No description provided for @noRecordsHere.
  ///
  /// In zh, this message translates to:
  /// **'暂无记录'**
  String get noRecordsHere;

  /// No description provided for @openFolder.
  ///
  /// In zh, this message translates to:
  /// **'打开文件夹'**
  String get openFolder;

  /// No description provided for @threeSteps.
  ///
  /// In zh, this message translates to:
  /// **'三步上手'**
  String get threeSteps;

  /// No description provided for @threeStepsDesc.
  ///
  /// In zh, this message translates to:
  /// **'下载视频只需要三步。'**
  String get threeStepsDesc;

  /// No description provided for @step1.
  ///
  /// In zh, this message translates to:
  /// **'粘贴链接'**
  String get step1;

  /// No description provided for @step1Desc.
  ///
  /// In zh, this message translates to:
  /// **'在「新建下载」页面粘贴视频网页地址（支持 YouTube、Bilibili 等数千个网站）。'**
  String get step1Desc;

  /// No description provided for @step2.
  ///
  /// In zh, this message translates to:
  /// **'选择格式'**
  String get step2;

  /// No description provided for @step2Desc.
  ///
  /// In zh, this message translates to:
  /// **'点击「解析链接」查看可选格式，选一个合适的画质或音频格式。'**
  String get step2Desc;

  /// No description provided for @step3.
  ///
  /// In zh, this message translates to:
  /// **'开始下载'**
  String get step3;

  /// No description provided for @step3Desc.
  ///
  /// In zh, this message translates to:
  /// **'点击「下载所选格式」，任务会加入队列并自动开始。'**
  String get step3Desc;

  /// No description provided for @modeHelp.
  ///
  /// In zh, this message translates to:
  /// **'下载模式说明'**
  String get modeHelp;

  /// No description provided for @modeHelpDesc.
  ///
  /// In zh, this message translates to:
  /// **'在「设置」页面可以切换三种模式。'**
  String get modeHelpDesc;

  /// No description provided for @modeSerial.
  ///
  /// In zh, this message translates to:
  /// **'串行下载'**
  String get modeSerial;

  /// No description provided for @modeSerialDesc.
  ///
  /// In zh, this message translates to:
  /// **'一次只下载一个任务，适合带宽有限的场景。'**
  String get modeSerialDesc;

  /// No description provided for @modeQueue.
  ///
  /// In zh, this message translates to:
  /// **'队列下载'**
  String get modeQueue;

  /// No description provided for @modeQueueDesc.
  ///
  /// In zh, this message translates to:
  /// **'手动管理下载次序，完成后不会自动开始下一个。'**
  String get modeQueueDesc;

  /// No description provided for @modeConcurrent.
  ///
  /// In zh, this message translates to:
  /// **'并发下载'**
  String get modeConcurrent;

  /// No description provided for @modeConcurrentDesc.
  ///
  /// In zh, this message translates to:
  /// **'同时下载多个任务（1-8），适合带宽充裕的场景。'**
  String get modeConcurrentDesc;

  /// No description provided for @toolConfig.
  ///
  /// In zh, this message translates to:
  /// **'工具配置'**
  String get toolConfig;

  /// No description provided for @toolConfigDesc.
  ///
  /// In zh, this message translates to:
  /// **'应用内置了 yt-dlp 和 ffmpeg，也可以使用系统安装的版本。'**
  String get toolConfigDesc;

  /// No description provided for @faqYtDlp.
  ///
  /// In zh, this message translates to:
  /// **'如何使用自己安装的 yt-dlp？'**
  String get faqYtDlp;

  /// No description provided for @faqYtDlpAnswer.
  ///
  /// In zh, this message translates to:
  /// **'在「设置」页面的「yt-dlp 路径」中输入完整路径，留空则使用应用内置版本。'**
  String get faqYtDlpAnswer;

  /// No description provided for @faqFfmpeg.
  ///
  /// In zh, this message translates to:
  /// **'ffmpeg 有什么用？'**
  String get faqFfmpeg;

  /// No description provided for @faqFfmpegAnswer.
  ///
  /// In zh, this message translates to:
  /// **'yt-dlp 使用 ffmpeg 进行格式转换和合并。缺少 ffmpeg 时部分功能可能不可用。'**
  String get faqFfmpegAnswer;

  /// No description provided for @faqSites.
  ///
  /// In zh, this message translates to:
  /// **'支持哪些视频网站？'**
  String get faqSites;

  /// No description provided for @faqSitesAnswer.
  ///
  /// In zh, this message translates to:
  /// **'yt-dlp 支持数千个网站，包括 YouTube、Bilibili、Twitter/X、TikTok、Instagram 等。'**
  String get faqSitesAnswer;

  /// No description provided for @resumeHelp.
  ///
  /// In zh, this message translates to:
  /// **'断点续传'**
  String get resumeHelp;

  /// No description provided for @resumeHelpDesc.
  ///
  /// In zh, this message translates to:
  /// **'下载中断后可以继续，不需要从头开始。'**
  String get resumeHelpDesc;

  /// No description provided for @faqResumePause.
  ///
  /// In zh, this message translates to:
  /// **'暂停后恢复会丢失进度吗？'**
  String get faqResumePause;

  /// No description provided for @faqResumePauseAnswer.
  ///
  /// In zh, this message translates to:
  /// **'不会。yt-dlp 会保留已下载的部分文件，恢复后会从断点继续。'**
  String get faqResumePauseAnswer;

  /// No description provided for @faqResumeCrash.
  ///
  /// In zh, this message translates to:
  /// **'应用崩溃后能恢复吗？'**
  String get faqResumeCrash;

  /// No description provided for @faqResumeCrashAnswer.
  ///
  /// In zh, this message translates to:
  /// **'可以。重启应用后在历史记录中点击「重试」，yt-dlp 会自动检测并续传。'**
  String get faqResumeCrashAnswer;

  /// No description provided for @expandCompleted.
  ///
  /// In zh, this message translates to:
  /// **'展开已完成任务'**
  String get expandCompleted;

  /// No description provided for @collapseCompleted.
  ///
  /// In zh, this message translates to:
  /// **'收起已完成任务'**
  String get collapseCompleted;

  /// No description provided for @deleteRecord.
  ///
  /// In zh, this message translates to:
  /// **'仅删除记录'**
  String get deleteRecord;

  /// No description provided for @deleteWithFiles.
  ///
  /// In zh, this message translates to:
  /// **'同时删除下载文件'**
  String get deleteWithFiles;

  /// No description provided for @confirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除历史记录'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteContent.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除「{title}」吗？'**
  String confirmDeleteContent(String title);

  /// No description provided for @parseFailed.
  ///
  /// In zh, this message translates to:
  /// **'解析失败：{error}'**
  String parseFailed(String error);

  /// No description provided for @addTaskFailed.
  ///
  /// In zh, this message translates to:
  /// **'加入任务失败：{error}'**
  String addTaskFailed(String error);

  /// No description provided for @pleaseEnterUrl.
  ///
  /// In zh, this message translates to:
  /// **'请输入完整链接，例如 https://...'**
  String get pleaseEnterUrl;

  /// No description provided for @cookiePrompt.
  ///
  /// In zh, this message translates to:
  /// **'该网站需要登录才能获取高清格式。先在浏览器登录 {host}，然后去设置页导入 Cookies。'**
  String cookiePrompt(String host);

  /// No description provided for @downloadSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'下载所选 ({count} 项)'**
  String downloadSelectedCount(int count);

  /// No description provided for @video.
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get video;

  /// No description provided for @audio.
  ///
  /// In zh, this message translates to:
  /// **'音频'**
  String get audio;

  /// No description provided for @unknownError.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get unknownError;

  /// No description provided for @fileLabel.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get fileLabel;

  /// No description provided for @alreadyImported.
  ///
  /// In zh, this message translates to:
  /// **'已导入'**
  String get alreadyImported;

  /// No description provided for @daysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天前'**
  String daysAgo(int count);

  /// No description provided for @justImported.
  ///
  /// In zh, this message translates to:
  /// **'刚导入'**
  String get justImported;

  /// No description provided for @cookiesCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个 cookie'**
  String cookiesCount(int count);

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @additionalOptionsDesc.
  ///
  /// In zh, this message translates to:
  /// **'下载时附带字幕和封面文件。'**
  String get additionalOptionsDesc;

  /// No description provided for @openDownloadDir.
  ///
  /// In zh, this message translates to:
  /// **'打开下载目录'**
  String get openDownloadDir;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
