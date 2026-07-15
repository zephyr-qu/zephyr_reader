import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/dictionary/builtin_dictionary.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/dictionary.dart' as dict_api;
import 'package:zephyr_reader/src/rust/domain/dictionary/models.dart';


@injectable
/// 词典管理 ViewModel。
///
/// 管理当前词典路径、词典列表的加载/切换/删除/重置，
/// 所有设置变更自动持久化。
class DictionarySettingsViewModel {
  final PreferencesService _prefs;

  /// 当前词典文件路径（持久化）。
  late final currentMdxPath = persistedNullableString(
    _prefs,
    SettingsKeys.dictMdxPath,
  );

  /// 已注册词典列表。
  final dictionaries = signal<List<Dictionary>>([]);

  /// 列表加载状态。
  final loading = signal(true);

  DictionarySettingsViewModel(this._prefs);

  /// 加载已注册词典列表。
  Future<void> load() async {
    loading.value = true;
    try {
      dictionaries.value = await dict_api.listDictionaries();
    } catch (e) {
      Logging.warning('加载词典列表失败: $e');
    }
    loading.value = false;
  }

  /// 切换当前词典为 [dict] 并重新初始化引擎。
  ///
  /// 返回词典名称以用于 UI 提示，失败返回 `null`。
  Future<String?> switchDict(Dictionary dict) async {
    try {
      dict_api.closeDictionary();
      await dict_api.initDictionary(mdxPath: dict.filePath);
      currentMdxPath.value = dict.filePath;
      return dict.name;
    } catch (e, st) {
      Logging.error('dict switch failed', exception: e, stackTrace: st);
      return null;
    }
  }

  /// 从 [filePath] 加载并注册新词典。
  ///
  /// 自动查找同名的 .mdd 资源文件。
  /// 返回词典显示名用于 UI 提示，失败返回 `null`。
  Future<String?> addDictFromPath(String filePath) async {
    final mddPath = filePath.replaceAll('.mdx', '.mdd');
    final mddExists = File(mddPath).existsSync();

    try {
      dict_api.closeDictionary();
      await dict_api.initDictionary(
        mdxPath: filePath,
        mddPath: mddExists ? mddPath : null,
      );
      currentMdxPath.value = filePath;

      final name = filePath
          .split(Platform.pathSeparator)
          .last
          .replaceAll('.mdx', '');
      await dict_api.upsertDictionary(
        dict: Dictionary(
          id: '',
          name: name,
          filePath: filePath,
          dictType: 'MDict',
          langFrom: null,
          langTo: null,
          isEnabled: true,
          wordCount: 0,
          addedAt: DateTime.now(),
        ),
      );
      await load();
      return name;
    } catch (e, st) {
      Logging.error('dict load failed', exception: e, stackTrace: st);
      return null;
    }
  }

  /// 删除词典 [dict] 的记录。
  ///
  /// 如果当前正使用该词典，自动切回内置词典。
  /// 返回删除是否成功。
  Future<bool> deleteDict(Dictionary dict) async {
    try {
      await dict_api.deleteDictionary(id: dict.id);
      if (currentMdxPath.value == dict.filePath) {
        await resetToBuiltin();
      }
      await load();
      return true;
    } catch (e, st) {
      Logging.error('dict delete failed', exception: e, stackTrace: st);
      return false;
    }
  }

  /// 重置为内置词典。
  ///
  /// 返回内置词典路径用于 UI 提示，失败返回 `null`。
  Future<String?> resetToBuiltin() async {
    try {
      final builtinPath = await BuiltinDictionary.ensureExtracted();
      dict_api.closeDictionary();
      await dict_api.initDictionary(mdxPath: builtinPath);
      currentMdxPath.value = builtinPath;
      await load();
      return builtinPath;
    } catch (e, st) {
      Logging.error('builtin dict reset failed', exception: e, stackTrace: st);
      return null;
    }
  }

  /// 释放所有 signal 资源。
  void dispose() {
    currentMdxPath.dispose();
    dictionaries.dispose();
    loading.dispose();
  }
}
