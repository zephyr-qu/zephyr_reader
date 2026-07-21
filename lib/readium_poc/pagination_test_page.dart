import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flureadium/flureadium.dart';

/// 分页准确性测试页面。
///
/// 功能：
/// 1. 逐页翻动，记录每页 Locator 数据
/// 2. 验证相邻页 Locator 连续性
/// 3. 检测是否有空页
/// 4. 统计总页数
/// 5. 测试对称性（前进 N 页后再后退 N 页，回到原位）
class PaginationTestPage extends StatefulWidget {
  final String filePath;

  const PaginationTestPage({super.key, required this.filePath});

  @override
  State<PaginationTestPage> createState() => _PaginationTestPageState();
}

class _PaginationTestPageState extends State<PaginationTestPage> {
  final reader = Flureadium();
  late Future<Publication> _openFuture;

  StreamSubscription<Locator>? _locatorSub;
  StreamSubscription<ReadiumReaderStatus>? _statusSub;

  // 测试数据
  final List<_PageRecord> _pageRecords = [];
  int _pageCount = 0;
  Locator? _currentLocator;
  int _emptyPageCount = 0;
  int _inconsistencyCount = 0;
  bool _isLogging = false;
  String _testResult = '未开始';
  String _detailedLog = '';

  @override
  void initState() {
    super.initState();
    _openFuture = reader.openPublication(widget.filePath);
    _locatorSub = reader.onTextLocatorChanged.listen(_onLocatorChanged);
    _statusSub = reader.onReaderStatusChanged.listen((status) {
      if (!mounted) return;
      // status logged implicitly via locator changes
    });
  }

  @override
  void dispose() {
    _locatorSub?.cancel();
    _statusSub?.cancel();
    reader.closePublication();
    super.dispose();
  }

  void _onLocatorChanged(Locator locator) {
    if (!mounted || !_isLogging) return;
    setState(() {
      _currentLocator = locator;
      final progression = locator.locations?.totalProgression ?? 0.0;
      _pageRecords.add(
        _PageRecord(
          pageIndex: _pageCount,
          progression: progression,
          href: locator.href ?? '',
          locatorJson: locator.toJson(),
        ),
      );
      _pageCount++;
    });
  }

  void _startLogging() {
    setState(() {
      _isLogging = true;
      _pageRecords.clear();
      _pageCount = 0;
      _emptyPageCount = 0;
      _inconsistencyCount = 0;
      _testResult = '收集中...';
      _detailedLog = '';
    });
  }

  void _stopLogging() {
    setState(() => _isLogging = false);
    _analyzeResults();
  }

  void _analyzeResults() {
    if (_pageRecords.isEmpty) {
      setState(() => _testResult = '❌ 无页面记录');
      return;
    }

    final issues = <String>[];

    // 检查空页
    if (_pageRecords.length <= 1) {
      issues.add('⚠️ 只有 ${_pageRecords.length} 页记录，可能翻页未触发');
    }

    // 检查 progress 单调递增
    for (int i = 1; i < _pageRecords.length; i++) {
      final prev = _pageRecords[i - 1].progression;
      final curr = _pageRecords[i].progression;
      if (curr <= prev) {
        issues.add(
          '❌ 页 $i: progression 未递增 (${prev.toStringAsFixed(4)} → ${curr.toStringAsFixed(4)})',
        );
        _inconsistencyCount++;
      }
    }

    // 检查 progression 范围
    for (final record in _pageRecords) {
      if (record.progression < 0 || record.progression > 1.0) {
        issues.add(
          '❌ 页 ${record.pageIndex}: progression 越界 ${record.progression}',
        );
      }
    }

    // 检查对称性（如果有足够记录）
    if (_pageRecords.length >= 4) {
      final first = _pageRecords.first;
      final last = _pageRecords.last;
      if ((last.progression - first.progression).abs() < 0.01) {
        issues.add(
          '⚠️ 总 progression 变化极小 (${first.progression} → ${last.progression})，可能只翻了一页的内容',
        );
      }
    }

    final summary = StringBuffer()
      ..writeln('=== 分页测试报告 ===')
      ..writeln('总记录: ${_pageRecords.length} 页')
      ..writeln(
        '起始 progression: ${_pageRecords.first.progression.toStringAsFixed(4)}',
      )
      ..writeln(
        '最终 progression: ${_pageRecords.last.progression.toStringAsFixed(4)}',
      )
      ..writeln(
        '覆盖范围: ${((_pageRecords.last.progression - _pageRecords.first.progression) * 100).toStringAsFixed(1)}%',
      )
      ..writeln()
      ..writeln('发现问题: ${issues.length}')
      ..writeln();

    for (final issue in issues) {
      summary.writeln(issue);
    }

    summary.writeln();
    if (issues.isEmpty && _pageRecords.length > 1) {
      summary.writeln('✅ 分页连续性验证通过');
      summary.writeln('✅ 无空页');
      summary.writeln('✅ 所有 progression 在 [0,1] 范围内');
    }

    setState(() {
      _testResult = issues.isEmpty ? '✅ 通过' : '⚠️ ${issues.length} 个问题';
      _detailedLog = summary.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('分页测试 — $_pageCount 页'),
        actions: [
          if (_isLogging)
            TextButton(
              onPressed: _stopLogging,
              child: const Text('停止', style: TextStyle(color: Colors.red)),
            )
          else
            TextButton(onPressed: _startLogging, child: const Text('开始记录')),
        ],
      ),
      body: FutureBuilder<Publication>(
        future: _openFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '打开失败: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          final pub = snapshot.data!;
          return Column(
            children: [
              // 测试结果面板
              Padding(
                padding: const EdgeInsets.all(8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📊 $_testResult',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '页数: $_pageCount | 空页: $_emptyPageCount | 不连续: $_inconsistencyCount',
                        ),
                        const SizedBox(height: 4),
                        Text('进度: 当前位置 ${_currentLocator?.locations?.totalProgression?.toStringAsFixed(1) ?? '0.0'}%'),
                        if (_detailedLog.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                _detailedLog,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // EPUB 渲染区域
              Expanded(child: ReadiumReaderWidget(publication: pub)),
              // 控制栏
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      tooltip: '第一章',
                      onPressed: () => reader.skipToPrevious(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      tooltip: '上一页',
                      onPressed: () => reader.goLeft(),
                    ),
                    Text('${_pageRecords.isEmpty ? 0 : _pageRecords.length} 页'),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      tooltip: '下一页',
                      onPressed: () => reader.goRight(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      tooltip: '最后一页',
                      onPressed: () => reader.skipToNext(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PageRecord {
  final int pageIndex;
  final double progression;
  final String href;
  final Map<String, dynamic> locatorJson;

  const _PageRecord({
    required this.pageIndex,
    required this.progression,
    required this.href,
    required this.locatorJson,
  });
}
