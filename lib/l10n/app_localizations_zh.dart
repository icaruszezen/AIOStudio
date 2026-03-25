// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class SZh extends S {
  SZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'AIO Studio';

  @override
  String get navProjects => '项目管理';

  @override
  String get navAssets => '资产库';

  @override
  String get navChat => 'AI 对话';

  @override
  String get navImageGen => 'AI 绘图';

  @override
  String get navVideoGen => 'AI 视频';

  @override
  String get navPrompts => '提示词库';

  @override
  String get navSettings => '设置';

  @override
  String get actionRetry => '重试';

  @override
  String get actionCancel => '取消';

  @override
  String get actionDelete => '删除';

  @override
  String get actionSave => '保存';

  @override
  String get actionCreate => '新建';

  @override
  String get actionEdit => '编辑';

  @override
  String get actionSearch => '搜索';

  @override
  String get emptyStateCreateFirst => '开始创作';

  @override
  String get loadingGeneric => '加载中...';

  @override
  String get errorGeneric => '操作失败，请稍后重试';

  @override
  String get errorNetwork => '网络连接失败，请检查网络设置或代理配置';

  @override
  String get errorTimeout => '请求超时，请稍后重试';

  @override
  String get errorFileSystem => '文件操作失败，请检查存储路径权限';

  @override
  String get errorDatabase => '数据库操作失败，请重试';

  @override
  String get pageNotFoundTitle => '页面不存在';

  @override
  String get pageNotFoundDescription => '你访问的页面不存在或已被移除';

  @override
  String get pageNotFoundAction => '返回首页';

  @override
  String get genFailedTitle => '生成失败';

  @override
  String extensionImportSaved(String name) {
    return '已从浏览器保存：$name';
  }

  @override
  String get actionView => '查看';
}
