import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
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
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

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

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'AIO Studio'**
  String get appName;

  /// No description provided for @navProjects.
  ///
  /// In zh, this message translates to:
  /// **'项目管理'**
  String get navProjects;

  /// No description provided for @navAssets.
  ///
  /// In zh, this message translates to:
  /// **'资产库'**
  String get navAssets;

  /// No description provided for @navChat.
  ///
  /// In zh, this message translates to:
  /// **'AI 对话'**
  String get navChat;

  /// No description provided for @navImageGen.
  ///
  /// In zh, this message translates to:
  /// **'AI 绘图'**
  String get navImageGen;

  /// No description provided for @navVideoGen.
  ///
  /// In zh, this message translates to:
  /// **'AI 视频'**
  String get navVideoGen;

  /// No description provided for @navPrompts.
  ///
  /// In zh, this message translates to:
  /// **'提示词库'**
  String get navPrompts;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @actionRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get actionRetry;

  /// No description provided for @actionCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get actionDelete;

  /// No description provided for @actionSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get actionSave;

  /// No description provided for @actionCreate.
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get actionCreate;

  /// No description provided for @actionEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get actionEdit;

  /// No description provided for @actionSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get actionSearch;

  /// No description provided for @emptyStateCreateFirst.
  ///
  /// In zh, this message translates to:
  /// **'开始创作'**
  String get emptyStateCreateFirst;

  /// No description provided for @loadingGeneric.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loadingGeneric;

  /// No description provided for @errorGeneric.
  ///
  /// In zh, this message translates to:
  /// **'操作失败，请稍后重试'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，请检查网络设置或代理配置'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In zh, this message translates to:
  /// **'请求超时，请稍后重试'**
  String get errorTimeout;

  /// No description provided for @errorFileSystem.
  ///
  /// In zh, this message translates to:
  /// **'文件操作失败，请检查存储路径权限'**
  String get errorFileSystem;

  /// No description provided for @errorDatabase.
  ///
  /// In zh, this message translates to:
  /// **'数据库操作失败，请重试'**
  String get errorDatabase;

  /// No description provided for @pageNotFoundTitle.
  ///
  /// In zh, this message translates to:
  /// **'页面不存在'**
  String get pageNotFoundTitle;

  /// No description provided for @pageNotFoundDescription.
  ///
  /// In zh, this message translates to:
  /// **'你访问的页面不存在或已被移除'**
  String get pageNotFoundDescription;

  /// No description provided for @pageNotFoundAction.
  ///
  /// In zh, this message translates to:
  /// **'返回首页'**
  String get pageNotFoundAction;

  /// No description provided for @genFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'生成失败'**
  String get genFailedTitle;

  /// No description provided for @extensionImportSaved.
  ///
  /// In zh, this message translates to:
  /// **'已从浏览器保存：{name}'**
  String extensionImportSaved(String name);

  /// No description provided for @actionView.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get actionView;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'zh':
      return SZh();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
