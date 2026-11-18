---
name: yifan-r-code-style
description: >
  Yifan 的 R 语言科研代码风格 v3。结合本人代码风格以及 R for Data Science 2e、ggplot2 3e、Advanced R 2e、R Packages 2e 与 Tidyverse Style Guide 等 tidyR 语法教程。用于生成、改写、审查任何 R 脚本：运算、可视化、高级技巧、R 包开发、工程与可复现约定。
  Triggers: R 代码风格, Yifan R style, R 规范, 写 R 脚本, 按风格写 R, R coding style, R 脚本规范, R 编码规范, tidy 风格, tidyverse 风格, R 数据处理规范, R 可视化规范, R4DS, ggplot2 规范, dplyr 规范, R 包开发, R package, usethis, roxygen2, DESCRIPTION, NAMESPACE, R CMD check, Advanced R, 编程技巧, 性能优化, purrr, rlang, 管线编排, targets, 空间数据 sf stars terra, 变量登记表, 口径登记表, 命名豁免, 同名不同义, 以及编写、修改或格式化任何 R 脚本时自动启用，不需要用户提醒。
version: 3.2.0
author: Yifan
license: MIT
tags: [R, Coding-Style, Scientific-Computing, Reproducibility, Tidyverse, ggplot2, sf, R-Package]
---

# Yifan R Code Style v3.2.0

本文件给硬规则。细则在 `references/`，按 §0.1 的表取用。

依据：Hadley Wickham, *R for Data Science* 2e；*ggplot2: Elegant Graphics for Data Analysis* 3e；*Advanced R* 2e；
Hadley Wickham 与 Jenny Bryan, *R Packages* 2e；*Tidyverse Style Guide*。链接见 §14。

规则优先级：项目约定（注释位置、`##_` 分割、关键口径、目录布局、数据位置）高于本文件。
本文件不规定项目目录布局，只规定 R 脚本放在 `R/`。通用写法（命名、空格、管道、tidyverse 与 ggplot2 语法、可复现）按 Hadley 通则。

标记含义：`必须` 硬规则；`禁止` 不得出现；`优先` 默认选法，可换；`推荐` 默认写法，项目约定可覆盖；
`坑` 会静默出错的写法。

## 0. 总则

1. `必须` R 脚本放项目根目录下的 `R/`。其余目录由项目约定决定。
2. `必须` 脚本按顺序执行、可重跑、不依赖隐藏状态。有随机数就 `set.seed()`。
3. `必须` 关键恒等式（分区守恒、总量守恒、行列对齐）用 `stopifnot()` 断言，超差即停。不要只打印数值让人看。
4. `推荐` 先探索再分析后报告。图形不得误导（见 `references/visualization.md` §11）。
5. `禁止` `setwd()`。路径用 `here::here()` 相对项目根构造。
6. `推荐` 末尾打印 `sessioninfo::session_info()`以便复现环境。

- 安装命令不写进脚本。

### 0.1 取用哪份细则

| 正在做的事 | 读这份 |
|---|---|
| 数据变换、join、类型与缺失值、正则、日期、大文件、嵌套 list | `references/computation.md` |
| ggplot2 出图、比例尺与配色、地图与栅格、分面、拼图 | `references/visualization.md` |
| 函数设计、取值与子集、条件与调试、性能、purrr、程序化列引用 | `references/advanced-r.md` |
| 抽成 R 包、写文档、测试、发布 | `references/package-dev.md` |
| 命名细则、口径登记表、格式豁免 | `references/naming.md` |
| 新建脚本 | `templates/analysis-step.R`、`templates/figure.R` |

## 1. 输出文件

- `推荐`：文件名含数据口径、计算情景、计算方法、计算日期。日期用六位 `format(Sys.Date(), "%y%m%d")`。

    > 例：`health_burden_global_allproduct_MRBRT2019_260902.xlsx`。

- `禁止`：`output1`、`temp`、`test`、`new`、`final` 这类看不出内容的名字。临时试验产物例外。

- `优先`：输出格式按数据类型选：数据框与数据框列表 → xlsx；SpatVector 与 sf → shp；SpatRaster 与 stars → GeoTIFF；不规则 list → json；多维数组（带 dimnames、按下标运算）→ rds；大表且需要 dplyr 下推 → parquet（需 `arrow`）。
- `优先` 中间结果缓存用 rds 格式。
- `优先` 导出用 `readr::write_csv()`、`writexl::write_xlsx()`、`sf::write_sf()`、`stars::write_stars()`、`terra::writeRaster()`。
- `必须`：产出数据须附读取说明。每个结果文件夹中建立 `output-data.json` 登记产出结果，包括数据字段、意义、计算口径、产出脚本。每次产出新结果时登记。
    > 例：
```json
[
  {
    "filename": "health_burden_global_MRBRT2019_260902.xlsx",
    "content": "2017年全球网格化归因死亡长表",
    "type": "data.frame",
    "method": "使用MRBRT2019相对风险函数，RandallMartin出品的V6.GL.02.03全球0.1°分辨率地表PM2.5浓度数据（2017），LandScan的1km人口栅格数据（2017），GBD2019的分国家分疾病终端分年龄组死亡率数据（2017），GBD2019的分国家分年龄组人口数据（2017）计算得来",
    "script": "R/03_health_base.R",
    "keys": ["x", "y", "location", "cause", "age", "mortality"],
    "unit": "人"
  },
  {
    "filename": "PM25_conc_global_fromEE_261001.tif",
    "content": "全球由于EE食品消费引起的PM2.5浓度网格",
    "type": "raster",
    "method": "使用Omar的源受体矩阵，基于邢老师计算的EE食品消费引起的全球主要大气污染物排放（2017），计算得到世界168受体国家的人口加权PM2.5浓度变化量（借用两处补充了受体关系），再乘以RandallMartin出品的V6.GL.02.03全球0.1°分辨率地表PM2.5浓度（2017）计算得来",
    "script": "R/02_conc_consumption.R",
    "keys": ["pm25"],
    "unit": "μg/m3"
  }
]
```

## 2. 命名

- `必须` 变量、函数、文件、参数名用 snake_case 表明其实际口径与含义。其他命名（全大写数据对象、数据源前缀族、待迁移旧名）一律写入 `.lintr` 的 `regexes`，每条带理由。
- `必须` 变量名表达数据内容。禁止 `p1`、`p2`、`df`、`tmp`、`x1`、`plot_data`、`output1` 这类只表示位置或用途的名字。
- 允许三种缩写：`figure` → `fig`、`directory` → `dir`、`registry` → `reg`。其他缩写要能拼出且有标准含义。
- `dir` 只用于复合名（如 `dir_processed`）；单独使用会覆盖 `dir()`。
- `必须` 代码目录建立变量登记表 `R/_variables.json`。项目内部的专有变量、别名、待迁移名都登记在这张表里。新增计算变量按三步走：先问用户，获准后登记，再写代码。新项目从 `templates/variables.json` 与 `templates/_variables.R` 起步，细则见 `references/naming.md`。
- 类型后缀按含义固定：`_dir` 目录路径、`_files` 文件路径向量、`_tif` 栅格文件路径、`_nm` 名称向量、
  `_n` 计数、`_rate` 率。
- 同数据不同口径靠后缀拆开：`pm25_global_05` 是全球0.5度PM2.5，`pm25_china_001` 是中国0.01度PM2.5。
- `推荐` 布尔变量用 `is_` 或 `has_` 前缀；函数名用动词前缀 `load_emis()`、`summarise_by_region()`。绘图函数用 `plot_`。ggplot 对象用 `p_` + 数据内容 + 几何形态（如 `p_exposure_map`）。
- 改列名用 `rename()`。
- `禁止` 用对象覆盖函数名（如 `filter`、`mean`、`df`）。

## 3. 注释

- 文件头保留清单，写两项：
  1. 总体说明：脚本做什么、输入、输出、运行方式。
  2. 版本记录：版本号、日期、改动摘要。
- 按代码层级写注释。每个层级的顶部写三件事：
  1. 本层级的计算框架：输入、处理步骤、输出。
  2. 数学公式：用 LaTeX 写清变量、单位与下标。
  3. 输出口径：范围、单位、缺失处理、口径开关。
- 层级按项目结构划分：脚本顶部、函数定义上方、循环或分支块顶部。
- 本地项目尽量用中文注释，专有名词保留英文。
- 开源到 GitHub 的项目额外加英文注释，中文在前，英文在后。
- 独立语句之间空一行。一行代码不足 50 字符时，允许与下一行紧接。管道、图层链与多行函数调用的续行算同一条语句，不空行。
- 删除用 `#` 注释掉的旧代码，用 git 留档。

## 4. 语法与格式
- `必须` 用 `<-` 赋值。`禁止` 用 `=` 赋值；`=` 只用于传参。
- R>=4.1.0 时使用默认管道 `|>`，其余情况使用magrittr管道 `%>%`。需要 `.` 占位、`%$%`、`%T>%` 的场合也可以使用magrittr管道。同一脚本内管道符号最好不要混用。
- R>=4.2.0 的情况下使用原生占位符 `_`搭配原生管道运算 `x |> f(n = 2, v = _)` 实现改变管道导入数据的传参位置
    > **注意：** `_` 只能用于命名参数，不能用于位置参数。`x |> f(1, _)` 会报错。
- 除非一行能够结束多个管道运算，否则每行只写一个管道运算或一个图层。
- 字符串用双引号。串内有双引号时改用单引号或原始字符串 `r"(...)"`。
- `library()` 集中在脚本顶部。零星调用使用 `::` （如`readxl::read_xlsx()`）。
- 代码须通过格式工具校验：`styler::style_dir("R", indent_by = 2)` + `lintr::lint_dir("R")` 才可交付落地。缩进只用 2 个空格。
- `禁止` 在 `R/` 下保留 tab 缩进。格式化后逐文件检查；有 tab 就查解析失败与编辑器设置。
- RStudio 里 Code > Editing 的缩进设为 spaces，Tab width 设 2。用 styler 插件时，在项目 `.Rprofile` 写 `options(styler.addins_style_transformer = "styler::tidyverse_style(indent_by = 2)")`。

## 5. 代码分割与复用

- 所有计算用的脚本只出现在 `R/`，计算脚本命名为 `##_<主题>.R`（`##` 表示计算阶段）。画图脚本命名为 `plot_<主题>.R`。
- 多个脚本共用的处理抽到 `R/_common_<主题>.R`，脚本顶部 `source()`。口径登记表的读取与检查放 `R/_variables.R`。
- 成本高、用得勤的中间数据在 `00` 阶段计算后写进中间目录。不要每步重算或反复解压大文件。
- 键可能不匹配的两组数据（例如按国名匹配），在 `00` 阶段用 `llmjoin::build_joint()` 生成连接表存进中间目录，命名 `join_*_<yymmdd>.xlsx`。
    > 使用 `llmjoin` 前执行 `Sys.setenv(CURL_SSL_BACKEND = "openssl")`。
- 每个脚本要能整段独立运行。只写派生产物，不改原始输入。
- 同一段代码出现两次以上就写成函数塞进`_common_<主题>.R` 以便复用。

## 6. 关键口径与稳健性

- 关键口径变量（如物种、区域、品类等）一律取 `R/_variables.json` 中的登记值，禁止随便写变量和键值。
- 能 join 的都 join。不要靠字符串位置切片凑匹配。
- 用 `recode_values(x, from, to)` 改值时，`from` 与 `to` 最好是named_vector向量的names和values，方便核对。
- join 前检查键唯一性。每组汇总都校验 `n`。样本量不明就不下结论。
- `必须` 单位换算用 `units` 包。导入时用 `units::set_units()` 赋单位，换算用 `units::set_units(x, "目标单位")`。导出前用 `units::drop_units()` 去掉单位属性。禁止手写换算系数（如 `1e-3`）。
- `坑`：`set_units(x, u)` 会把变量 `u` 当成单位符号；目标单位写字符串字面量。
- 年份、情景表在文件顶部或单独的配置表里定义一次。单位链写在一处，并把单位写进 `output-data.json` 的 `unit`。
  
## 7. 绘图要点

细则见 `references/visualization.md`。

- 绘图主要使用基于grid包的高级绘图系统（ggplot2、lattice等）进行绘制，尽量不使用原生绘图函数。
- 对于多变量且反复用到的绘图数据，`ggplot()` 放数据与全局映射。单层的数据与映射写在该层里。
- `aes()` 内只写裸列名，不需要 `aes(df$x)`。
- 线宽设置用 `linewidth`；点和文字用 `size`。
- 沿用美学属性用 `after_stat()`、`after_scale()`、`from_theme()`、`stage()`进行调整。
- 单张子图最多 3 到 4 个视觉通道。分箱用 `*_binned()`。
- 配色须色盲安全。使用自定义色板前先做色盲模拟。
- 推荐的标度颜色：
    - 单色渐变_蓝：`c("#FCF9DE", "#BFE4DB", "#90D7BC", "#7FBADB", "#45A1CB", "#1793B1", "#1A73A2")`
    - 单色渐变_橙：`c("#FEE6CE", "#FDBE85", "#FD8D3C", "#E6550D", "#A63603")`
    - 单色渐变_红：`c("#FEE0D2", "#FC9272", "#EF3B2C", "#CB181D", "#67000D")`
    - 单色渐变_绿：`c("#FBFFF2", "#DCECB5", "#81C570", "#46B065", "#008E6B")`
    - 连续变化（常用于数值差异非常大的数据，配合log使用）：`c("#000000", "#74A9CF", "#41AB5D", "#FEC44F", "#F16913", "#B30000")`
    - 正负连续变化（常用于表现数据正负分化）：`c("#005A89", "#4DAABE", "#A3D2CF", "#D8E1C8", "#E7C99F", "#D8AD74", "#B77634", "#9C5D1A")`
    - 离散低饱和度5色①：`c("#a82524", "#f4d01e", "#50b048", "#43afdd", "#c485b4")`
    - 离散低饱和度5色②：`c("#45b293", "#f2a5b5", "#e48464", "#75a3d2", "#e7d787")`
    - 离散低饱和度5色③：`c("#80c7dc", "#2f7592", "#8ab65a", "#f1ae4e", "#bfa1c8")`
    - 离散低饱和度5色④：`c("#7ec9d9", "#9d8eb7", "#e9e2a9", "#e5a474", "#88bb8e")`
    - 离散低饱和度20+色，适合离散标签大于10个的数据：`c("#1f72a9", "#6a9dc6", "#99a854", "#2f9b3f", "#e88888", "#c27aa1", "#966765", "#bc958c", "#95878c", "#9a9a9a", "#b8bbc6", "#6db767", "#e58d46", "#9fb774", "#8e68a6", "#ad90c0", "#c883a1", "#bdba6a", "#cc79a4", "#b9ba35", "#f2ac66", "#d54c4b", "#b294af", "#e19dc3", "#9fca9c", "#39b5b9")`
- 色标 `limits` 取数据范围不要用最大值，尽量提前计算取q99.5，否则离群情景会让整图色阶失真。
- `坑`：比例尺的 `limits` 如果小于数据范围会把界外数据转成 NA，需要加上`oob = scales::squish` 截断。
- 对于普通图，放大或缩小视野用 `coord_cartesian(xlim = )` ，空间制图用 `coord_sf(xlim = )`。
- 世界地图：`geom_sf()` 或 `geom_stars()` 配 `coord_sf(crs = "+proj=robin", default_crs = sf::st_crs(4326))`。`default_crs` 必须给，否则 `xlim`、`ylim` 按投影坐标解释。跨日界线的形变用 `datum` 控制。排除南极用 `ylim = c(-60, 89.9)`，不要删数据。
- 绘制世界地图时，如果不是在wgs84坐标系下，可按如下方法绘制世界地图的边界（以robin投影为例）。
```r
world_map_box <- c(xmin = -179.9, xmax = 179.9, ymin = -60, ymax = 89.9)
ggplot() +
  geom_sf(data = rnaturalearth::ne_countries(), aes(fill = gdp_md)) +
  geom_sf(data = st_as_sfc(st_bbox(world_map_box, crs = 4326)) |> st_segmentize(dfMaxLength = 1E4), fill = NA, color = "black", linewidth = .5) +
  coord_sf(
    crs = "+proj=robin", default_crs = 4326,
    xlim = world_map_box[c("xmin","xmax")],
    ylim = world_map_box[c("ymin","ymax")],
    expand = c(bottom = FALSE)
  )
```

- 成品图不设副标题。标题写结论并带单位；情景、年份与来源写进 `caption`。对数尺度必须注明。
- 标签、标题、图例涉及化学式、上下标、希腊字母或运算符时，用 `bquote()` 写 expr，如 `bquote(PM[2.5] ~ "(" ~ mu * "g/" * m^3 ~ ")")`。
- expr 的加粗用表达式内的 `bold()` 包裹；`element_text(face = "bold")` 对 expr 不生效。

- 保存图片用 `ggsave(file.path(fig_dir, out_fig_nm), p_world_pop, width = fig_w, height = fig_h)`。`fig_dir` 与文件名在配置段定义。交付用 `.pdf` 或 `.svg`。图片比例一般保持方形、4:3、以及黄金比例原则。

## 8. 函数与迭代

- 函数要短、纯、动词命名、默认参数有值。输入输出与计算分离：读写留在外层，核心计算是纯函数。
- 遍历用 `purrr::map_*()` 家族，后续换 `future` 并发时不用改结构。批量遍历用 `purrr::safely()` 隔离失败。
- 对列做同一件事用 `across()`。非必要不用 `apply` 系。`sapply()` 改成 `map_*()` 或 `vapply()`。
- 匿名函数用 `\(x)`，只允许一行。函数体跨行或含 `{}` 就写具名函数。
- `map_*()`输出的合并用 `list_rbind()` 、 `list_cbind()`或`list_c()`。不要在`map_*()`遍历里用 `rbind()`、`c()` 。
- 程序化列参数优先 `{{ }}`。动态列名用 `.data[[var]]`。外部字符向量用 `all_of()`。tidyselect 上下文不用 `.data$`。

## 9. 条件、调试与性能

细则见 `references/advanced-r.md`。

1. 报错用 `cli::cli_abort()`，警告用 `cli::cli_warn()`，进度用 `cli::cli_inform()`。不要用 `print()`、`cat()` 当日志。
2. 断言用 `stopifnot()`。输入校验放函数入口。
3. 错误用 `tryCatch()`，警告与消息用 `withCallingHandlers()`。不要用 `suppressWarnings()`、`suppressMessages()` 掩盖问题；确要抑制就写明原因。
4. 批量任务用 `purrr::safely()` 隔离失败，先收齐结果与错误，再统一报告。单个坏文件不应终止整条管线。
5. 调试顺序：复现（最小可复现例）→ 提假设 → 用工具验证 → 修复 → 留守卫。工具按顺序试 `traceback()`、`debugonce()`、`browser()`、`rlang::last_trace()`。
6. 性能：先测量再优化，用 `bench::mark()` 与 `profvis::profvis()`。
7. 优化顺序从先到后：改算法与减少重复计算 → 向量化 → 换数据结构（矩阵、`data.table`、磁盘后端）→ 预分配 → 缓存 → 并行 → C++。

## 10. 工程习惯

- 用数据驱动，不用代码分支。情景、物种、年份的组合写成表，用 `expand_grid()` 配 `pmap()` 跑。不要写一长串 `if (scen == ...)` 加分支内复制代码。
- 脚本重复运行结果一致。长任务在中间写检查点，方便失败后从断点继续。
- 分层：`_common_<主题>.R` → `##_<主题>.R` → 主控脚本。每层只依赖下一层。
- 依赖可复现：用 `renv` 锁定（需先安装），用 `sessioninfo` 留痕。脚本里不写 `install.packages()`。
- Git 小步提交。原始数据与超大数据文件不入库（gitignore 或 Git LFS，清单按项目约定）。
- 命令行启动`Rscript` 时可能 `LC_*` 设置失败，`collate` 为 `C`。默认排序不是中文序。需要按中文排序时用 `stringr::str_sort(x, locale = "zh")`。因子水平顺序同理。

## 11. 静态检查配置

在项目根目录放 `.lintr` 用于风格检查。
```ini
linters: linters_with_defaults(
    line_length_linter(100L),
    object_name_linter(styles = "snake_case"),
    T_and_F_symbol_linter(),
    undesirable_function_linter = undesirable_function_linter(
      c(apply = "用 purrr::map_*() 或向量化写法", sapply = "用 purrr::map_*() 或 vapply()",
        reshape = "用 pivot_longer() 或 pivot_wider()", subset = "用 filter()")
    )
  )
exclusions: list("data-raw", "renv", "docs")
```
- 默认风格 `snake_case`。其他命名（全大写对象、数据源前缀族、待迁移旧名）写入 `.lintr` 的 `regexes`，每条带理由：

```ini
object_name_linter(
  styles = "snake_case",
  regexes = c(
    "GLC 数据源对象" = "^GLC_[a-z0-9_]+$",
    "17 区域情景" = "^SCE17$"
  )
)
```
- 自定义中缀运算符也走豁免：`"自定义中缀" = "^%.*%$"`。
- `坑`：
    - `object_name_linter` 用 `match.arg(..., several.ok = TRUE)` 解析风格名，未匹配的项被静默丢弃。写错一个名字，对应风格就不再检查，配置本身不报错。
    - `object_name_linter` 只检查赋值目标与形参。列名、`$` 访问、`rename()` 的新名由 `check_variables()` 检查，见 `references/naming.md`。

- 待迁移旧名用行内 `# nolint object_name_linter: 待迁移到 xxx`。它保持可见，清完就删。

- `lintr` 不导出 `with_defaults()`，要用 `linters_with_defaults()`；配置里不要写 `default = TRUE`，会报 non-linters at elements。
- 建议开启的检查：`assignment_linter`、`seq_linter`、`T_and_F_symbol_linter`、 `pipe_consistency_linter`、`object_name_linter`、`line_length_linter`、`commented_code_linter`、`indentation_linter`、`object_usage_linter`。
- 建议不开启 `pipe_linter`。
- 交付前跑 `lintr::lint_dir("R")`。格式化用 `styler::style_dir("R", indent_by = 2)`。

## 12. 反模式黑名单

| ❌ 禁止 | ✅ 改用 |
|---|---|
| `read.csv()` / `write.csv()` | `readr::read_csv()` / `write_csv()` |
| `T` / `F` | `TRUE` / `FALSE` |
| `ifelse()` | `if_else()` / `case_when()` |
| `x == NA` | `is.na(x)` |
| 用 `==` 比浮点 | `dplyr::near(x, 0.3)` |
| `arrange(-x)` | `arrange(desc(x))` |
| `apply()` 作用于数据框 | `map_*()` / `across()` |
| `sapply()` | `map_*()` / `vapply()` |
| 循环内 `rbind()` / `c()` 扩容 | 预分配 + `list_rbind()` |
| `reshape` / `melt` / `dcast` | `pivot_longer()` / `pivot_wider()` |
| `df[df$x > 1, ]`、`subset()` | `filter(x > 1)` |
| `cbind()` / `rbind()` 拼表 | `bind_cols()` / `bind_rows()` |
| `data.frame()` 手工建表 | `tibble()` / `tribble()` |
| `paste0()` / `gsub()` / `substr()` | `str_c()` / `str_replace_all()` / `str_sub()` |
| `do.call(rbind, ...)` | `list_rbind()` / `bind_rows()` |
| `purrr::invoke()` | `rlang::exec()` / `do.call()` |
| `1:length(x)` | `seq_along(x)` |
| 用 `[` 取单个元素 | `[[` |
| `x[-which(is.na(x))]` | `x[!is.na(x)]`（前者在全 NA 时返回整个 x） |
| `df[, "col"]` 不带 `drop = FALSE` | `df[["col"]]` 或补 `drop = FALSE` |
| `print()` 当进度与日志 | `cli::cli_inform()` / `message()` |
| `cat(e$message)` 吞错 | `cli::cli_abort()`，或收集后统一报告 |
| 改了 `options()` / `par()` 不还原 | `withr::local_*()` / `on.exit(add = TRUE)` |
| `suppressWarnings()` 掩盖问题 | 修因；必要时 `withCallingHandlers()` 并写明原因 |
| `<<-` 改全局变量 | 参数传递 / 闭包返回值 / 显式环境 |
| tidyselect 上下文用 `.data$` | 裸列名；程序化用 `{{ }}` 或 `.data[[ ]]` |
| `stat(count)` / `..count..` | `after_stat(count)` |
| 线宽写 `size` | `linewidth` |
| 矩阵最大值做色标 `limits` | 取数据列（§7） |
| 用 `scale_*` 的 `limits` 放大局部 | `coord_cartesian()` / `coord_sf()` |
| `setwd()` | `here::here()` 相对项目根 |
| `rm(list = ls())` 开头清场 | 干净会话（`--vanilla` / renv） |
| `library()` 藏在函数体内 | 顶部集中 |
| 行尾大段注释 | 注释写在该层级顶部（§3） |

## 13. 交付自查

- [ ] `Rscript --vanilla <script>` 一遍通过，`parse()` 无错。重跑一处代表性数值或图，与改动前一致。
- [ ] 命名 snake_case 且写数据内容，或已写入 `.lintr` `regexes` 的豁免名。布尔值全拼。没有 `=` 赋值。一行一个管道或图层。
- [ ] 跨边界列名与对象已登记在 `R/_variables.json`；`check_variables()` 无 error；别名命中 0 处。
- [ ] 文件头有总体说明与版本记录；每个代码层级顶部有计算框架、数学公式、输出口径；本地项目中文注释，GitHub 项目加英文；独立语句之间空行，不足 50 字符可紧接（§3）。
- [ ] 文件名能看出内容（§1 命名为推荐，项目约定优先）。结果目录有 `output-data.json` 登记。多维数据带读取说明。
- [ ] join 用 `join_by()` 给键，键唯一性查过。每组汇总带 `n`。
- [ ] 缺失值处理显式（删、留、补三选一）并写进 `output-data.json` 的 `method`。关键恒等式有 `stopifnot()`。
- [ ] 图有标题、轴标签、图例与单位。条形 y 轴从 0 起。`linewidth` 与 `after_stat()` 用对。`ggsave` 写到图目录，文件名与项目命名约定一致。
- [ ] §12 黑名单写法为 0。`lintr::lint_dir("R")` 无 error 与 warning。已跑 `styler::style_dir("R", indent_by = 2)`，`R/` 下无 tab 缩进。
- [ ] 无隐藏状态：`set.seed()` 就位，全局状态有还原，末尾打印 `sessioninfo::session_info()`。
- [ ] 报错先复现再定位（§9）。性能改动有 `bench::mark()` 或 `profvis` 证据。循环已预分配或向量化。
- [ ] R 包项目另按 `references/package-dev.md` §14 核对。

## 14. 建议使用

标 `†` 的包随 `install.packages("tidyverse")` 一起安装，不必单独装。

- `tidyverse`：含 `dplyr`、`forcats`、`ggplot2`、`lubridate`、`magrittr`、`modelr`、`purrr`、`readr`、`readxl`、`scales`、`stringr`、`tidyr` 等数据分析基础包。
- 网络通信与爬虫：`xml2`†、`httr`†、`jsonlite`†、`rvest`†。
- 数据分析与可视化建议安装：**`data.table`**†、`tidytable`、**`anytime`**、**`clock`**、`patchwork`、**`cowplot`**、**`ggrepel`**、**`ggtext`**、`ggarrow`、**`showtext`**、`shadowtext`、`geomtextpath`
- 单位换算用 `units`。
- Excel 导出用 `writexl`。
- 模板额外依赖：`here`、`rnaturalearth`、`sessioninfo`。
- 空间运算建议使用：`sf`、`stars`、`terra`、`tidyterra`。
- package 开发建议安装：**`devtools`**、**`usethis`**、**`pkgdown`**、`testthat`、**`covr`**、**`lintr`**、**`styler`**、**`withr`**、**`renv`**、**`targets`**。
- 文件与路径管理建议安装：**`fs`**†、**`here`**。
- 性能分析与优化建议安装：**`profvis`**、**`bench`**、**`memoise`**、**`lobstr`**。
- `tidyverse` 还会带上 `knitr`、`rmarkdown`、`broom`、`haven`、`hms`、`googledrive`、`googlesheets4`、`ragg`、`reprex`、`dbplyr`、`dtplyr` 等依赖。
- LYF 开发：`LYFtools`、`llmjoin`、`AttrMort`。
- 缺包时先列出包名、用途与版本要求，问过用户再装。运行本 skill 不自动安装包，也不写 `install.packages()`。

## 15. 参考资料

- Hadley Wickham, *R for Data Science* (2e, 2023), https://r4ds.hadley.nz/ 。用到第 3–5、7–8、10–12、13–21、26–28 章。
- Hadley Wickham, *ggplot2: Elegant Graphics for Data Analysis* (3e), https://ggplot2-book.org/ 。
- Hadley Wickham, *Advanced R* (2e, 2019), https://adv-r.hadley.nz/ 。
- Hadley Wickham 与 Jenny Bryan, *R Packages* (2e, 2023), https://r-pkgs.org/ 。
- Hadley Wickham, *Tidyverse Style Guide*, https://style.tidyverse.org/ 。
