import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

const quotes = [
  QuoteData('读书破万卷，下笔如有神。', '杜甫'),
  QuoteData('书籍是造就灵魂的工具。', '雨果'),
  QuoteData('读一本好书，就是和许多高尚的人谈话。', '歌德'),
  QuoteData('知识就是力量。', '培根'),
  QuoteData('学而不思则罔，思而不学则殆。', '孔子'),
  QuoteData('书是人类进步的阶梯。', '高尔基'),
  QuoteData('读万卷书，行万里路。', '刘彝'),
  QuoteData('生活里没有书籍，就好像没有阳光。', '莎士比亚'),
  QuoteData('读书有三到，谓心到、眼到、口到。', '朱熹'),
  QuoteData('书籍是屹立在时间的汪洋大海中的灯塔。', '惠普尔'),
  QuoteData('黑发不知勤学早，白首方悔读书迟。', '颜真卿'),
  QuoteData('书卷多情似故人，晨昏忧乐每相亲。', '于谦'),
];

class QuoteData {
  final String text;
  final String author;
  const QuoteData(this.text, this.author);
}

Widget buildDailyQuote(BuildContext context, ThemeData theme) {
  final day = DateTime.now().day;
  final quote = quotes[day % quotes.length];
  return Container(
    padding: EdgeInsets.all(DesignTokens.spacing(Spacing.md)),
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(DesignTokens.radius(RadiusSize.md)),
      border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 36,
          decoration: BoxDecoration(
            color: DesignTokens.warmAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: DesignTokens.spacing(Spacing.sm)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quote.text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: DesignTokens.textPrimary,
                ),
              ),
              SizedBox(height: DesignTokens.spacing(Spacing.sm)),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  quote.author,
                  style: const TextStyle(
                    fontSize: 12,
                    color: DesignTokens.warmAccent,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
