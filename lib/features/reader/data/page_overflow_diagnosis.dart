/// 分页页 overflow / underfill 因子分解诊断。
///
/// 目标：把「一页缺几行 / 多几行」钉到具体口径：
/// 字宽·ratio / 行高 / 段距 / pageHeight·padding。
library;

/// overflow ≤ 此值视为几何对齐（亚像素容差）。
const kOverflowOkDp = 0.5;

/// 行数差超过此值，优先判为断行/字宽问题。
const kLineDeltaThreshold = 1;

/// 底部空白超过「行高 × 此倍数」才报 underfill（避免噪声）。
const kUnderfillLineMultiples = 1.5;

/// 与 [ReaderRenderConfig.pageContentVerticalPadding] 对齐；用于无预算时的 vPad 启发。
const kDefaultContentVerticalPaddingDp = 20.0;

/// 根因分类（与 phase6-verification §8 FAIL 分诊对齐并细化）。
enum PageOverflowCause {
  /// overflow ≤ [kOverflowOkDp] 且无明显 underfill。
  ok,

  /// Flutter 行数明显多于 Rust 估算 → 字宽偏窄或 ratio 偏大，同字符装不下。
  charWidthOrRatio,

  /// 行数接近，但行盒高度导致总高超视口。
  lineHeight,

  /// 纯文本高度能放下，加上段距/块 padding 后溢出。
  paragraphSpacing,

  /// Rust 页高预算大于 Flutter bodyHeight（常见：vPad 未扣）。
  pageHeightPadding,

  /// 内容明显矮于视口（底部空白 / 「缺几行」）。
  underfill,

  /// 无文本（空页 / 纯图 / skeleton）；不应当作排版少装。
  emptyPage,

  /// 多因子同时显著，或无法单独归因。
  mixed,
}

/// 单页诊断输入（由渲染层累计后传入）。
class PageOverflowMetrics {
  const PageOverflowMetrics({
    required this.bodyHeightDp,
    required this.textHeightDp,
    required this.spacingHeightDp,
    required this.flutLines,
    required this.rustEstLines,
    required this.flutLineHeightDp,
    required this.rustLineHeightDp,
    this.rustPageHeightBudgetDp,
    this.contentVerticalPaddingDp = kDefaultContentVerticalPaddingDp,
  });

  /// Flutter 可视正文区高度（已扣 contentVerticalPadding）。
  final double bodyHeightDp;

  /// 所有 text slice 的 TextPainter 高度之和（不含段距/padding）。
  final double textHeightDp;

  /// paragraphSpacing + blockPadding.vertical 之和。
  final double spacingHeightDp;

  final int flutLines;
  final int rustEstLines;

  /// Flutter 实测/配置单行高（dp）。
  final double flutLineHeightDp;

  /// 传给 Rust 的 measuredLineHeight（dp，非 px）。
  final double rustLineHeightDp;

  /// Rust `page_height_px / dpr`；若未知可为 null。
  final double? rustPageHeightBudgetDp;

  /// 用于无 [rustPageHeightBudgetDp] 时的 vPad 启发（默认 20）。
  final double contentVerticalPaddingDp;

  double get totalHeightDp => textHeightDp + spacingHeightDp;

  double get overflowDp =>
      (totalHeightDp - bodyHeightDp).clamp(0.0, double.infinity);

  double get underfillDp =>
      (bodyHeightDp - totalHeightDp).clamp(0.0, double.infinity);

  int get lineDelta => flutLines - rustEstLines;
}

/// 诊断结果。
class PageOverflowDiagnosis {
  const PageOverflowDiagnosis({
    required this.cause,
    required this.metrics,
    required this.summary,
  });

  final PageOverflowCause cause;
  final PageOverflowMetrics metrics;
  final String summary;

  bool get isOk => cause == PageOverflowCause.ok;

  /// 结构化日志一行（便于真机 grep）。
  String toLogLine() {
    final m = metrics;
    final budget = m.rustPageHeightBudgetDp;
    final budgetStr = budget == null ? 'n/a' : budget.toStringAsFixed(1);
    return '[OverflowDiag] cause=${cause.name}'
        ' overflow=${m.overflowDp.toStringAsFixed(1)}dp'
        ' underfill=${m.underfillDp.toStringAsFixed(1)}dp'
        ' flutLines=${m.flutLines} rustEstLines=${m.rustEstLines}'
        ' lineDelta=${m.lineDelta}'
        ' textH=${m.textHeightDp.toStringAsFixed(1)}'
        ' spacingH=${m.spacingHeightDp.toStringAsFixed(1)}'
        ' bodyH=${m.bodyHeightDp.toStringAsFixed(1)}'
        ' flutLineH=${m.flutLineHeightDp.toStringAsFixed(1)}'
        ' rustLineH=${m.rustLineHeightDp.toStringAsFixed(1)}'
        ' rustBudgetH=$budgetStr'
        ' | $summary';
  }
}

/// 根据累计度量做因子分解，返回唯一主因（必要时 [PageOverflowCause.mixed]）。
PageOverflowDiagnosis diagnosePageOverflow(PageOverflowMetrics m) {
  final overflow = m.overflowDp;
  final underfill = m.underfillDp;
  final lineH = m.flutLineHeightDp > 0
      ? m.flutLineHeightDp
      : (m.rustLineHeightDp > 0 ? m.rustLineHeightDp : 1.0);
  final underfillThreshold = lineH * kUnderfillLineMultiples;

  if (overflow <= kOverflowOkDp) {
    // 无文本页（纯图/骨架）：不要报成 underfill。
    if (m.flutLines == 0 && m.textHeightDp <= kOverflowOkDp) {
      return PageOverflowDiagnosis(
        cause: PageOverflowCause.emptyPage,
        metrics: m,
        summary: '无文本块（空页/纯图/skeleton）',
      );
    }
    if (underfill > underfillThreshold) {
      final cause = m.lineDelta <= -kLineDeltaThreshold
          ? PageOverflowCause.charWidthOrRatio
          : PageOverflowCause.underfill;
      final summary = cause == PageOverflowCause.charWidthOrRatio
          ? '底部空白偏大且 Flutter 行数明显少于 Rust → 字宽/ratio 偏保守（少装）'
          : '底部空白偏大（>${underfillThreshold.toStringAsFixed(1)}dp）→ 查行高预算或 Rust 过早翻页';
      return PageOverflowDiagnosis(cause: cause, metrics: m, summary: summary);
    }
    return PageOverflowDiagnosis(
      cause: PageOverflowCause.ok,
      metrics: m,
      summary: '几何对齐（overflow≤${kOverflowOkDp}dp）',
    );
  }

  // —— 以下 overflow > ok ——
  final hits = <PageOverflowCause>[];

  final budget = m.rustPageHeightBudgetDp;
  final vPadBand = 2 * m.contentVerticalPaddingDp;
  // 仅在「几乎无段距贡献」且溢出高度钉在 2×vPad 时启发，避免抢走 lineHeight/spacing。
  final looksLikeUnfixedVPad =
      budget == null &&
      m.contentVerticalPaddingDp > 0 &&
      m.spacingHeightDp <= kOverflowOkDp &&
      m.lineDelta.abs() <= kLineDeltaThreshold &&
      (overflow - vPadBand).abs() <= 4.0;
  if (budget != null && budget > m.bodyHeightDp + 1.0) {
    hits.add(PageOverflowCause.pageHeightPadding);
  } else if (looksLikeUnfixedVPad) {
    hits.add(PageOverflowCause.pageHeightPadding);
  }

  if (m.lineDelta >= kLineDeltaThreshold + 1) {
    // flutLines >= rust+2
    hits.add(PageOverflowCause.charWidthOrRatio);
  }

  final textAloneOverflows = m.textHeightDp > m.bodyHeightDp + kOverflowOkDp;
  final spacingCausesOverflow =
      !textAloneOverflows &&
      m.spacingHeightDp > 0 &&
      m.totalHeightDp > m.bodyHeightDp + kOverflowOkDp;

  if (spacingCausesOverflow) {
    hits.add(PageOverflowCause.paragraphSpacing);
  }

  // 行数接近但仍 overflow，且不是纯段距问题 → 行高
  if (m.lineDelta.abs() <= kLineDeltaThreshold &&
      textAloneOverflows &&
      !spacingCausesOverflow) {
    hits.add(PageOverflowCause.lineHeight);
  }

  // 行数接近、文本未单独溢出但总高溢出且无 spacing 归因时，比一行高差
  if (m.lineDelta.abs() <= kLineDeltaThreshold &&
      !textAloneOverflows &&
      !spacingCausesOverflow &&
      (m.flutLineHeightDp - m.rustLineHeightDp).abs() > 0.5) {
    hits.add(PageOverflowCause.lineHeight);
  }

  if (hits.isEmpty) {
    // 行数略多（= rust+1）也倾向字宽
    if (m.lineDelta > 0) {
      hits.add(PageOverflowCause.charWidthOrRatio);
    } else if (textAloneOverflows) {
      hits.add(PageOverflowCause.lineHeight);
    } else {
      hits.add(PageOverflowCause.mixed);
    }
  }

  // 优先级：页高口径错误会连带「行数对齐但仍溢出」，不宜再报成 lineHeight。
  PageOverflowCause cause;
  if (hits.contains(PageOverflowCause.pageHeightPadding) &&
      !hits.contains(PageOverflowCause.charWidthOrRatio) &&
      !hits.contains(PageOverflowCause.paragraphSpacing)) {
    cause = PageOverflowCause.pageHeightPadding;
  } else if (hits.length == 1) {
    cause = hits.first;
  } else {
    cause = PageOverflowCause.mixed;
  }
  return PageOverflowDiagnosis(
    cause: cause,
    metrics: m,
    summary: _summaryFor(cause, m, hits),
  );
}

String _summaryFor(
  PageOverflowCause cause,
  PageOverflowMetrics m,
  List<PageOverflowCause> hits,
) {
  switch (cause) {
    case PageOverflowCause.ok:
      return 'ok';
    case PageOverflowCause.charWidthOrRatio:
      return 'Flutter 行数=${m.flutLines} > Rust=${m.rustEstLines} → '
          '查 effectiveLineWidthRatio / cjkWidth（字宽偏窄或 ratio 偏大）';
    case PageOverflowCause.lineHeight:
      return '行数接近(delta=${m.lineDelta})但高度溢出 → '
          '查 measuredLineHeightPx vs StrutStyle '
          '(flut=${m.flutLineHeightDp.toStringAsFixed(1)} '
          'rust=${m.rustLineHeightDp.toStringAsFixed(1)})';
    case PageOverflowCause.paragraphSpacing:
      return '文本高=${m.textHeightDp.toStringAsFixed(1)}≤body，'
          'spacing=${m.spacingHeightDp.toStringAsFixed(1)} 推高溢出 → '
          '查 paragraphSpacing / margin*Em 双端是否一致';
    case PageOverflowCause.pageHeightPadding:
      final b = m.rustPageHeightBudgetDp?.toStringAsFixed(1) ?? '?';
      return 'Rust 页高预算=${b}dp > body=${m.bodyHeightDp.toStringAsFixed(1)}dp '
          '或 overflow≈2×vPad → '
          '查 contentVerticalPadding 是否扣入 pageHeight';
    case PageOverflowCause.underfill:
      return 'underfill';
    case PageOverflowCause.emptyPage:
      return 'empty/image page';
    case PageOverflowCause.mixed:
      final names = hits.map((e) => e.name).join('+');
      return '多因子同时显著: $names → 先修 pageHeightPadding / charWidth，再验行高与段距';
  }
}
