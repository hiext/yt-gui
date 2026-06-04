// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Hiext YT GUI';

  @override
  String get appSubtitle => 'yt-dlp 可视化下载器';

  @override
  String get newDownload => '新建下载';

  @override
  String get downloading => '下载中';

  @override
  String get history => '历史记录';

  @override
  String get settings => '设置';

  @override
  String get help => '帮助';

  @override
  String get disclaimerTitle => '使用声明';

  @override
  String get disclaimerSubtitle => '请在下载前确认内容来源、授权范围和使用目的符合当地法律及平台规则。';

  @override
  String get disclaimerBody =>
      '本项目仅提供基于 yt-dlp 和 ffmpeg 的下载与管理工具，不提供任何受保护内容，也不以下载、传播或获取盗版数字数据为目的。请仅在拥有合法权利或已获得明确授权的前提下使用本工具，并自行遵守相关版权法律、平台服务条款及当地法规。';

  @override
  String get pasteLink => '粘贴链接';

  @override
  String get pasteLinkHint => '在这里粘贴视频链接';

  @override
  String get pasteLinkDesc => '把视频页面地址放进来，我们帮你找可下载内容。';

  @override
  String get parseLink => '解析链接';

  @override
  String get parsing => '正在解析';

  @override
  String get selectFormat => '选择格式';

  @override
  String get selectFormatDesc => '解析成功后在这里选择要下载的格式。';

  @override
  String get selectFormatHint => '请先粘贴链接并解析可下载格式。';

  @override
  String get recommendedQuality => '推荐品质';

  @override
  String get recommendedQualityDesc => '自动选取最佳视频和音频流合并输出单个文件。';

  @override
  String get videoFormats => '视频格式';

  @override
  String get audioFormats => '音频格式';

  @override
  String get checkToSelect => '勾选要下载的格式，可以多选。';

  @override
  String get downloadSelected => '下载所选';

  @override
  String get addingTask => '正在加入任务';

  @override
  String get taskList => '任务列表';

  @override
  String get taskListDesc => '粘贴链接并选择格式后，下载任务会显示在这里。';

  @override
  String get noDownloadTasks => '还没有下载任务';

  @override
  String get noDownloadTasksHint => '回到「新建下载」页粘贴链接开始';

  @override
  String formatsCount(int count) {
    return '$count 个格式';
  }

  @override
  String get saveAndQuality => '保存与画质';

  @override
  String get saveAndQualityDesc => '文件保存位置和默认下载质量。';

  @override
  String get saveDirectory => '保存目录';

  @override
  String get defaultQuality => '默认画质 / 格式';

  @override
  String get defaultQualityHint =>
      '例如 best、bestvideo+bestaudio 或 yt-dlp format id';

  @override
  String get externalTools => '外部工具';

  @override
  String get externalToolsDesc => 'yt-dlp 和 ffmpeg 的路径，留空则使用应用内置版本。';

  @override
  String get ytDlpPath => 'yt-dlp 路径';

  @override
  String get ytDlpPathHint => '留空时使用应用内置 yt-dlp';

  @override
  String get ffmpegPath => 'ffmpeg 路径';

  @override
  String get ffmpegPathHint => '留空时使用应用内置 ffmpeg';

  @override
  String get downloadMode => '下载模式';

  @override
  String get downloadModeDesc => '控制并行任务数量和调度策略。';

  @override
  String get scheduleMode => '调度模式';

  @override
  String get serialDownload => '串行下载 — 一个一个来';

  @override
  String get queueDownload => '队列下载 — 排队等待';

  @override
  String get concurrentDownload => '并发下载 — 同时进行';

  @override
  String get concurrentCount => '并发数量';

  @override
  String concurrentHint(int count) {
    return '同时下载 $count 个任务';
  }

  @override
  String get concurrentDisabledHint => '仅并发模式下生效';

  @override
  String get additionalOptions => '附加选项';

  @override
  String get downloadSubtitles => '下载字幕';

  @override
  String get downloadSubtitlesDesc => '启动 yt-dlp 时追加 --write-subs';

  @override
  String get downloadThumbnail => '下载封面';

  @override
  String get downloadThumbnailDesc => '启动 yt-dlp 时追加 --write-thumbnail';

  @override
  String get restoreDefaults => '恢复默认';

  @override
  String get browseDirectory => '浏览目录';

  @override
  String get browseFile => '浏览文件';

  @override
  String get cookieManagement => 'Cookie 管理';

  @override
  String get cookieManagementDesc => '先在浏览器中登录目标网站，再导入 cookies。登录后才能获取高清格式。';

  @override
  String get browser => '浏览器';

  @override
  String get domain => '域名';

  @override
  String get importBtn => '导入';

  @override
  String get commonSites => '常用网站';

  @override
  String get delete => '删除';

  @override
  String get reimport => '重新导入';

  @override
  String get viewDetails => '查看详情';

  @override
  String get cookieImportFailed => 'Cookie 导入失败（已尝试所有浏览器）';

  @override
  String cookieImportSuccess(String domain) {
    return '已导入 $domain 的 cookies';
  }

  @override
  String get noHistory => '没有历史';

  @override
  String get noHistoryDesc => '完成或取消下载后，记录会显示在这里。';

  @override
  String get noHistoryYet => '还没有历史记录';

  @override
  String get completedTasks => '已完成任务';

  @override
  String get completedTasksDesc => '下载成功的任务。';

  @override
  String get downloadingTasks => '下载中任务';

  @override
  String get failedTasks => '失败任务';

  @override
  String get failedTasksDesc => '可以从这里重新加入下载队列。';

  @override
  String get cancelledTasks => '已取消任务';

  @override
  String get cancelledTasksDesc => '用户取消的任务。';

  @override
  String get pausedTasks => '已暂停任务';

  @override
  String get noRecordsHere => '暂无记录';

  @override
  String get openFolder => '打开文件夹';

  @override
  String get threeSteps => '三步上手';

  @override
  String get threeStepsDesc => '下载视频只需要三步。';

  @override
  String get step1 => '粘贴链接';

  @override
  String get step1Desc => '在「新建下载」页面粘贴视频网页地址（支持 YouTube、Bilibili 等数千个网站）。';

  @override
  String get step2 => '选择格式';

  @override
  String get step2Desc => '点击「解析链接」查看可选格式，选一个合适的画质或音频格式。';

  @override
  String get step3 => '开始下载';

  @override
  String get step3Desc => '点击「下载所选格式」，任务会加入队列并自动开始。';

  @override
  String get modeHelp => '下载模式说明';

  @override
  String get modeHelpDesc => '在「设置」页面可以切换三种模式。';

  @override
  String get modeSerial => '串行下载';

  @override
  String get modeSerialDesc => '一次只下载一个任务，适合带宽有限的场景。';

  @override
  String get modeQueue => '队列下载';

  @override
  String get modeQueueDesc => '手动管理下载次序，完成后不会自动开始下一个。';

  @override
  String get modeConcurrent => '并发下载';

  @override
  String get modeConcurrentDesc => '同时下载多个任务（1-8），适合带宽充裕的场景。';

  @override
  String get toolConfig => '工具配置';

  @override
  String get toolConfigDesc => '应用内置了 yt-dlp 和 ffmpeg，也可以使用系统安装的版本。';

  @override
  String get faqYtDlp => '如何使用自己安装的 yt-dlp？';

  @override
  String get faqYtDlpAnswer => '在「设置」页面的「yt-dlp 路径」中输入完整路径，留空则使用应用内置版本。';

  @override
  String get faqFfmpeg => 'ffmpeg 有什么用？';

  @override
  String get faqFfmpegAnswer =>
      'yt-dlp 使用 ffmpeg 进行格式转换和合并。缺少 ffmpeg 时部分功能可能不可用。';

  @override
  String get faqSites => '支持哪些视频网站？';

  @override
  String get faqSitesAnswer =>
      'yt-dlp 支持数千个网站，包括 YouTube、Bilibili、Twitter/X、TikTok、Instagram 等。';

  @override
  String get resumeHelp => '断点续传';

  @override
  String get resumeHelpDesc => '下载中断后可以继续，不需要从头开始。';

  @override
  String get faqResumePause => '暂停后恢复会丢失进度吗？';

  @override
  String get faqResumePauseAnswer => '不会。yt-dlp 会保留已下载的部分文件，恢复后会从断点继续。';

  @override
  String get faqResumeCrash => '应用崩溃后能恢复吗？';

  @override
  String get faqResumeCrashAnswer => '可以。重启应用后在历史记录中点击「重试」，yt-dlp 会自动检测并续传。';

  @override
  String get expandCompleted => '展开已完成任务';

  @override
  String get collapseCompleted => '收起已完成任务';

  @override
  String get deleteRecord => '仅删除记录';

  @override
  String get deleteWithFiles => '同时删除下载文件';

  @override
  String get confirmDelete => '删除历史记录';

  @override
  String confirmDeleteContent(String title) {
    return '确定要删除「$title」吗？';
  }

  @override
  String parseFailed(String error) {
    return '解析失败：$error';
  }

  @override
  String addTaskFailed(String error) {
    return '加入任务失败：$error';
  }

  @override
  String get pleaseEnterUrl => '请输入完整链接，例如 https://...';

  @override
  String cookiePrompt(String host) {
    return '该网站需要登录才能获取高清格式。先在浏览器登录 $host，然后去设置页导入 Cookies。';
  }

  @override
  String downloadSelectedCount(int count) {
    return '下载所选 ($count 项)';
  }

  @override
  String get video => '视频';

  @override
  String get audio => '音频';

  @override
  String get unknownError => '未知错误';

  @override
  String get fileLabel => '文件';

  @override
  String get alreadyImported => '已导入';

  @override
  String daysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get justImported => '刚导入';

  @override
  String cookiesCount(int count) {
    return '$count 个 cookie';
  }

  @override
  String get completedStatus => '已完成';

  @override
  String get enterDomainHint => '输入域名后点导入';

  @override
  String get filePickerSaveDirTitle => '选择保存目录';

  @override
  String get filePickerExecutableTitle => '选择可执行文件';

  @override
  String moreCookies(int count) {
    return '... 还有 $count 个 cookie';
  }

  @override
  String get retry => '重试';

  @override
  String get cancel => '取消';

  @override
  String get additionalOptionsDesc => '下载时附带字幕和封面文件。';

  @override
  String get openDownloadDir => '打开下载目录';

  @override
  String get downloadCompleteTitle => '下载完成';

  @override
  String get downloadFailedTitle => '下载失败';

  @override
  String get downloadFailedFallback => '下载失败';

  @override
  String get recommendedOptionLabel => '推荐';

  @override
  String get recommendedOptionDesc => '适合大多数人';

  @override
  String bestQualityLabel(int height) {
    return '最佳品质（${height}p 视频+音频合并）';
  }

  @override
  String get bestQualityDesc => 'yt-dlp 自动选取最佳视频和音频流合并 · 推荐';

  @override
  String get recommendedSuffix => '推荐';

  @override
  String videoFormatWithHeight(String height) {
    return '${height}p 视频';
  }

  @override
  String videoFormatWithId(String id) {
    return '视频 $id';
  }

  @override
  String audioFormatWithId(String id) {
    return '音频 $id';
  }

  @override
  String get containsAudioTrack => '含音轨';

  @override
  String get videoOnly => '仅视频';

  @override
  String get cookieScriptNotFound => 'extract_cookies.py 脚本未找到';

  @override
  String get pythonNotFound => 'Python 未安装或不在 PATH 中';

  @override
  String cookiesExtractedWithBrowserCookie3(String browser, int count) {
    return '已从 $browser 提取 $count 个 cookie（browser_cookie3）';
  }

  @override
  String get browserCookie3NotInstalled =>
      'browser_cookie3 未安装。运行: pip install browser-cookie3';

  @override
  String browserCookie3NoCookies(String browser, String domain) {
    return '$browser: 未找到 $domain 的已登录 cookie';
  }

  @override
  String browserCookie3Failed(String browser, String detail) {
    return '$browser: browser_cookie3 失败: $detail';
  }

  @override
  String cookieDecryptFailed(String browser) {
    return '$browser: cookie 加密无法解密';
  }

  @override
  String cookieFileNotGenerated(String browser) {
    return '$browser: 未生成 cookie 文件';
  }

  @override
  String loggedInCookiesNotFound(String browser) {
    return '$browser: 未找到已登录的 cookie';
  }

  @override
  String cookiesExtractedFromBrowser(String browser, int count) {
    return '已从 $browser 提取 $count 个 cookie';
  }

  @override
  String get cookieSession => '会话';

  @override
  String get cookieExpired => '已过期';

  @override
  String cookieExpiresInDays(int count) {
    return '$count 天后';
  }

  @override
  String cookieExpiresInHours(int count) {
    return '$count 小时后';
  }

  @override
  String get cookieExpiresSoon => '即将过期';

  @override
  String get ytDlpNonZeroExit => 'yt-dlp 以非零状态退出';
}
