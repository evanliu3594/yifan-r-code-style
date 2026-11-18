# 名称: fig_exposure_map.R
# 作用: 画基准情景下分区域暴露浓度世界图，输出 png 与 pdf 两个版本
# 输入: 中间目录的 step1_exposure.rds、join_country_sce17.rds；底图用 rnaturalearth
# 输出: 图目录的 fig01_exposure_<scenario>_<yymmdd>.png 与 .pdf
# 运行: Rscript --vanilla R/fig_exposure_map.R
# 版本: v1.0（<yymmdd>）：初稿

# 计算框架：读中间结果，选 PM2.5，按区域排序，连接世界地图，按浓度填色，导出 png 与 pdf。
# 公式：conc = 区域暴露总量 / 区域网格数（step1 已算）；本图只对 conc 填色。
# 输出口径：情景 MRBRT，基准年 2019；PM2.5 浓度单位 ug/m3；排除南极；png 与 pdf 同尺寸。

library(tidyverse)
library(sf)
source(here::here("R", "_common_proc.R"))

# 配置层：情景、年份、图号、尺寸与目录只在这里定义一次。
scenario <- "MRBRT"
base_year <- 2019
fig_id <- "fig01"
out_date <- format(Sys.Date(), "%y%m%d")
fig_width <- 8
fig_height <- 6
fig_dpi <- 300
dir_processed <- "data/proc"
dir_figures <- "pics"
species_selected <- "PM2_5"

dir.create(here::here(dir_figures), recursive = TRUE, showWarnings = FALSE)

# 数据层：只读已核算的中间结果，不在绘图脚本重算口径。区域顺序取 step0 链接表，缺失区域显式报告。
exposure <- readRDS(here::here(file.path(dir_processed, "step1_exposure.rds")))

stopifnot(
  "结果表缺少绘图必需列" = all(c("SCE17", "conc", "species") %in% names(exposure))
)

stopifnot(
  "物种键不在结果表中" = species_selected %in% unique(exposure$species)
)

region_lookup <- readRDS(
  here::here(file.path(dir_processed, "join_country_sce17.rds"))
)

region_order <- unique(region_lookup$SCE17)
present_regions <- intersect(region_order, unique(exposure$SCE17))

missing_regions <- setdiff(region_order, unique(exposure$SCE17))

if (length(missing_regions) > 0) {
  cli::cli_warn("以下区域码在结果表中缺失，绘图顺序按实有水平排：{missing_regions}")
}

pm25_exposure <- exposure |>
  filter(species == species_selected) |>
  mutate(SCE17 = fct_relevel(as_factor(SCE17), present_regions))

world <- rnaturalearth::ne_countries(scale = "medium", returnclass = "sf") |>
  st_transform(4326) |>
  left_join(region_lookup, join_by(name == country_name)) |>
  select(SCE17, geometry)

# 绘图层：底图做地理参照，数据层按 conc 填色；标题写结论与单位，caption 写情景、来源与样本量。
map_layer <- world |>
  left_join(pm25_exposure |> distinct(SCE17, conc), join_by(SCE17))

p_exposure_map <- ggplot() +
  geom_sf(data = world, colour = "gray40", fill = NA, linewidth = 0.15) +
  geom_sf(data = map_layer, aes(fill = conc), linewidth = 0.1) +
  scale_fill_viridis_c(
    option = "magma",
    name = bquote(PM[2.5] ~ "(" ~ mu * "g/" * m^3 ~ ")"),
    na.value = "white",
    labels = scales::label_number(accuracy = 0.1)
  ) +
  coord_sf(
    crs = "+proj=robin",
    default_crs = st_crs(4326),
    xlim = c(-180, 180),
    ylim = c(-60, 89.9),
    datum = st_crs(4326)
  ) +
  labs(
    title = bquote(
      bold(
        "Food-related " * PM[2.5] *
          " exposure concentrates in South and East Asia (" *
          mu * "g/" * m^3 * ")"
      )
    ),
    caption = sprintf(
      "%s %d; Data: CEDS v2014, GTAP v11; n = %d regions",
      scenario, base_year, n_distinct(pm25_exposure$SCE17)
    )
  ) +
  theme_void(base_size = 11) +
  theme(
    legend.position = "bottom",
    plot.background = element_rect(fill = "white", colour = NA)
  )

# 输出层：png 与 pdf 共用尺寸，文件名含图号、主题、情景、日期。
out_png <- file.path(
  dir_figures,
  sprintf("%s_exposure_%s_%s.png", fig_id, scenario, out_date)
)

out_pdf <- file.path(
  dir_figures,
  sprintf("%s_exposure_%s_%s.pdf", fig_id, scenario, out_date)
)

ggsave(
  here::here(out_png),
  p_exposure_map,
  width = fig_width,
  height = fig_height,
  dpi = fig_dpi
)

ggsave(
  here::here(out_pdf),
  p_exposure_map,
  width = fig_width,
  height = fig_height
)

cli::cli_inform("图已保存：{out_png} 与 {out_pdf}")

print(sessioninfo::session_info())
