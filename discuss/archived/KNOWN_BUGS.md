
## Pre-existing: paginated_renderer_test 找不到 staging 图片 widget

**文件**: `test/features/reader/page/widgets/paginated_renderer_test.dart`
**问题**: `contentBlocks staging 渲染 Image 占位` 找不到匹配 widget。
可能是渲染逻辑或 mock 数据与当前 PageBlockSlice/image 结构不匹配。非 P6-P8 引入。
