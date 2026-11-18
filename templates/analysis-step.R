# 名称: step1_calc_exposure.R
# 作用: 按情景与区域汇总基准暴露浓度，输出结果表与中间缓存
# 输入: 中间目录的 step0_grid.rds（缓存未命中时回源重建）
# 输出: 结果目录的 exposure_<scenario>_<yymmdd>.xlsx 与 output-data.json；
#       中间目录的 step1_exposure.rds
# 诊断: 诊断目录的 step1_check_<yymmdd>.log
# 运行: Rscript --vanilla R/step1_calc_exposure.R
# 版本: v1.0（<yymmdd>）：初稿

# 计算框架：读 step0 网格（缓存优先）→ 换算单位 → 校验列与键
# → 按 SCE17 与 species 汇总 → 输出 xlsx 与 output-data.json。
# 公式：emis_t = set_units(set_units(emis, "kg/yr"), "t/yr")；
# conc = emis_t / n_cell；frac_na = n_na / n_cell；总量守恒相对偏差 < 1e-6。
# 输出口径：情景 MRBRT，基准年 2019；单位 t/yr；保留 NA 并在 n_na 报告；
# 情景与年份写进 output-data.json。

library(tidyverse)
library(units)
source(here::here("R", "_common_proc.R"))

# 配置层：情景、年份与目录只在这里定义一次。
scenario <- "MRBRT"
base_year <- 2019
out_date <- format(Sys.Date(), "%y%m%d")
random_seed <- 260902L
dir_processed <- "data/proc"
dir_output <- "output"
dir_diagnosis <- "diagnosis"

species_map <- c(BC = "BC", OC = "OC", NH3 = "NH3", SO2 = "SO2", NOx = "NOX")

# 目录层：确保中间、结果、诊断目录存在。
for (directory in c(dir_processed, dir_output, dir_diagnosis)) {
  dir.create(here::here(directory), recursive = TRUE, showWarnings = FALSE)
}

set.seed(random_seed)

# 缓存层：缓存命中直接读，未命中回源重建并写缓存。
cache_path <- here::here(file.path(dir_processed, "step0_grid.rds"))

if (file.exists(cache_path)) {
  grid_raw <- readRDS(cache_path)
} else {
  grid_raw <- rebuild_step0_grid(scen = scenario, year = base_year)

  saveRDS(grid_raw, cache_path)
}

# 校验层：核对列、物种字典与格网键唯一性。
expected_cols <- c("x", "y", "SCE17", "species", "emis")

stopifnot(
  "缺少必需列" = all(expected_cols %in% names(grid_raw)),
  "物种取值超出字典" = all(grid_raw$species %in% names(species_map))
)

grid <- grid_raw |>
  mutate(emis_t = set_units(set_units(emis, "kg/yr"), "t/yr")) |>
  filter(!is.na(SCE17))

dup_key <- grid |>
  count(x, y, SCE17, name = "n_key") |>
  filter(n_key > 1)

stopifnot("格网键重复" = nrow(dup_key) == 0)

# 计算层：按 SCE17 与 species 汇总；conc = emis_t / n_cell；带 n_cell 与 n_na。
exposure <- grid |>
  summarise(
    emis_t = sum(emis_t, na.rm = TRUE),
    n_cell = n(),
    n_na = sum(is.na(emis_t)),
    .by = c(SCE17, species)
  ) |>
  mutate(
    conc = emis_t / n_cell,
    frac_na = n_na / n_cell
  )

tot_step1 <- sum(exposure$emis_t)
tot_step0 <- sum(grid$emis_t, na.rm = TRUE)

stopifnot(
  "总量不守恒" = drop_units(abs(tot_step1 - tot_step0) / tot_step0) < 1e-6
)

# 输出层：写 xlsx、output-data.json、rds 与诊断日志。
out_xlsx <- here::here(
  file.path(dir_output, sprintf("exposure_%s_%s.xlsx", scenario, out_date))
)

exposure_out <- exposure |>
  mutate(
    emis_t = drop_units(emis_t),
    conc = drop_units(conc)
  )

writexl::write_xlsx(exposure_out, out_xlsx)

reg_path <- here::here(file.path(dir_output, "output-data.json"))

reg <- if (file.exists(reg_path)) {
  jsonlite::fromJSON(reg_path, simplifyVector = FALSE)
} else {
  list()
}

new_entry <- list(
  filename = basename(out_xlsx),
  content = "按情景与区域汇总的基准暴露浓度",
  type = "data.frame",
  method = sprintf(
    "情景 %s；基准年 %s；单位 t/yr；保留 NA 并报告 n_na；总量守恒相对偏差 < 1e-6",
    scenario, base_year
  ),
  script = "step1_calc_exposure.R",
  keys = I(c("SCE17", "species")),
  unit = "t/yr"
)

reg <- append(reg, list(new_entry))
jsonlite::write_json(reg, reg_path, pretty = TRUE, auto_unbox = TRUE)

saveRDS(
  exposure,
  here::here(file.path(dir_processed, "step1_exposure.rds"))
)

writeLines(
  c(
    paste("date:", out_date),
    paste("scenario:", scenario),
    paste("total_emis_t:", format(drop_units(tot_step1), digits = 10)),
    paste("n_region:", dplyr::n_distinct(exposure$SCE17)),
    paste("dup_key_rows:", nrow(dup_key))
  ),
  here::here(file.path(dir_diagnosis, sprintf("step1_check_%s.log", out_date)))
)

cli::cli_inform("step1 完成：{nrow(exposure)} 行，输出 {out_xlsx}")

print(sessioninfo::session_info())
