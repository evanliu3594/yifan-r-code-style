# 可视化细则：ggplot2、地图与成品图

依据 Hadley Wickham, *ggplot2: Elegant Graphics for Data Analysis* 3e 与
Hadley Wickham, *R for Data Science* 2e 第 10–12 章（layers、EDA、communicate 章）。


## 1. 图层结构

1. 每张图有三部分：数据、美学映射、至少一个图层。图层有五个组件：data、mapping、geom、stat、position。
2. `ggplot()` 的前两个参数是 data、mapping。每个 `geom_*()` 的前两个参数是 mapping、data。顺序相反，这是设计如此。层内换数据必须写 `data =`。
3. 画每一层前先定它属于哪类：显示数据、给统计摘要、还是提供背景与元信息。背景层要淡（低 `alpha`），需要强调的层最后画。图层顺序就是语义顺序。
4. 共享结构（x、y、主分组变量）放 `ggplot()` 的全局映射。只有一层用的数据与映射放该层内。
   `坑`：分组美学放全局还是放层内会改变拟合结果。全局写 `colour = grp` 时，`geom_smooth()` 会给每组各拟合一条。
5. `aes()` 内只写裸列名。ggplot2 4.0.3 对 `aes(x = df$x)` 提示改用裸列名；分面改变行序后这种写法会出错。
6. 自定义出图函数返回 ggplot 对象，不要返回打印结果。要一次返回多个组件就返回 `list()`，ggplot2 会忽略其中的 `NULL`，因此可以条件加层。

```r
layer_list <- list(
  aes(x = pm25, y = mort),
  geom_point(alpha = 0.3),
  if (show_fit) geom_smooth(method = "lm") else NULL,
  theme_classic(base_size = 12)
)
p_pm25_mort <- ggplot(grid_data) + layer_list
```

## 2. 美学映射：进 `aes()` 还是当参数

1. 受变量控制的外观进 `aes()`。固定外观写成层参数。
   `坑`：`aes(colour = "blue")` 会把 blue 当新变量过比例尺，颜色变粉红并多一条图例。
   例外用法：给图层起名进图例时写 `aes(colour = "loess")`，再用 `scale_colour_manual()` 或 `guides()` 控制。
2. 线宽一律用 `linewidth`（线、`geom_col()` 的边、`geom_errorbar()` 等）；点和文字用 `size`。
   ggplot2 4.0.3 实测：线用 `size` 仍报 “Using `size` aesthetic for lines was deprecated in ggplot2 3.4.0”。
3. 计算美学只用 `after_stat()`、`after_scale()`、`stage()`。`stat(count)` 在 4.0.3 已弃用。
   `坑`：`after_stat()` 在统计之后求值，不能引用原始数据列。要在映射阶段改值用 `after_scale()`。

```r
p_pm25_hist <- ggplot(grid_data, aes(x = pm25)) +
  geom_histogram(aes(y = after_stat(density)), bins = 24) +
  geom_density(aes(colour = after_scale(alpha(blue, 0.7))))
```

4. 一张图最多 3 到 4 个视觉通道。类别变量用 colour、shape、linetype；数值变量用 x、y、size、fill。
   shape 超过 6 类、colour 超过 8 类就分面。

## 3. 比例尺：limits、expand、breaks、labels、oob

1. 命名规律是 `scale_<美学>_<类型>()`。类型有 `continuous`、`discrete`、`binned`、`manual`、`identity`、`date`、`datetime`、`log10`、`sqrt`、`reverse`。
   一个美学只能挂一个比例尺，后写的覆盖先写的并报警告。4.0.3 有 `scale_*_binned()` 系列。
2. 三个参数分工：
   - `limits` 改变数据取值范围，界外值先转 NA 再参与统计。只用于跨图对齐尺度或往外扩。
   - `expand` 在范围外留白，用 `expansion(add = , mult = )`。条形图 y 轴要去掉底部留白保证零基线。
   - `oob` 决定界外值怎么处理，默认 `scales::oob_censor()`；压回界内用 `oob_squish()`，丢弃用 `oob_discard()`。
   放大或缩小视野一律用坐标层：`coord_cartesian(xlim = )`、`coord_sf(xlim = )`。这样统计量仍按全量数据算。

```r
p_mort_by_country <- ggplot(grid_data, aes(x = cntry, y = mort)) +
  geom_col() +
  scale_y_continuous(
    limits = c(0, max(c(grid_data$mort, ref_data$mort))),
    expand = expansion(mult = c(0, 0.05)),
    breaks = scales::breaks_pretty(n = 5),
    labels = scales::label_comma()
  ) +
  coord_cartesian(ylim = c(0, 40))
```

3. `breaks` 可以给向量、`NULL`（连网格线一起去掉）或函数。scales 1.4.0 有 `breaks_extended()`、`breaks_pretty()`、`breaks_width()`、`breaks_log()`、`breaks_timespan()`、`breaks_hms()`。
4. `labels` 可以给 `NULL`（只去文字）、命名向量（只改部分标签）或函数：`label_percent()`、`label_comma()`、`label_dollar()`、`label_pvalue()`、`label_date()`。
5. 日期轴用 `scale_x_date(date_breaks = "2 years", date_labels = "%Y")`。不要手算 breaks。
6. 次坐标轴用 `sec.axis`（4.0.3 的 `scale_*_continuous()` 有此参数）。只用于同一变量的线性变换，例如换单位。禁止用它塞第二个不相关的变量。
7. 变换用 `transform = "log1p"`，或 `scale_*_log10()`。scales 1.4.0 提供 `transform_log1p()`、`transform_boxcox()`、`transform_yj()`、`transform_sqrt()`、`transform_reverse()`。
   透明性：比例尺变换后刻度仍是原数据值，发表图用这种；在 `aes()` 里手算 log 会让刻度变成变换值，读者容易误读。

## 4. 配色

1. 类别色用 `scale_colour_brewer()`、`scale_fill_brewer()`（点图用鲜色 Set1、Dark2；大面积用柔色 Set2、Pastel）、`scale_colour_viridis_d()`，或手写 Okabe-Ito 色板。
   连续用 `scale_*_distiller()`，分箱用 `scale_*_fermenter()`（出处：`scales-colour.qmd`）。
   4.0.3 没有 `scale_colour_brewer_d()` 这种后缀写法。第三方色板如 `ggthemes::scale_fill_gdocs()` 可用，但要全项目统一。

```r
oi_pal <- c("#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7", "#999999")
p_scenario_plot <- p_scenario_plot + scale_fill_manual(values = set_names(oi_pal, sce17_order), name = "Scenario")
```

2. 连续色用 `scale_*_viridis_c()`（可给 `option = "magma"`）或 `scico::scale_colour_scico()`。
   单方向双色用 `scale_*_gradient(low = , high = )`。有对照中心（正负、增减）用 `scale_*_gradient2(low = , mid = , high = , midpoint = )`，`midpoint` 必须显式给：默认是 0，数据不对称时中点会错位。
   n 个色标用 `scale_*_gradientn(colours = , values = )`，`values` 用来把非均匀分位映射到颜色。
3. 分箱色阶用 `scale_*_binned()`、`scale_*_steps()`、`scale_*_stepsn()`。
4. `na.value` 必须显式设定。默认灰色会被读成一个有效等级。要隐藏就设 `na.value = NA`。
5. 图例：低透明度散点图必须覆写图例外观。同一变量映射到多个美学时会自动合并图例，但要求各图例 `name` 相同（用 `labs()` 统一改）。

```r
p_scenario_plot <- p_scenario_plot + guides(colour = guide_legend(override.aes = list(alpha = 1, size = 3)))
p_scenario_plot <- p_scenario_plot + guides(fill = guide_coloursteps(even.steps = FALSE, show.limits = TRUE))
```

6. `坑`：一个美学挂两个比例尺需要 `ggnewscale::new_scale_colour()`（需安装）。出现这种需求说明图超载了，应该分面或拆成两张图。
7. 色盲安全之外再加一层冗余：用 shape 或 linetype 重复编码同一分组。避免只用红绿对比。

## 5. 坐标系统与地图

1. 空间数据一律用 `geom_sf()` 配 `coord_sf()`。不要手工映射经纬度。几何列自动识别，有多个几何列时才在 `aes()` 里指定。面标注用 `geom_sf_text()`、`geom_sf_label()`。
2. 栅格用 `stars::geom_stars(data = , aes(fill = ))`，或用 `tidyterra::geom_spatraster()`。
3. 4.0.3 的 `coord_sf()` 参数：`xlim`、`ylim`、`expand`、`crs`、`default_crs`、`datum`、`label_graticule`、`label_axes`、`lims_method`、`ndiscr`、`clip`、`reverse`。
4. 世界地图（项目约定）：投影写 `crs`，数据坐标系写 `default_crs`，两个都要给。

```r
world_plot <- ggplot() +
  geom_stars(data = conc_ras, aes(fill = conc), sf = TRUE) +
  geom_sf(data = world, colour = "gray10", fill = NA, linewidth = 0.2) +
  coord_sf(
    crs = "+proj=robin",
    default_crs = sf::st_crs(4326),
    xlim = c(-180, 180),
    ylim = c(-90, 90),
    datum = sf::st_crs(4326)
  ) +
  theme_void()
```

   - `default_crs` 不给时，`xlim`、`ylim` 按投影平面坐标解释，整图渲染异常。这是本项目踩过的坑。
   - `datum` 控制经纬度网格的加密方式，跨日界线的多边形形变靠它调。
   - 排除南极用 `ylim`，不要删数据。
   - 经纬度标注位置用 `label_graticule`、`label_axes`。
5. 等比非地图用 `coord_fixed()`（旧名 `coord_equal`）。栅格图常用它。只有经纬度多边形、暂时不做投影时用 `coord_quickmap()`（等纵横比近似）。
   `geom_raster()` 在 4.0.3 实测无弃用提示，可用于等尺寸密集栅格，配 `expand = expansion(0)` 去边距。
6. `coord_flip()` 在 4.0.3 实测不报警告。官方自 3.5 起推荐在图层里写 `orientation` 或直接交换 x、y。新图按官方推荐写。
7. 想在原始尺度解读、在变换尺度拟合：`scale_*_log10()` 配 `coord_trans(x = "log10")`。比例尺变换发生在统计之前，坐标变换发生在渲染阶段。

## 6. 分面

1. 一个变量多个水平用 `facet_wrap(~ var, nrow = , ncol = , dir = , as.table = )`。两个变量交叉用 `facet_grid(rows ~ cols)`，`a + b ~ c` 支持嵌套。水平数量多的放列方向。
   `facet_wrap` 更省空间，通常比 `facet_grid` 有用。
2. 比较目标决定 `scales`。跨面板比模式用固定尺度（默认）。比小值组内部形态用 `scales = "free_y"`。
   面板宽度按数据范围分配用 `facet_grid` 的 `space = "free"`。只比 y 用 `. ~ var`，只比 x 用 `var ~ .`。
   轴与条带位置用 `axes`、`strip.position`、`switch`。长标签配 `theme(strip.text.y = element_text(angle = 0))`。
3. 连续变量先分箱才能分面：分面只接受离散变量，且在 `mutate()` 里算好新列，公式里不执行函数。
4. 辅助层没有分面变量时会被复制到每个面板。这是可用特性，也是陷阱：底图与跨面板参考线利用它，只想出现在一个面板的标注必须补上分面变量。
   跨面板参考线用 `geom_hline()`、`geom_abline()`。
5. 分面还是颜色：组间差异小、组数少用颜色；组重叠严重或要看绝对数值差异用分面。跨分面比较时加注释层（灰化背景数据、每组均值点）。
6. 分面顺序由因子水平决定。先在 `mutate()` 里 `fct_relevel()` 或 `fct_reorder()`，不要依赖默认字母序。

```r
p_mort_trend <- ggplot(grid_data, aes(x = year, y = mort)) +
  geom_line(aes(group = region)) +
  facet_grid(sector ~ scen, scales = "free_y", switch = "y")
```

## 7. 常用 geom 与 stat

1. 散点按数据量选法：点少用 `shape = 1` 或 `"."`；中等用 `alpha`，取值 1/10 到 1/50（分母是叠加成实心所需点数，小于 1/500 会全透明）；
   离散变量用 `geom_jitter(width = , height = )`；点多用 `geom_bin2d()` 或 `geom_hex()`（六边形视觉伪影更少）；数点用 `geom_count()`；二维密度用 `geom_density_2d()`。
2. 不确定度：离散 x 用 `geom_errorbar()`、`geom_linerange()`、`geom_pointrange()`、`geom_crossbar()`，给 `ymin`、`ymax`；连续 x 用 `geom_ribbon()`。SE 自己在 dplyr 里算好。
3. 平滑用 `geom_smooth()`。`n < 1000` 默认 loess（用 `span` 控制波动），`n > 1000` 自动改 GAM。不要置信带就写 `se = FALSE`。
   4.0.3 的 `geom_smooth()` 参数是 `method`、`formula`、`se`，`method.args` 在 `stat_smooth()` 上。实测传 `fun.data` 会被 “Ignoring unknown parameters” 静默忽略。自定义汇总改用 `stat_summary(fun = , fun.args = )`。
   4.0.3 没有 `geom_summary()`。
4. 柱：预汇总数据用 `geom_col()`；原始计数用 `geom_bar()`（默认 `stat = "count"`）。画“各组的值”时优先 `geom_point()`：不要求零基线、更省空间。柱状只在强调构成或总量时用。
5. 时序用 `geom_line()`（按 x 排序）；时间藏在行序里时用 `geom_path()`。方向难辨就改成 `geom_point(aes(colour = year))`。
   `坑`：默认 group 是所有离散美学的交互。长表画多条线必须写 `aes(group = id)`。线段颜色取每段首点的值。`geom_polygon()` 要求各观测点美学一致，否则退回灰色。
6. 文字：`geom_text()`、`geom_label()` 配 `hjust = "inward"`、`vjust = "inward"` 防出界。标签密集用 `ggrepel::geom_text_repel()`，或本项目在用的 `shadowtext::geom_shadowtext()`（带描边，叠在栅格上可读）。
   `坑`：文字不参与 `limits` 计算，标注越界要手动扩 `xlim`。`geom_text()` 的 `size` 单位是 mm，其他工具是 pt。
7. 分布对比用 `geom_boxplot()`（样本量差异大时写 `varwidth = TRUE`；连续 x 需要 `aes(group = cut_width(x, 0.1))`）、`geom_violin()`、`geom_freqpoly(aes(y = after_stat(density)))`。
8. 两个分类变量的频次用 `count()` 配 `geom_tile(aes(fill = n))`。

## 8. 统计汇总的诚实性

1. 必须实验分箱宽度。默认的 30 bins 不可信。`binwidth`、`bins`、`breaks` 三者选一个，发表图在 caption 里注明分箱规则。
2. 组规模悬殊时比分布形状，用密度（`after_stat(density)`）或频率多边形。堆叠比例图（`position = "fill"`）最难读，只在强调构成时用，
   并且必须把 y 轴标签从默认的 count 改成比例（写 proportion 或 Percentage）。
3. 区分两种权重：只影响视觉大小用 `size` 配 `scale_size_area()`（0 映射到 0 面积）；进入统计计算的用 `weight` 美学
   （`geom_smooth()`、`geom_histogram()`、`geom_boxplot()`、`geom_density()` 支持，且不产生图例）。
4. `stat_summary()`、`stat_summary_bin()`、`stat_summary_2d()` 能做 mean 之外的汇总，但书里承认它们受限。复杂汇总先在 dplyr 里算成表，再用 `geom_col()`、`geom_errorbar()` 画。

## 9. 主题与文字

1. 先用 complete theme 打底，再用 `theme()` 逐项覆盖元素。4.0.3 自带的有 `theme_bw()`、`theme_minimal()`、`theme_linedraw()`、`theme_classic()`、`theme_dark()`、`theme_void()`、`theme_test()`、`theme_gray()`。
   `坑`：存量脚本用的 `theme_half_open()` 不在 ggplot2 也不在 ggthemes（实测），来自另一个未安装的第三方主题包。新图用自带主题，或自己拼：`theme_classic()` 加 `theme(panel.border = )`。
2. `element_blank()` 删除元素并回收空间。`colour = NA`、`fill = NA` 是隐形但占位，多图对齐时用后者。
3. 轴类元素有方向后缀：`axis.text` 设公共值，`axis.text.x`、`axis.text.y` 覆写；`strip.text.y` 同理。
   4.0.3 的元素表（160 项）里没有 `legend.text.x`、`legend.text.y`。图例只能整体设 `legend.text`，方向差异用 `guides()` 或分图处理。
4. `base_size` 是轴标题的字号（标题 1.2 倍，刻度和条带 0.8 倍），不是全图字号。项目默认 `theme_minimal(base_size = 12)`，发表图用 `base_size = 11` 配 `aspect.ratio`。
5. 改全局默认用 `theme_set()`，临时改 `theme_update()`。本项目每张图自带 `theme()`，不依赖全局状态，保证脚本可重跑。
6. 图例位置：宽扁图放 top 或 bottom，窄高图放 left 或 right。不需要图例就 `theme(legend.position = "none")`，改为图内直接标注。图内定位用 `legend.position = c(x, y)` 配 `legend.justification`。
7. `aspect.ratio` 只管 panel，不含标题与图例。地图与等比散点必须设 `= 1`。
8. `showtext` 与 `ggtext` 需安装。默认设备字体在部分中文标签下缺字，出图前必须肉眼看渲染结果。要富文本标签或嵌入字体先装这两个包，并在脚本里显式 `showtext_auto()`。
9. 数学标签（项目主用法）：单位与下标用 `expression()`、`bquote()`；动态标题用 `parse(text = str_glue(...))`。
   - 化学式、上下标、希腊字母、运算符用 expr。例：`bquote(PM[2.5] ~ "(" ~ mu * "g/" * m^3 ~ ")")`。
   - expr 的加粗用 `bold()` 包裹；`element_text(face = "bold")` 对 expr 无效。

```r
p_pm25_mort <- p_pm25_mort +
  labs(
    x = bquote(bold(PM[2.5] ~ " (" * mu * g ~ m^3 * ")")),
    y = bquote(atop(bold(Mortality ~ Rate), "(Death~per~10^5~pop)")),
    title = parse(text = str_glue("bold({pollu} - {sector})"))
  )
```

   `坑`：`parse(text = )` 里塞进含特殊字符的数据值会报错或渲染成空白。含非 ASCII 时改用纯文本 `labs(title = str_glue(...))`。

## 10. 拼图与输出

1. 优先 patchwork：`p_pm25_mort + p_mort_trend`、`|`、`/`、`plot_layout(ncol = , heights = , design = )`、`guide_area()` 集中放图例。
   子图用 `[[]]` 修改。给整组统一加主题或比例尺用 `&`。

```r
p_combined <- (p_pm25_mort | p_mort_trend) + plot_layout(widths = c(2, 1), guides = "collect")
p_combined <- p_combined + plot_annotation(title = "Exposure and mortality by scenario",
                             tag_levels = "A", caption = "Data: CEDS v2014, GTAP v11")
```

2. 整组标题与来源属于组合，用 `plot_annotation()`。学术图必须带面板标号（A、B、C）。
3. cowplot 的用途是抽组件：`get_plot_component(p_exposure_map, "guide", return_all = TRUE)` 可以把某张图的图例单独放到组合底部；
   以及 `plot_grid(..., labels = , rel_heights = )` 与 `ggdraw()` 叠加。两个包并存时全项目固定一种组合风格。
4. 输出优先矢量（`.pdf`、`.svg`）。光栅只在点极多或交付给 Office 时用，`dpi = 300`；屏显用 96。
   `ggsave()` 参数：`filename`、`plot`、`device`、`path`、`scale`、`width`、`height`、`units`、`dpi`、`limitsize`、`bg`、`create.dir`。
   同一张图要 png 与 pdf 两版时，两次调用的 `width`、`height` 必须一致，否则字号与比例尺跟着变。

```r
# fig_dir 与文件名在配置段定义，目录位置由项目约定给出
ggsave(
  file.path(fig_dir, out_png),
  p_exposure_map,
  width = 8,
  height = 6,
  dpi = 300,
  create.dir = TRUE
)
ggsave(
  file.path(fig_dir, out_pdf),
  p_exposure_map,
  width = 8,
  height = 6
)
```

## 11. EDA 与诚实可视化

1. 2e 的探索框架是变异与共变。单变量看典型值、罕见值、簇、异常值。再按分类×分类、分类×数值、数值×数值看共变。
   强关系之下要看弱模式：先拟合，再画残差图，而不是把两个强变量并排放。
2. 异常值按这个顺序处理：用 `coord_cartesian(ylim = )` 放大低值区找出来；用 `if_else()` 改成 NA，不要删整行；
   含与不含异常值各跑一次分析；影响大就查明成因，并在正文披露。
3. 标题写结论，不写内容。例：Fuel efficiency generally decreases with engine size。不设副标题；情景、年份与来源写进 `caption`，轴标签展开变量名并带单位。
4. 缺失不得静默。ggplot 提示 “Removed n rows containing missing values” 说明有数据被丢。要么显式处理（`na.rm = TRUE`）并在产出登记写丢了多少，要么补上缺失分类。
5. 透明度：图上披露分母与样本量（例如 `n = 344`）；对数尺度、分箱宽度、比例截断都要写进 caption。颜色与大小不编码与内容无关的东西。
6. 条形与面积的基线必须在 0：`scale_y_continuous(expand = expansion(mult = c(0, 0.05)))`。禁止截断坐标轴制造差异。
7. 分两类图命名：探索图快出快丢，成品图再打磨主题与标签。探索图不直接进交付物。

## 12. 编程化出图

1. 按变量出图用 embracing：`aes(fill = {{ var }})`。旧的引号变体 `aes_()`、`gather_()` 不用。动态列名用 `!!sym(col)`。
2. 批量出图把组件放 list 再 `lapply()`。同形多图拆成两个函数：一个变换数据，一个画图。
3. 减少重复可以先存可复用的组件对象（例如 `band <- geom_ribbon(...)`）再复用。参数分发复杂时用 `modifyList()` 配 `do.call()`，或者写自定义 geom。
4. 自包含的注释层设 `inherit.aes = FALSE`、`show.legend = FALSE`。
5. 循环出图时路径、标题、情景名都从数据表里取（用 `pmap()`），每次 `ggsave()` 用不同文件名。循环内不要 `print()` 图：`Rscript` 下无意义，要存盘。
6. 逐要素构造时保留具名中间对象：先 `p_base`，再 `p_base + geom_x()` 赋给新名字。单步调试时能直接打印中间量。

## 13. 交付自查

- [ ] 线宽用 `linewidth`；计算美学用 `after_stat()`、`after_scale()`、`stage()`；没有 `stat()`、`..x..`、`fun.data`。
- [ ] `aes()` 内全是裸列名，没有 `df$col`。分组层确认过 `group` 语义。
- [ ] 放大局部用 `coord_*()`；`limits` 只用于对齐尺度；色标 `limits` 取数据列；`na.value` 显式设定。
- [ ] 分箱宽度经过实验并写进 caption。`breaks`、`labels` 与单位一致。变换尺度已注明。
- [ ] 类别编码不超过 6 到 8 类。配色色盲安全。低透明度图有 `override.aes`。
- [ ] 地图给全 `crs` 与 `default_crs`。南极用 `ylim` 排除。`aspect.ratio` 正确。
- [ ] 标题写结论，不设副标题，轴带单位，caption 写来源与样本量。缺失行有交代。异常值未静默删除。
- [ ] 中文标签肉眼核过渲染。png 与 pdf 尺寸一致，写进图目录，文件名与项目命名约定一致。
