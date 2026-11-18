# 命名与口径登记

本文件是 §2 的细则，讲三件事：跨文件边界的名字记在哪、格式豁免怎么写、同名不同义怎么防。

## 1. 依据

- `lintr::object_name_linter()` 只检查赋值目标与形参。列名、`$` 访问、`rename()` 的新名它看不到。
- 同一概念写成多个名字，静态检查不报，运行时 join 静默错配。
- 同一名字承载不同对象，静态检查不报。例如 `PM25` 在一处是文件名向量，在另一处是数据框。
- 登记表给作者、agent、检查脚本一份共同参照。

## 2. 位置

| 项目形态 | 登记表位置 |
|---|---|
| 脚本在 `R/` | `R/_variables.json` |
| 脚本平铺在项目根（旧项目） | `_variables.json`，迁入 `R/` 时一起移动 |

新项目从 `templates/variables.json` 复制登记表，从 `templates/_variables.R` 复制检查脚本。
登记表与脚本同目录，随代码进版本库。

## 3. 字段

JSON 顶层是数组。数组里一个对象一个概念。

| 字段 | 类型 | 必填 | 内容 | 例 |
|---|---|---|---|---|
| `name` | 字符串 | 是 | 规范名 | `"pm25"` |
| `concept` | 字符串 | 是 | 概念键，全表唯一 | `"pm25_grid"` |
| `meaning` | 字符串 | 是 | 一句话定义，写口径 | `"网格 PM2.5 年均质量浓度"` |
| `unit` | 字符串 | 是 | 单位，无量纲写 `"-"` | `"ug/m3"` |
| `type_shape` | 字符串 | 是 | 类型与维度 | `"SpatRaster[lon;lat]"` |
| `aliases` | 字符串数组 | 否 | 旧名与外部列名 | `["PM25", "simulated_PM25"]` |
| `where` | 字符串 | 否 | 首次定义位置 | `"1.calibrate_concentration.R:165"` |

```json
[
  {
    "name": "pm25",
    "concept": "pm25_grid",
    "meaning": "网格 PM2.5 年均质量浓度",
    "unit": "ug/m3",
    "type_shape": "SpatRaster[lon;lat]",
    "aliases": ["PM25", "simulated_PM25"],
    "where": "1.calibrate_concentration.R:165"
  }
]
```

用 UTF-8 存。JSON 不支持注释；说明写进 `meaning` 或本文件。

## 4. 规则

1. 数组里一个对象一个概念。`concept` 全表唯一。
2. `name` 全表唯一。`aliases` 数组里的名字全表唯一，一个旧名只指向一个概念。
3. `meaning` 与 `unit` 必填。无量纲写 `-`。
4. `aliases` 只写实际在代码或输入数据中出现过的名字。
5. 只登记三类：跨文件边界的列与对象、口径易混的量、外部数据源常量。局部变量、循环变量、单文件中间对象不登记。
6. 变量名写数据内容，不写用途或位置。`plot_data`、`output1` 这类名字不登记。

### 4.1 新增变量的流程

1. 先问用户：说明概念、含义、单位、口径，以及现有登记名为什么不够用。
2. 用户同意后，在 `_variables.json` 的数组里新增一个对象。`name`、`concept`、`meaning`、`unit`、`type_shape` 必填。
3. 再写代码。代码里的列名与对象名用登记的 `name`。
4. 名字不符合 snake_case 时，同时在项目 `.lintr` 的 `regexes` 里登记豁免，写清理由。

顺序不得颠倒。

## 5. 用法

```r
source("R/_variables.R")

# 读表
variables <- read_variables()

# step0 检查：表质量、别名命中、废弃提示
check_variables()

# 首次建表：扫出未登记的赋值名
variables_suggest()
```

脚本引用边界列时，用 `read_variables()` 取名字，不手写字符串。

脚本平铺在项目根时，`source("_variables.R")`，并给三个函数传 `dir = "."`。

## 6. 格式豁免

默认只用 `snake_case`。其他命名写入项目 `.lintr` 的 `regexes`，不写进登记表。登记表管语义，lintr 管格式。

- 按前缀族登记。一条正则覆盖一族：`"GLC 数据源对象" = "^GLC_[a-z0-9_]+$"`。
- 全大写对象也走豁免：`"17 区域情景" = "^SCE17$"`。
- 自定义中缀运算符也走豁免：`"自定义中缀" = "^%.*%$"`。
- 每条正则写理由。理由会进 lint 消息。
- 待迁移旧名用行内 `# nolint object_name_linter: 待迁移到 xxx`。它保持可见，清完即删。
- 旧名写进 `regexes` 会永久隐藏债务。

合法风格名只有 8 个。默认只用 `snake_case`。
`match.arg(..., several.ok = TRUE)` 静默丢弃未匹配项。写错名字时配置不报错，对应风格失效。

## 7. 检查项

`check_variables()` 报八类问题：

| 级别 | 问题 |
|---|---|
| error | 缺字段 |
| error | `concept` 重复 |
| error | `name` 重复 |
| error | 一个别名指向多个概念 |
| error | `meaning` 为空 |
| error | `unit` 为空 |
| error | 别名出现在 `R/*.R` 的符号或字符串里 |
| info | 登记名从未出现且无别名 |

有 error 时函数中止。step0 跑一次，交付前跑一次。

## 8. 维护

- 新增边界列：先登记，再写代码。
- 改名：旧名移进 `aliases` 数组，代码改用规范名。
- 迁移完成：从 `aliases` 数组删除旧名。旧名清零后，登记表只剩规范名。
- 概念废弃：删除该对象，并在项目历史记录里记一句。

## 9. 局限

登记表是参照，不能自动判定语义。同名不同义靠两件事兜底：

- 边界 `stopifnot()` 断言列名、单位与量级。
- 类型后缀（§2）把含义写进名字。

别名按完整符号匹配。写在复合名里的别名（如 `PM25_MORT_lower` 中的 `PM25`）不报，靠命名审查。
