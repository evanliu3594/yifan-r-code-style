# yifan-r-code-style

Yifan 的 R 科研代码风格。打包为 Agent Skill，用于生成、改写、审查 R 脚本。

规则覆盖：数据运算、可视化、高级技巧、R 包开发、工程与可复现约定。

## 安装

把仓库放到 agent 的技能目录。目录名保持 `yifan-r-code-style`。

DSH：

```powershell
git clone https://github.com/evanliu3594/yifan-r-code-style.git "$HOME\.agents\skills\yifan-r-code-style"
```

Claude Code：

```powershell
git clone https://github.com/evanliu3594/yifan-r-code-style.git "$HOME\.claude\skills\yifan-r-code-style"
```

其他 Agent Skills 工具：放到各自的 skills 目录。

新会话加载 `SKILL.md`。需要写或改 R 脚本时，按 frontmatter 的 triggers 启用。

## 内容

| 路径 | 内容 |
|---|---|
| `SKILL.md` | 硬规则：命名、注释、语法、口径、绘图、函数、调试、工程、lintr、反模式、交付自查、推荐包 |
| `references/computation.md` | dplyr、join、类型、缺失值、正则、日期、大文件、嵌套 list |
| `references/visualization.md` | ggplot2、比例尺、配色、地图、分面、拼图 |
| `references/advanced-r.md` | 函数、子集、条件、调试、性能、purrr、程序化列引用 |
| `references/package-dev.md` | R 包结构、文档、测试、发布 |
| `references/naming.md` | 变量登记表、命名豁免、检查脚本 |
| `templates/analysis-step.R` | 计算脚本模板 |
| `templates/figure.R` | 成图脚本模板 |
| `templates/_variables.R` | 变量登记表读取与检查 |
| `templates/variables.json` | 变量登记表模板 |

## 快速使用

1. 在项目里建 `R/`。
2. 复制 `templates/variables.json` 到 `R/_variables.json`。
3. 复制 `templates/_variables.R` 到 `R/_variables.R`。
4. 从 `templates/analysis-step.R` 与 `templates/figure.R` 起步。

## 核心约定

- 命名默认 `snake_case`。变量名写数据内容。允许 `fig`、`dir`、`reg` 缩写。
- 跨文件边界的列与对象登记在 `R/_variables.json`。
- 注释：文件头写总体说明与版本；每个代码层级顶部写计算框架、数学公式、输出口径。本地项目用中文，GitHub 项目加英文。
- 缩进 2 空格。用 `styler::style_dir("R", indent_by = 2)`，格式化后查 tab。
- 单位换算用 `units`。导出前 `drop_units()`。
- 绘图标签含化学式、上下标、希腊字母、运算符时用 `bquote()`。表达式内加粗用 `bold()`。
- 缺包时先问用户，再安装。运行本 skill 不自动装包。

## 依赖

R 4.x。基础：`tidyverse`、`lintr`、`styler`、`jsonlite`。按任务安装：`units`、`sf`、`stars`、`terra`、`patchwork`、`ggrepel`、`ggtext`、`showtext`、`devtools`、`testthat`、`roxygen2` 等。模板额外依赖：`here`、`writexl`、`rnaturalearth`、`sessioninfo`。完整列表见 `SKILL.md` §14。

## 版本

当前 3.2.0。变更见 `CHANGELOG.md`。

## 许可

MIT。见 `LICENSE`。

## 参考

规则参考 Hadley Wickham 的 R for Data Science 2e、ggplot2 3e、Advanced R 2e、R Packages 2e 与 Tidyverse Style Guide。链接见 `SKILL.md` §15。
