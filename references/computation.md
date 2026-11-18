# 运算细则：数据变换、类型与外部存储

依据 Hadley Wickham, *R for Data Science* 2e（用到 data-transform、data-tidy、joins、numbers、logicals、strings、regexps、factors、datetimes、missing-values、rectangling、arrow、base-R、data-import 章）。


## 1. dplyr 动词选择

1. 五个动词分工固定：`filter()` 选行，`arrange()` 排行，`select()`、`rename()`、`relocate()` 选列，`mutate()` 造列，`summarise()` 汇总。
2. 每个动词输入数据框、输出新数据框，不改原对象。结果必须赋值给具名对象。
3. 排除列优先用 `!`。`!` 能读作“非”，并且可以和 `&`、`|` 组合；`-` 只能减一列。

```r
df |> select(!geometry)
df |> pivot_longer(cols = !c(x, y))
df |> select(where(is.numeric), !ends_with("_flag"))
```

4. 列选择用 tidyselect 助手：`starts_with()`、`ends_with()`、`contains()`、`matches()`、`num_range()`、`where()`、`all_of()`、`any_of()`、`last_col()`、范围写法。
5. 禁止用数字位置选列。读者无法判断列序，上游改列序就错。
6. 每次汇总都带组规模 `n = n()`。样本量不明就不下结论。
7. 取前几名用 `slice_max()`、`slice_min()`、`slice_sample()`。不要用 `arrange()` 加 `head()`。
   `坑`：这三个函数默认保留并列，返回行数可能大于 `n`。每组只要一行时写 `with_ties = FALSE`。

```r
top3 <- emis |> slice_max(order_by = value, n = 3, with_ties = FALSE)
```

8. 一次性的分组运算用 `.by`，可以省掉 `ungroup()` 和分组提示。要跨多步保持分组才用 `group_by()`。
   多个键分组后 `summarise()` 会剥掉最内一层，用 `.groups` 显式声明结果。

```r
by_region <- emis |> summarise(total = sum(value), n = n(), .by = c(SCE17, food_cat))
layered <- emis |> group_by(SCE17, food_cat) |> summarise(m = mean(pm25), .groups = "drop")
```

9. 每组要输出多行时用 `reframe()`。`summarise()` 每组只输出一行。dplyr 1.2.1 有 `reframe()`。
10. 对一批列做同一件事用 `across()`。对一组数值列整体操作用 `pick()`。多列共用一个筛选用 `if_any()` 或 `if_all()`。
11. `mutate()` 控制输出列：`.keep` 取字符串 `unused`、`used`、`none`、`all`；位置用 `.before` 和 `.after`。
12. 列名整体不干净时用 `janitor::clean_names()`（需另装）。
13. 看分布用 `count(x, wt = y, sort = TRUE)`。去重前想清楚保留哪一行：`.keep_all = TRUE` 保留首次出现的那行。

## 2. join

1. 用 `join_by()` 显式给键。同名简写，异名写全左右两列。

```r
out <- left_join(burden, pop, join_by(cntry, year))
out <- left_join(a, b, join_by(source_cntry == country_name))
```

   旧的字符向量 `by` 仍可用且不报警告。统一用 `join_by()`，迁移时替换。
2. `坑`：不写键就是自然 join，会把所有同名列当键。`year`、`id`、`code` 在不同表里含义不同时，结果静默错。
   非键的同名列会被加 `.x`、`.y` 后缀，需要时用 `suffix` 指定。
3. join 前查键。没有自然主键时造代理键。

```r
dup_key <- link |> count(key) |> filter(n > 1)
miss_key <- link |> filter(is.na(key))
keyed <- raw |> mutate(row_id = row_number(), .before = 1)
```

4. 按语义选函数：附加元数据用 `left_join()`；只要匹配上的行用 `inner_join()`；存在性筛选用 `semi_join()`；找没匹配上的行用 `anti_join()`。
   筛选型 join 不复制行，适合做覆盖率核对。
5. `坑`：两侧键都重复就是多对多，行数按笛卡尔积增长。dplyr 现在会警告。确实要这样才写 `relationship = "many-to-many"`，否则先聚合或先去重。
6. 非等值连接可用。实测 `between` 与 `closest` 正常。

```r
hit <- obs |> left_join(period, join_by(between(day, start, end), unmatched = "error"))
near <- obs |> left_join(align, join_by(closest(year >= eff_year)), keep = TRUE)
```

7. 用 `unmatched = "error"` 让没匹配上的行直接失败。用 `keep = TRUE` 保留两侧键列。
8. 在 step0 统一键列名，后续 join 就能省参数。

## 3. 宽长转换与嵌套结构

1. 长表化时 `names_to` 和 `values_to` 是新列名，必须写成字符串。

```r
long <- wide |>
  pivot_longer(!c(x, y), names_to = "scenario", values_to = "dose")
split <- wide |>
  pivot_longer(!id, names_to = c("scen", "cat"), names_sep = "_", values_to = "value")
both <- tab |>
  pivot_longer(!id, names_to = c(".value", "child"), names_sep = "_")
```

2. 列名里打包了多个变量时用 `names_to` 加向量，配 `names_sep` 或 `names_pattern`。变量名和值混在同一列时用哨兵 `.value`。
3. tidyr 1.3.2 有 `names_prefix`、`names_sep`、`names_pattern`、`names_transform`、`names_ptypes`、`names_sort`、`cols_vary`。
   用 `names_transform` 在转换时定类型，不要事后再 `parse_number()`。
4. 宽表化时用 `id_cols` 钉住行身份，用 `values_fill` 填空格，用 `values_fn` 决定同格多行怎么合并。

```r
wide <- long |>
  pivot_wider(names_from = scenario, values_from = dose, values_fill = 0)
wide2 <- long |>
  pivot_wider(id_cols = c(x, y), names_from = cat, values_from = value, values_fn = sum)
```

5. `坑`：一个输出格对应多个输入行时，`pivot_wider()` 静默产出列表列，后续运算全错。先定位重复：

```r
bad <- long |> count(x, y, cat) |> filter(n > 1)
```

   修法是去重或先汇总。
6. 拆列用 tidyr 新家族。变行用 `separate_longer_delim()`、`separate_longer_position()`；变列用 `separate_wider_delim()`、`separate_wider_position()`、`separate_wider_regex()`。
   旧的 `separate()`、`extract()` 在 tidyr 1.3.2 仍可用且不报警告，但新函数在行数不齐时直接报错，旧函数只填 NA。新代码用新家族。
7. 拆不开时用 `too_few = "debug"`、`too_many = "debug"` 加诊断列，看完就删掉这两个参数。留着它们，以后出错也不再报。
8. 嵌套 list 矩形化只用两个原语，反复用可以穿透任意深度：命名且等长的子元素用 `unnest_wider()` 变列，未命名或长度不一的用 `unnest_longer()` 变行。只要其中几个路径时用 `hoist()`。

```r
rec <- tibble(json = jsonlite::parse_json(txt)) |>
  unnest_wider(json, names_sep = "_") |>
  unnest_longer(geometry) |>
  hoist(geometry, lat = c("bounds", "northeast", "lat"))
```

9. `unnest_wider()` 列名冲突会报错，用 `names_sep` 解决。`unnest_longer()` 遇到空元素会丢行，要补 NA 就写 `keep_empty = TRUE`。
10. 解析 JSON 用 `jsonlite::parse_json()` 或 `jsonlite::fromJSON()`。readr 2.2.0 没有 `parse_json()`，旧引用会报错。
    自己拆结构时用 `parse_json()`；`fromJSON(simplifyVector = TRUE)` 会压成难以预测的表。JSON 没有日期类型，导入后再解析。
11. `unnest_auto()` 只在控制台探结构时用。禁止留在提交的脚本里：它把结构选择藏起来，上游一变含义就变。

## 4. 缺失值

1. 区分两类缺失。显式缺失是格子里有 NA，隐式缺失是该有的行或列不存在。两种要用不同方法处理。
2. 把隐式变显式：`complete(year, qtr)` 补网格，`full_join()` 对齐到参照表。找出隐式缺失：`anti_join()`。
   把显式变隐式：`pivot_wider()`；只丢空格用 `values_drop_na = TRUE`。
3. 单元格 NA 用 `coalesce()` 填后备值，或用 `replace_na()`。前向填充用 `fill()`。

```r
grid <- sales |> complete(year, qtr)
gap <- obs |> anti_join(lookup, join_by(id))
seq_ok <- obs |> mutate(day = full_seq(day, 1))
sentinel <- conc |> mutate(pm25 = na_if(pm25, -999), pm25 = coalesce(pm25, 0))
```

4. 哨兵值在导入时就转 NA。`read_csv()` 的 `na` 参数要列全所有缺失记号，例如 `-999`、空串、`N/A`。已经在内存里就用 `na_if()`。
5. 报告缺失量并写进产出登记（`output-data.json`）：

```r
miss_report <- conc |> summarise(n_cell = n(), n_na = sum(is.na(pm25)), frac_na = mean(is.na(pm25)))
```

6. 第三类缺失是空的因子水平。要显示它们就写 `.drop = FALSE`：`count()`、`group_by()` 都支持，绘图用 `scale_x_discrete(drop = FALSE)`。
7. `坑`：零长度组的 `mean()` 返回 `NaN`，`min()` 返回 `Inf`。要么先汇总再 `complete()`（缺点是计数也变 NA），要么显式给默认值。
   `is.na(NaN)` 为 TRUE，只有 `is.nan()` 能区分。`NaN` 来自 `0/0`、`Inf - Inf`、`sqrt(-1)`。

## 5. 数值、排序与阈值

1. 拆编码值用 `%%` 与 `%/%`。例如把 `hhmm` 拆成时与分，也用于把行分进等宽箱。
2. 逐行取极值用 `pmin()`、`pmax()`；整列汇总用 `min()`、`max()`。用错的症状是每行得到同一个值。两者都支持 `na.rm`。
3. 阈值判断用排名族：`min_rank()`（并列 1,2,2,4）、`dense_rank()`、`row_number()`、`percent_rank()`、`cume_dist()`。
   值大的排前面用 `min_rank(desc(x))`。基 R 的 `rank()` 要把 NA 留在末尾就写 `na.last = "keep"`。

```r
flag <- grid |>
  mutate(rank = min_rank(desc(pm25)), cum = cume_dist(pm25)) |>
  filter(cum > 0.95)
```

4. 差分与变化检测用 `lead()`、`lag()`。首行不要 NA 就给 `default`。值一变就开新组用 `consecutive_id()`。

```r
delta <- ts_tbl |> mutate(d = x - lag(x, default = first(x)), changed = x != lag(x))
```

5. `first()`、`last()`、`nth()` 的选项名是 `na_rm`，带下划线。滚动窗口用 `slider` 包（需安装），不要手写循环。
6. 取对数用 `log2()` 或 `log10()`。`round()` 是四舍六入五取偶。`floor()`、`ceiling()` 没有 `digits` 参数，按 0.01 向下取整要先缩放再还原。
7. 分箱：`cut()` 返回因子，界外值为 NA，`labels` 长度比 `breaks` 少 1；只要箱号就写 `labels = FALSE`；只要边界查找用 `findInterval()`；
   等宽、等数分箱用 ggplot2 的 `cut_width()`、`cut_number()`、`cut_interval()`。
8. 选汇总量：对称分布用 `mean()`，偏态用 `median()`。要“最坏情况”用 `quantile(x, 0.95)`，不要用 `max()`。定口径前先画分布和分组分布。
9. `坑`：`filter()` 里给长度大于 1 的向量，tidyverse 只允许长度 1 的回收；基 R 比较会回收，行数整除时静默出错。用 `%in%`。

## 6. 逻辑向量

1. 禁止用 `==` 比较算出来的浮点数，用 `dplyr::near()`。`1/49 * 49 == 1` 是 FALSE。
2. NA 会传染：`NA == NA` 得 NA，判断用 `is.na()`。`NA %in% NA` 是 TRUE，所以把 NA 放进 `%in%` 的向量是合法的含 NA 筛选写法。
3. `filter()` 里用 `&`、`|`、`!`。`&&`、`||` 只用于 `if` 的单值判断。
   `坑`：在 dplyr 动词里写 `&&` 会报错。R 会报长度不符。
4. TRUE 当 1 用：`sum()` 是计数，`mean()` 是比例，`mean(is.na(x))` 是缺失率。条件均值可以内联，但 `filter()` 后 `n()` 的含义会变。
5. 向量分支用 `if_else()`（检查类型，并有 `missing` 参数处理 NA）。多分支用 `case_when()`。
   `坑`：`case_when()` 第一个匹配生效。区间按单调顺序写，缺失判断放最前，末尾给 `.default`。

```r
lab <- df |>
  mutate(cat = case_when(
    is.na(pm25) ~ NA_character_,
    pm25 < 10 ~ "low",
    pm25 < 35 ~ "mid",
    .default = "high"
  ))
```

## 7. 字符串与正则

1. 只用 stringr。不要用 `gsub`、`substr`、`paste0`、`grepl`。
2. 常用动词：`str_detect()`（配 `filter()`）、`str_count()`、`str_subset()`、`str_which()`、`str_replace()`、`str_replace_all()`、
   `str_remove()`、`str_remove_all()`、`str_extract()`、`str_match()`（返回矩阵，能用 `separate_wider_regex()` 就不用它）、
   `str_sub()`（支持负下标，两端都包含，不报错）、`str_trim()`、`str_squish()`、`str_to_lower()`、`str_sort()`、`str_equal()`。
   stringr 1.6.0 有 `str_split_i()`，取第 n 段不必整列拆分。
3. 口径字典的主用法是命名向量配 `str_replace_all()`。`dict` 必须命名并覆盖全部取值。

```r
abbr <- cntry_tbl |> mutate(code = str_replace_all(location, cntry_abbr))
```

4. 拼接用 `str_c()`（遵守 tidyverse 的回收与 NA 规则，可直接进 `mutate()`）。混排大量文本与变量用 `str_glue()`。折叠成一行用 `str_flatten()`。
   `坑`：`str_glue()` 把 NA 变成文本 `NA`，先 `coalesce()` 再拼。
5. 模式对象三种：`regex()`（带 `ignore_case` 等开关）、`fixed()`（把元字符当字面量）、`coll()`（按 locale 匹配非英文）。复杂模式用原始字符串并开 `comments = TRUE`。
6. 正则要素：锚点 `^`、`$`；词边界；字符类与否定类；速记 `\d`、`\s`、`\w` 及大写形式；量词 `?`、`+`、`*`、`{n,}`。
   `坑`：量词优先级高于“或”，多分支一律加括号。不需要捕获的分组用非捕获组。匹配字面点用方括号包起来，或写两个反斜杠。
7. 要“并且”“取非”就把多个 `str_detect()` 用 `&`、`!` 连起来，不要堆一个复杂正则。
8. 每条新正则上线前配两个对照：一个必须命中，一个必须不命中。
9. 来自数据的字符串要参与模式构造时先 `str_escape()`，否则数据里的点和括号会改变模式含义。

## 8. 因子

1. 创建用 `factor(x, levels = ...)`。`坑`：不在 `levels` 里的值静默变 NA，这是本项目映射表最常见错源。
   改用 `forcats::fct()`：同样情况报错。`fct()` 不给 `levels` 时按首次出现排序，跨机器确定；`factor()` 按字母序，依赖 locale。
   forcats 1.0.1 有 `fct()`。`fct_expert_na()` 已从包里移除，处理 NA 水平用 `fct_na_value_to_level()`、`fct_na_level_to_value()`。
2. 排序用 `fct_reorder()`（配 `.fun`，只用于本身无序的类别；收入档这类有内在顺序的不要重排）、`fct_relevel()`、
   `fct_infreq()` 加 `fct_rev()`、折线图图例对齐右端用 `fct_reorder2()`。
   `坑`：`fct_relevel()` 收到数据里不存在的水平会警告（forcats 1.0.1 报 unknown levels）。对照表比数据全时先取交集再重排，并把缺的水平单独报出来。
3. 重排写在 `mutate()` 里，不要塞进 `aes()`。塞进 `aes()` 会让绘图顺序与图例顺序分离，分面时还会出错。
4. 改标签用 `fct_recode()`（左侧新名、右侧旧水平，旧水平不存在会警告）。合并用 `fct_collapse()`。
   归并小群体用 `fct_lump_n()`、`fct_lump_min()`、`fct_lump_prop()`、`fct_lump_lowfreq()`。
   `坑`：归并后产生的“其他”也是一个水平，图例会多出一项。
5. 因子水平顺序就是绘图顺序，必须与图例、分面条、表头一致。读取时就声明：在 `col_types` 里用 `col_factor(levels_vector)`。
6. 有序因子用 `ordered()`。它只影响 ggplot2 默认色板和 `lm()` 的多项式对比。

```r
food <- fct(FOODCAT6)
lv <- factor(region, levels = region_order)
na_lv <- fct_na_value_to_level(x, level = "NA")
```

## 9. 日期与时间

1. 用够用的最简单类型。只要日期就用 date，不要用 datetime；时区问题只出现在 datetime 上。
2. 解析函数按组件顺序命名：`ymd()`、`dmy()`、`mdy()`，带时刻就加 `_hms`、`_hm`。解析时可强制时区。
   `坑`：解析失败返回 NA 并给警告，不报错。除了查 `problems()`，还要统计 NA 数量。

```r
d1 <- ymd(str_sub(fnm, 6, 13))
d2 <- ymd_hms(stamp, tz = "UTC")
any_fmt <- parse_date_time(raw, orders = c("ymd", "dmy", "mdy", "y"))
d3 <- make_date(year = yr, month = mo, day = dy)
```

3. 从年月日三列构造用 `make_date()`、`make_datetime()`。类型互转用 `as_date()`、`as_datetime()`：datetime 的数值是秒，date 的数值是距 1970-01-01 的天数。
4. 改日期用 `update()`，它会滚动越界的日。取标签用 `month(x, label = TRUE)`、`wday(x, label = TRUE, abbr = FALSE)`，返回有序因子，可以直接进图和分面。
5. 时间分箱用 `floor_date()`、`round_date()`、`ceiling_date()`。按周汇总时先 `floor_date(day, "week")` 生成周首列，再 `count()`。
6. 三种时间跨度分别用于不同场景，选错会在夏令时附近出错：
   - duration（`dseconds()` 到 `dyears()`）是精确秒数，`dyears()` 固定 365.25 天且没有月。用于物理时长。
   - period（`days(1)`、`years(1)`）是人类单位。用于日历运算。
   - interval（`a %--% b`）用于一个跨度除以另一个单位，例如 2024 年除以 `days(1)` 得 366。
   `坑`：加 duration 是加固定秒数，跨夏令时会挪钟；加 period 保持墙上时间。默认用 period。
7. 时区是显示属性。同一时刻换 `tz` 后比较仍相等。用 IANA 名，例如 `Asia/Shanghai`；缩写有歧义。
   `with_tz()` 只改显示，`force_tz()` 改真实时刻，只用于数据标错时区的情况。`c()` 会保留第一个元素的时区。
8. `anytime` 包未安装。存量脚本的 `anytime::anydate()` 改用 `lubridate::parse_date_time()`，或装 `clock` 后用 `date_parse()`。

## 10. 数据导入与外部存储

1. 文本用 `readr::read_csv()`、`read_tsv()`。关键列用 `col_types = cols(...)` 显式声明。导入后查 `problems()`，结果存进诊断目录留痕。
2. Excel 用 `readxl::read_excel()`，给全 `sheet`、`range`、`na`。读全部工作表用 `excel_sheets()` 配 `map()`。
   写 xlsx 优先 `writexl::write_xlsx()`。
3. 大 CSV 分块读，本项目 MRIO 用这个写法，避免一次进内存：

```r
chunk <- read_csv_chunked(
  big_path,
  DataFrameCallback$new(\(x, pos) bind_rows(chunk_out, x)),
  skip = 1,
  chunk_size = 1e6
)
```

4. `arrow` 需安装。装好后按书的判据用：可用内存不到文件大小的 2 倍时不要整表读入，改建懒表，`collect()` 时才求值，dplyr 表达式下推给后端。

```r
laz <- open_dataset(part_dir, format = "parquet")
out <- laz |>
  filter(year > 2010) |>
  group_by(year) |>
  summarise(s = sum(v), n = n()) |>
  collect()
written <- tab |> group_by(year) |> write_dataset(part_dir, format = "parquet")
```

5. 分区按会被过滤的变量切。单文件控制在 20MB 到 2GB，分区数低于 1 万。`to_duckdb()` 可以把同一套 dplyr 代码交给 DuckDB。
   `坑`：只有部分 R 表达式能下推，翻不动的退回本地计算且不加提示，换懒表后要确认下推确实发生。
6. 可用替代：`data.table::fread()`（读宽表快）、rds 缓存（保类型）、栅格走 GeoTIFF 磁盘后端。
7. 缓存中间结果：多维数组用 `saveRDS()`、`readRDS()`（保留 dimnames），表用 parquet。禁止用 CSV 当中间格式。

## 11. 基 R 与 tidyverse 混用

1. 混用可以。以下场景基 R 更合适：
   - 向量取值：`[`、`[[`、`$`。`filter()` 等价于逻辑下标，`arrange()` 等价于 `order()`，`select()` 等价于字符下标。
   - `lapply()` 与 `map()` 可以互换。
   - 函数内部用 `vapply()` 固定返回类型。`sapply()` 只在交互探索时用。
   - 单个变量分组小计用 `tapply()`。
   - 矩阵与数组用 `apply()`。
   - 快速 EDA 用 `hist()`、`plot()`。
2. `坑`：`apply(df, 2, fun)` 会把数据框强转成矩阵，全列变成同一类型。改用 `across()`。
3. 循环不慢。预分配加 `for (i in seq_along(x))` 与 `map()` 性能相当。慢的是在循环里反复 `c()`、`rbind()` 扩对象。

## 12. 空间与栅格

1. 矢量读用 `sf::read_sf()`，写用 `sf::write_sf()`，报错信息比 `st_read()`、`st_write()` 清楚。
2. 表与面连接用 `sf::st_join()`。不要手工按名匹配。
3. 坐标系在导入时就统一：`st_transform(x, 4326)`。投影交给 `coord_sf()`。
4. `坑`：`sf_use_s2(FALSE)` 把几何当平面欧氏算。本项目为速度常用，但它改变面积与距离口径，必须写进产出登记，并与 `st_area()` 的用法一致。
5. 栅格入口：`st_as_stars()` 配 `dims = 1:2`，随后 `st_set_crs(4326)`。重投影与降采样用 `st_warp()`，逐格统计用 `st_apply(1:2, sum)`，维度不齐先 `st_redimension()`。输出用 `write_stars()`，指定数据类型与压缩选项。

```r
ras <- df |> st_as_stars(dims = 1:2) |> st_set_crs(4326)
out <- ras |>
  st_warp(target, use_gdal = TRUE, method = "sum", no_data_value = -9999)
write_stars(out, tif_path, type = "Float32", options = "COMPRESS=DEFLATE")
```

6. 物理量一律用 `units::set_units()` 换算（例如面密度乘面积再转质量单位）。换算链写在一处，并在产出登记记录。导出前 `drop_units()`，不要手写换算系数。
7. `terra` 大任务按进程隔离：为每个进程建独立 tempdir，设 `terraOptions(tempdir = , memfrac = )`；结束时清临时文件并删除目录。清理代码放在 `tryCatch(finally = )` 或 `on.exit(add = TRUE)` 里。
8. 点面归属、格网与行政区对齐先 join 再算。禁止用 `which()` 按下标猜对应关系。

## 13. 交付自查

- [ ] 每个 join 有 `join_by()` 键，键唯一性查过，多对多风险已声明或已聚合。
- [ ] 每个 `summarise()` 带 `n = n()`。分组要么用 `.by`，要么显式给 `.groups`。
- [ ] 缺失处理显式（导入声明、`complete()`、`fill()`、`coalesce()`），并在产出登记写明是删、留还是补。
- [ ] 因子用 `fct()` 或带 `levels` 的构造，查过没有静默 NA。绘图顺序与图例一致。
- [ ] `case_when()` 区间无重叠。`filter()` 里没有长度大于 1 的比较。算出来的浮点没有用 `==` 比。
- [ ] 大文件走分块读、rds 或 GeoTIFF 缓存，或（装了 arrow 之后）用懒表。没有用 CSV 当中间格式。
- [ ] 查过 `problems()`。哨兵值已转 NA。单位换算只在一处定义。`sf_use_s2` 这类口径开关写进产出登记。
