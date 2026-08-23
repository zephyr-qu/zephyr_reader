/// 应用错误映射工具。
///
/// 按异常类型将各类异常映射为用户可读的中文错误消息，
/// 覆盖 FRB/Rust 引擎、网络请求、文件 IO、数据格式等场景。
library;

import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

// 导入 FRB 生成的类型化 AppError 子类
import '../../src/rust/common/error.dart';

/// 应用错误映射器 — 按异常类型（而非字符串）匹配。
class AppErrorMapper {
  AppErrorMapper._();

  /// 将异常对象映射为用户可读的错误消息。
  ///
  /// 按异常类型（而非字符串匹配）分发到对应消息模板，
  /// 覆盖 FRB/Panic、Rust AppError（15 种变体）、网络请求、文件 IO、数据格式等场景。
  /// 无法识别的异常返回通用消息，不会向外传播异常。
  static String humanReadable(Object error) {
    // ===== FRB/Rust 引擎严重错误 =====
    if (error is PanicException) {
      return '引擎内部错误，请重试或重启应用';
    }

    // ===== Rust AppError（15 种类型化变体） =====
    if (error is AppError) {
      return error.when(
        fileNotFound: (path) => '文件未找到: $path',
        fileReadError: (path, details) => '文件读取失败: $details',
        unsupportedFormat: (format) => '不支持的格式: $format',
        fileWriteError: (path, details) => '文件写入失败: $details',
        epubParseError: (reason) => 'EPUB 解析失败: $reason',
        chapterExtractError: (index, reason) => '章节 $index 提取失败: $reason',
        chapterTooLarge: (sizeBytes, details) =>
            '章节过大（${sizeBytes}bytes，最大2MB），建议重新导入',
        databaseError: (reason) => '数据库错误: $reason',
        notFound: (entity) => '$entity 未找到',
        storageNotInitialized: () => '存储未初始化，请先初始化',
        searchError: (reason) => '搜索失败: $reason',
        securityError: (reason, path) => '安全错误: $reason（$path）',
        invalidInput: (reason) => '输入无效: $reason',
        staleBookData: (message) => message,
        internalError: (reason) => '内部错误: $reason',
        taskPanic: (taskName, details) => '任务 $taskName 异常: $details',
        other: (message) => message,
      );
    }

    // ===== 文件/IO 错误 =====
    if (error is FileSystemException) {
      if (error.osError?.errorCode == 2) {
        return '文件未找到，可能已被移动或删除';
      }
      return '文件读写失败，请检查存储空间';
    }

    // ===== 数据格式错误 =====
    if (error is FormatException) {
      return '数据格式不正确';
    }

    // ===== FRB 通用异常 =====
    if (error is AnyhowException) {
      return '数据处理异常，请稍后重试';
    }

    return '操作失败，请稍后重试';
  }
}
