# Changelog

## 3.2.0 - 2026-11-18

首个公开版本。

- 变量登记表改为 JSON：`R/_variables.json`，模板为 `templates/variables.json`。
- 命名规则：默认 `snake_case`；变量名写数据内容；允许 `fig`、`dir`、`reg` 缩写。
- 注释规则：文件头写总体说明与版本；每个代码层级顶部写计算框架、数学公式、输出口径；本地项目中文，GitHub 项目加英文。
- 空行规则：独立语句之间空行；不足 50 字符可紧接；管道与多行调用不空行。
- 单位：`units` 包；导出前 `drop_units()`。
- 绘图：标签用 `bquote()`；表达式内加粗用 `bold()`；不设副标题。
- 格式：`styler::style_dir("R", indent_by = 2)`；禁止 tab 缩进。
- 模板：`analysis-step.R`、`figure.R`、`_variables.R`、`variables.json`。
- 清理本地路径与机器相关说明。
