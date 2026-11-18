# R 包标准细则：结构、文档、测试、发布

依据 Hadley Wickham 与 Jenny Bryan, *R Packages* 2e（2023，用到 structure、code、description、dependencies、workflow101、whole-game、package-within、man、testing-basics、testing-design、testing-advanced、data、vignettes、other-markdown、misc、software-development-practices、lifecycle、release、website、R-CMD-check 章）。
书中标注的旧版本号与工具现状见 §13。

## 1. 什么时候抽成包

1. 判据是复现频次，不是代码量。同一批操作跨多个项目重复时才抽包。脚本、报告、Shiny 应用继续以脚本形式存在。
2. 升级路径：复制粘贴 → 抽成函数 → 函数进一个 helper 文件加查找表 → 包。到了需要单独 helper 文件这一步就该建包。
3. 转包时的四个常错点：
   - 依赖改用 `DESCRIPTION` 声明。禁止 `library(tidyverse)`。
   - 数据走 `data/`、`inst/extdata/` 或 `R/sysdata.rda`。禁止在包顶层放一个 CSV 加相对路径去读。
   - 导出必须显式 `@export`。挂载包不会像 `source()` 那样把函数倒进全局环境。
   - 区分构建期与运行期。顶层不能有副作用。
4. 个人杂项包（本项目的 `LYFtools`）可以不上 CRAN，但仍要 `devtools::check()` 干净。对外发布的包只解决一类相关问题。

## 2. 包目录树与文件规则

```text
pkgname/                          # 包根 = git 仓库根 = RStudio Project
├── DESCRIPTION                   # 元数据与依赖
├── NAMESPACE                     # roxygen2 生成，禁止手改
├── LICENSE / LICENSE.md          # 由 usethis 许可助手写入
├── R/                            # 只有 .R 文件，禁止子目录
├── man/                          # .Rd，roxygen2 生成，禁止手改
├── tests/testthat.R              # usethis 生成，禁止手改
├── tests/testthat/test-<主题>.R  # 与 R/ 文件同名对应
├── vignettes/                    # 长文档
├── data/                         # 面向用户的数据集，一文件一对象
├── data-raw/                     # 数据集生成脚本（入库但不进包）
├── inst/extdata/                 # 随包分发的样例文件
├── R/sysdata.rda                 # 内部数据
├── NEWS.md                       # 用户可见变更
├── README.Rmd → README.md        # 只编辑 Rmd
├── _pkgdown.yml / docs/          # 站点配置与本地预览
└── .Rbuildignore / .gitignore
```

1. 必需三件：`DESCRIPTION`、`NAMESPACE`、`R/`。用 `usethis::create_package()` 建骨架。禁止 `package.skeleton()`。
2. `R/` 里只放函数定义。书里的判据是：函数之外的任何 R 代码都可疑，需要仔细复核。合法例外只有两个：内部状态环境
   （`the <- new.env(parent = emptyenv())`，常放 `R/aaa.R` 保证先定义）与 `R/sysdata.rda`。
3. `R/` 禁止子目录。相关函数用共同前缀分组，例如 `clean-*.R`。
4. 文件命名要说明里面有哪几个函数。一个文件放一个主函数加它的 helper、或一个函数家族、或（少见）一个又大又难解释的函数。
   不要把所有代码塞一个文件，也不要长期一函数一文件。小的内部 helper 放 `R/utils.R`，不导出。
5. 永不手改：`NAMESPACE`、`man/*.Rd`、`tests/testthat.R`、`inst/doc/`、`docs/`、`README.md`、`.Rproj`。`NAMESPACE` 与 `man/` 要提交。
6. `.Rbuildignore` 的内容是锚定的 PCRE 正则，匹配源码路径。写 `^data-raw$`，不要写 `data-raw`：不锚定会连 `R/data-raw.R` 一起排除。
   文件里禁止 `#` 注释。用 `usethis::use_build_ignore()` 添加，多数 usethis 助手会自动加。
7. `R CMD check` 的硬限制：整包小于 5 MB，单个子目录小于 1 MB；不得有可执行文件、隐藏文件、空目录；除 `R/` 外子目录名小写；文件名只用字母、数字、下划线、连字符。

## 3. 包内代码规则

1. 禁止出现：`library()`、`require()`（`@examples` 除外）、`source()`、`attach()`、不带 `envir` 的 `data()`、
   向全局环境 `assign()` 或 `<<-`、`.Internal()`、`:::`、已弃用或已移除的函数、`T`、`F`。
2. 调用其他包一律写 `pkg::fun()`。
   `坑`：写 `foo <- pkgB::blah` 这种别名会把依赖的代码冻结在构建期。要写 `foo <- function(...) pkgB::blah(...)`。
3. 不要在顶层计算随时间或环境变化的值。`system.file()` 路径、`Sys.time()`、locale 与颜色能力探测都放进函数里，在调用时算。
4. 要改全局状态就必须还原，并且范围尽量小：`options()`、`par()`、`setwd()`、`Sys.setenv()`、`Sys.setlocale()`、`set.seed()`
   一律用 `withr::local_*()` 或 `withr::with_*()` 包起来。临时改随机数用 `withr::with_preserve_seed()`。
5. 包自己的选项名以包名开头，并且不要覆盖用户已设的值。
6. 绘图与打印隔离在只负责输出的函数里。
7. `R/zzz.R`：一般只用 `.onLoad()`。要发启动消息才用 `.onAttach()`，消息用 `packageStartupMessage()`，不要用 `message()`。
   配套加 `.onUnload()`。`.First.lib()`、`.Last.lib()` 已过时。
8. 要上 CRAN 时 `.R` 文件必须是 ASCII。非 ASCII 字符写成 `\uXXXX`：用 `stringi::stri_escape_unicode()` 转，用 `tools::showNonASCIIfile()` 查。
9. 开发循环按顺序做，一天多次：改 `R/` → `document()`（改了文档或导出才需要）→ `load_all()` → 跑示例 → `test()` → `check()`。

## 4. DESCRIPTION

1. DCF 格式：`Field: value`，续行缩进 4 空格，每行不超过 80 字符。
2. `Package`：字母开头，只用字母、数字和点，不以点结尾。禁止 `-` 和 `_`，尽量不用点。查重用 `pak::pkg_name_check()`。
3. `Version` 用 `major.minor.patch` 三段，写 `1.0.0`，不写 `1.0`，分隔符只能是点。
   开发版加第四段，从 9000 起；新包从 `0.0.0.9000` 开始。
   patch 只修 bug；minor 加向后兼容的新功能（最常用）；major 破坏兼容（`1.0.0` 表示 API 稳定）。
   只有需要别人能检测到某个功能时才递增第四段。版本递增一律用 `usethis::use_version()` 或 `use_dev_version()`，它们会同步改 `NEWS.md` 标题。
4. `Title`：一行、title case、结尾无句号、纯文本、实际在 65 字符内被截断。不能含包名，也不能出现 package 这个词。被引用的软件与 API 名加单引号。少用缩写。
5. `Description`：一段话，说明这个包做什么、给谁用。不要以 “A package for” 或 “This package” 开头，不要写包名，缩写要展开。它不能代替 README。
6. `Authors@R` 用 `person(given, family, email, role, comment)`。至少一个 `aut` 和一个 `cre`。
   `cre` 的邮箱必须是长期有效、不被严格过滤的个人邮箱：这是 CRAN 唯一的联系渠道，退信可能导致下架。
   角色含义：`cre` 维护者、`aut` 实质贡献、`ctb` 小贡献、`cph` 版权持有人（受雇完成的必须有）、`fnd` 资助方，另有 `dtc`、`rev`、`ths`、`trl`、`com`、`ctr`。
   多人用 `c(...)`。ORCID 写 `comment = c(ORCID = ...)`。`citation()` 只列 `aut`。写了 `Authors@R` 就不要再手写 `Author:` 与 `Maintainer:`，同时写是错误。
7. `License` 是机器可读字段。可选写法：`MIT + file LICENSE`（需要一个只含年份与版权人的 `LICENSE` 文件）、`GPL (>= 2)`、`GPL-2`、`LGPL-2.1`、`Artistic-2.0`、`Apache License (== 2.0)`，非标准文本用 `file LICENSE`。
   用助手生成：`use_mit_license()`、`use_gpl_license()`（默认 `>= 2`，避开 v2 与 v3 不兼容）、`use_lgpl_license()`、`use_apache_license()`、`use_agpl_license()`。
   数据包用 `use_cc0_license()` 或 `use_ccby_license()`。内部包用 `use_proprietary_license()`，它不能上 CRAN。
   助手把完整许可文本写进 `LICENSE.md` 并自动 `.Rbuildignore`：CRAN 禁止随包分发标准许可全文。随包嵌入他人代码时要写 `LICENSE.note` 并给 `cph` 角色。
8. `URL` 先站点后仓库，逗号分隔；`BugReports` 指 issue 页。用 `usethis::use_github_links()` 写。要让站点的自动链接生效，站点 URL 必须同时出现在 `DESCRIPTION::URL` 与 `_pkgdown.yml::url`。
9. `Encoding: UTF-8` 是唯一值得写的取值。用 roxygen2 时写 `Roxygen: list(markdown = TRUE)`；新包必开，旧包用 `use_roxygen_md()` 加 `roxygen2md` 迁移。
10. 自定义字段必须加前缀 `Config/`，例如 `Config/testthat/edition: 3`、`Config/Needs/website`。不要手工维护 `Date`。
11. 依赖字段：`Imports` 运行必需（只保证安装时被装上，不会让函数变得可调用）；`Suggests` 只用于测试、示例、vignette 和可选路径；
    `Depends` 会连带挂载，几乎总是错，唯一正当用法是 `Depends: R (>= 4.0.0)`，而且它会传导到你所有下游包；`LinkingTo` 只用于编译期头文件；`Enhances` 不推荐。
    版本约束只写 `pkg (>= x)`，禁止 `==`。只有用到新特性或确实踩过版本问题才设下限。
12. 提供 `data/` 里的 `.rda` 时，`usethis::use_data()` 会自动写 `LazyData: true`。它的现行态度见 §13。

## 5. 依赖

1. 加依赖只走 `usethis::use_package("dplyr")`（默认进 `Imports`，按字母序，可给 `min_version`）。GitHub 版本用 `use_dev_package()`，它会写 `Remotes:`。带 `Remotes:` 的中间状态不能提交给 CRAN。
2. 包代码里默认写 `pkg::fun()`。只有三类情况才 `@importFrom`：运算符（`%||%`、`%>%` 用 `::` 取不到）、用得极多的函数（可读性与消息换行）、紧密循环（`::` 约 100 纳秒开销）。
   `@import pkg` 是书里最不建议的方案，只在把某包当准基座时极少数使用。
3. `@importFrom` 集中在包级文档文件 `R/{pkgname}-package.R`（`usethis::use_package_doc()` 生成，内含 usethis namespace 起止标记），用 `usethis::use_import_from("glue", "glue_collapse")` 维护。分散在每个函数上方会在包长大后失控。
4. `NAMESPACE` 不能引用没在 `Imports` 或 `Depends` 里的包。`Depends` 的包也必须被 import 或用 `::` 使用，否则仅加载就会坏。依赖环非法。
5. 可选依赖在代码里用 `rlang::is_installed()` 判断，或用 `rlang::check_installed()` 提示安装。测试和 vignette 里可以直接用 `Suggests` 的包；难装的才用 `testthat::skip_if_not_installed(pkg, minimum_version = )`。
6. `Imports` 里有未使用的包会被 `R CMD check` 报 NOTE。解法是在一个永不调用的 helper 里留一个 `pkg::fun` 引用，这比 `@importFrom` 好，后者会强制提前加载。
7. 不要追求零依赖。评估这几项：包的类型（base 与 recommended 几乎免费）、递归依赖数、与已装包的重叠、编译时间与体积、你的维护带宽、是否关键路径。
   分析工具：`pak::pkg_deps_tree()`、`pak::pkg_deps_explain()`、`tools::package_dependencies()`。
   CRAN 对非默认 `Imports` 达到 20 个会发 NOTE（阈值随 R 版本可能变）。tidyverse 系包绝不能写 `Imports: tidyverse` 或 `Imports: devtools`。rlang、cli、glue、withr、lifecycle 视为几乎免费。
8. 导出策略：宁可少导出。导出即承诺有文档且接口稳定。内部 helper 不导出不文档，注释用 `@noRd`。要低调暴露的开发用工具函数写 `@export` 加 `@keywords internal`。
9. 泛型不属于你时用 `@exportS3Method dplyr::count`；基 R 泛型的方法直接 `@export`。重导别人的函数：在 `pkg::fun` 上方写 `#' @export` 与 `#' @importFrom pkg fun`，会生成 `man/reexports.Rd`。

## 6. roxygen2 与文档

1. 流程：对象上方写 `#'` 块 → `devtools::document()`（同时生成 `man/*.Rd` 与 `NAMESPACE`）→ `load_all()` 后用 `?fun` 预览。一个块对应一个主题。
2. 每个导出函数必须有：标题、描述、每个参数的 `@param`、`@returns`、`@examples`、`@export`。
   首次上 CRAN 时 `@returns` 和至少一个可直接运行（不套 `\dontrun`）的例子是硬性要求。
   `R CMD check` 会警告：未文档化的导出对象与数据集、缺参数文档、文档里有但签名里没有的参数。
3. 块结构：第一句是标题，首行大写、无句号、后跟空行。下一段是描述。再多内容用 `@details`，它渲染在 usage、args、value 之后。
   多段描述要显式写 `@description`。分节用 markdown 标题。源码里标签顺序不影响输出。
4. `@returns` 优先于别名 `@return`。要写输出的形状、类型、维度和重要警示，不要只写“一个数据框”。
5. `@param` 写接受哪些值与默认行为。成对参数可以合写。复用别人的参数文档用 `@inheritParams`。
   `坑`：跨包继承让文档不再自包含，别人改版会给你制造无谓 diff。`...` 的参数文档用 `@inheritDotParams`。
6. 合并主题用 `@rdname`。归类用 `@family`、`@concept`。交叉引用写 `@seealso`，链接用 `[pkg::fun()]`。
7. markdown 规则：反引号包代码；`[somefunction()]`（带方括号且带括号）会自动成链接；引用 vignette 用 `vignette("topic")`，跨包时补 `package =`；用项目符号拆长段。
8. `@examples` 是教学，不是测试。要求：真实、自包含、短、不报错、不改变外部环境。
   具体限制：例子里 withr 和 `on.exit()` 不生效，要手工还原 options；只写 `tempdir()` 里的文件；不改工作目录；不碰剪贴板；不打真实网络；所有例子合计少于 10 分钟。
   可能失败的例子优先用 `try()`，不要用 `\dontrun{}`；`\donttest{}` 已不推荐（CRAN 现在照跑）。条件执行用 `@examplesIf predicate()`。
9. 内部对象不写文档，给开发者看的注释用 `@noRd`。包级主题文件（`R/{pkgname}-package.R`）用 `#' @keywords internal` 加 `"_PACKAGE"`，它也是 `@importFrom` 的家。
10. 数据集文档写在 `R/data.R`：引用对象名，给 `@format`（数据框要逐列写 `\describe{}`，含单位）和 `@source`（URL 与出处）。禁止 `@export` 数据集。内部数据不需要文档。
11. Rd 每行小于 90 字符：roxygen 注释按 80 折行。`devtools::check_man()` 只跑文档相关检查，并且会先 document。

## 7. 测试（testthat 3e）

1. 一次性建立：`usethis::use_testthat(3)` 会写 `Suggests: testthat (>= 3.0.0)` 与 `Config/testthat/edition: 3`，并建 `tests/testthat/` 与 `tests/testthat.R`。`tests/testthat.R` 不手改。
2. 布局镜像 `R/`：`R/clean-emis.R` 对应 `tests/testthat/test-clean-emis.R`。测试文件必须是 `tests/testthat/` 的直接子文件且以 `test` 开头（`helper*`、`setup*`、`_snaps/` 同理）。
   `context()` 已弃用：文件名就是上下文。测试文件里禁止 `library()` 和 `source()`。
3. 一个 `test_that()` 测一个行为，描述读起来像期望结果。测试要小，测外部接口。发现 bug 先写成失败测试再修。测试里的重复是好事：测试要一眼看懂，不追求 DRY。
4. 断言选择：数值用 `expect_equal()`（带 tolerance，比 `expect_identical()` 更适合 CRAN 的数值噪声）；字符匹配用 `expect_match()`；
   类型用 `expect_s3_class()`、`expect_type()`；长度用 `expect_length()`；集合用 `expect_setequal()`；不报错用 `expect_no_error()`。
   错误断言按 class 断，不要按消息正则断。不测你不拥有的条件。
5. 快照测试是 3e 处理输出与图形的办法：`expect_snapshot(expr)`，捕获错误加 `error = TRUE`，默认 `cran = FALSE`（CRAN 上跳过），
   用 `transform` 洗掉临时路径与随机量，`variant` 按 OS 或 R 版本分快照（尽量避免，快照会变多）。
   快照落在 `tests/testthat/_snaps/<文件>.md`，要提交，只在非交互下生效。审阅用 `testthat::snapshot_review("file")`，接受用 `snapshot_accept("file")`。
6. 测试要封闭：`test-*.R` 里几乎只有 `test_that()` 调用。文件级对象、穿插的 skip、散落的 setup 是反面模式。
   状态与临时文件用 `withr::local_*()`、`withr::defer()`；只在会话临时目录写文件（`withr::local_tempfile()`、`local_tempdir()`）。
   3e 已自动应用 `local_reproducible_output()`（宽度、无颜色、`LC_COLLATE = "C"`）。在 `LC_*` 设置失败的环境下尤其重要。
7. 夹具放 `tests/testthat/`（例如 `fixtures/`），用 `test_path("fixtures", "x.rds")` 读；生成夹具的脚本与夹具放在一起。
   helper 放 `tests/testthat/helper.R`，或放 `R/test-helpers.R`（vignette 也能用）。不可逆的全局设置放 `setup.R`，并在 `teardown_env()` 上挂 `defer`。
   `坑`：`load_all()` 不跑 `setup.R`。交互通过而 check 失败常因此而起。
8. skip 家族：`skip_if_not_installed()`、`skip_if()`、`skip_if_not()`、`skip_if_offline()`、`skip_on_os()`、`skip_on_cran()`（依赖 `NOT_CRAN`，推荐的 Actions 会设成 true）。
   `坑`：skip 在 CI 里不显眼，要定期翻 check 日志确认跳过数量。
9. 不测这些：你有信心的简单代码；不要为覆盖率凑数（`covr::package_coverage()`、`usethis::use_coverage()`），力气花在脆弱与取巧处。
   CRAN 上不测时序、并行、精度敏感行为。不要留不稳定测试，它会阻塞别人的发布。全套目标小于 1 分钟，超了就 `skip_on_cran()`。
10. mock 尽量避免。需要时用 testthat 的 `local_mocked_bindings()`、`with_mocked_bindings()`。涉及密钥就设计成大部分代码不认证也能测，凭据存储交给 `keyring`、`gitcreds` 与 `tools::R_user_dir()`。
11. `R CMD check` 通过 `tests/testthat.R` 跑测试。要看细节读 `pkg.Rcheck/tests/testthat.Rout`。交互通过而 check 失败，说明测试对环境做了错误假设。

## 8. 数据与随包文件

1. 按受众路由：面向用户的 R 对象 → `data/*.rda`（一文件一对象，文件名等于对象名）；只给开发者用的对象 → 单个 `R/sysdata.rda`（`use_data(internal = TRUE)`）；
   非 R 的原始文件 → `inst/extdata/`；会话状态 → 内部环境；跨会话配置与缓存 → `tools::R_user_dir()`，禁止直接写家目录。
2. 保留数据来源：导入与清洗脚本、最后的 `use_data()` 调用都放 `data-raw/`（`usethis::use_data_raw()` 创建并自动 `.Rbuildignore`）。工作流代码绝不留在 `R/` 下（书里点名 ggplot2 是反面教材）。内部数据与测试夹具同样处理。
3. `use_data()` 会写 `LazyData: true`。压缩默认 bzip2，体积大时试 gzip 与 xz，用 `tools::resaveRdaFiles("data/")` 自动选，并把决定记回 `data-raw/`（用 `tools::checkRdaFiles()` 核对）。bzip2 与 xz 数据要求 `Depends: R (>= 2.10)`，这是尽量少用它们的理由。
4. CRAN 上包数据一般小于 1 MB，超出要论证。数据大就单独建数据包（少更新）。不能重新分发的数据不要随包发。
5. 给使用者取样例文件的路径函数：仿 `readxl::readxl_example()`，包一层 `system.file(..., mustWork = TRUE)`；更严格用 `fs::path_package()`。

## 9. vignette、README、NEWS

1. 写 vignette 的时机：例子长到像文章、例子无法自包含、要展示多个函数协作、需要文字串起工作流。简单包写一个，命名 `{pkgname}.Rmd` 会自动成为 Get started 链接。
2. `usethis::use_vignette("name")` 建 `vignettes/`、写 `VignetteBuilder: knitr`、把 knitr 与 rmarkdown 加进 `Suggests`、把渲染产物加进 `.gitignore`。
   前言里 `title` 与 `\VignetteIndexEntry{}` 必须重复写（不会自动同步）。`output: rmarkdown::html_vignette`，并写 `\VignetteEncoding{UTF-8}`。engine 行不要改。`author`、`date` 一般省略。
3. 第一个 chunk 用 `knitr::opts_chunk$set(collapse = TRUE, comment = "#>")`，随后 `library(pkg)`。不要换成 `load_all()`：CRAN 跑的是安装版。
   vignette 用到的每个包都必须在 `Imports` 或 `Suggests`，check 会查未声明依赖。
4. 控制是否执行：`eval` 是 vignette 版的 `@examplesIf`，可以按 chunk 或整篇设。`error = TRUE` 用来正当展示失败；`include = FALSE` 藏 setup。
   完全不在 CRAN 执行代码的文档改用 `usethis::use_article()`（也用于展示与你不愿依赖的包的互操作，或图太多会超体积；缺点是本地安装里没有它）。
5. vignette 里的图由 chunk 生成时会自动内嵌，不用手工处理；要随包发的数据放 `inst/extdata/` 并用 `system.file()`；只给 vignette 用的输入与图形放 `vignettes/`，用相对路径和 `knitr::include_graphics()`。把 `inst/doc/` 当机器所有，不要预置内容。
6. README 面向新用户，回答三件事：为什么用、怎么用、怎么装。内容是一段目的、一个完整例子、可复制的安装代码、指向 vignette 的概览。
   写 `README.Rmd`，用 `devtools::build_readme()` 渲染（普通 knit 可能用旧的已安装版本），提交 `README.md`。设 `output: github_document`、`fig.path = "man/figures/README-"`。
   保留 badge 占位注释区，`use_cran_badge()`、`use_coverage()`、`use_github_action()` 会往里插。`use_readme_rmd()` 会装一个 pre-commit 钩子阻止提交过期的 `README.md`；钩子不进版本库，clone 后要重加。
7. `NEWS.md` 面向老用户，记录用户可见变更，不是 commit log。顶部写 `# pkg (development version)`。之后每次发布一个一级标题，新的在前。
   每条变更一个条目，临近发布才分小节。引用 issue 与贡献者写成 `(#10)`、`(#101, @hadley)`。`use_version()` 会帮你改标题。

## 10. 开发循环与包的位置

1. `document()` 干两件事：写 `man/*.Rd` 和重写 `NAMESPACE`。
   `坑`：顺序重要。增删改导出函数后必须先 `document()` 再 `load_all()` 或 `install()`，否则命名空间还列着旧导出，会报 “Objects listed as exports, but not present”。
   `check()` 会先帮你 document，并且先构建包体，同时设 `NOT_CRAN = true`。
2. `load_all()` 语义：以模拟安装版的命名空间加载源码包。导出与内部函数都直接可访问（不需要 `:::`）；`NAMESPACE` 里的 import 生效（不需要 `library()`）；
   `system.file()` 指到源码树；testthat 已挂载；`helper*.R` 会执行；开发版 `?fun` 可用。禁止在 `R/` 下手工 `source()`，禁止在 `.GlobalEnv` 里定义函数。
3. 只在需要真安装版时才 `install()`：跑 vignette（`library(pkg)` 渲染的是安装版）、发布、复现 check。不要用 `build_vignettes()`。
4. 工作目录保持在包根。不要用 `setwd()` 找路径。运行时用 `testthat::test_path()`、`fs::path_package()`、`system.file(mustWork = TRUE)` 或 rprojroot 构造路径。
5. 禁止把包嵌在另一个 RStudio Project、另一个包或另一个仓库里。`.Rproj`、包名、目录名三者一致。
   包作为脚本项目的子文件夹会让人与工具对抗：把包放独立目录，脚本项目通过安装版调用它。
6. 交互开发可以在 `.Rprofile` 里 `if (interactive())` 加载 devtools。包代码里禁止调 `devtools::x()`，要用函数的真实归属。查函数真实来源用 `sessioninfo::session_info()`。
7. 纯脚本项目可以破例用一个 `DESCRIPTION` 只声明依赖（书里也这么做）。锁死具体版本用 renv，不要靠 `DESCRIPTION`。

## 11. 生命周期与弃用

1. 阶段定义：stable（默认）、experimental（`major == 0` 期间即隐含）、superseded（保留但不再维护）、deprecated（准备移除）。
2. 弃用分阶段走 `lifecycle` 包。badge 写在 `@description`（函数）或 `@param`（参数），只有阶段与父对象不同才加。
   `lifecycle::deprecate_warn(when = "1.0.0", what = "old()", with = "new()")` 默认 8 小时提示一次；
   `deprecate_soft()` 只让直接调用者收到警告；废弃参数写 `arg = deprecated()`，并用 `lifecycle::is_present(arg)` 判断。移除放在后续 minor 或 major。
3. 传达变更：刻意递增版本，随手更新 `NEWS.md`，给下游依赖方至少两周通知并尽量附补丁。需要过渡期就用 `local_edition()` 这类开关。

## 12. 发布与检查

1. 标准是 0 error、0 warning、0 note。error 与 warning 必修；note 即使是误报也要清掉，无法避免的写进 `cran-comments.md` 解释。
   可以保留的信息型提示：新提交说明、数据里的 UTF-8、Rd 交叉引用未声明包。
2. 发布前用 `usethis::use_release_issue()` 生成清单，按顺序做：
   1. 选发布类型（patch、minor、major）。
   2. 查当前 CRAN 结果，推进到期的弃用。
   3. 打磨 `NEWS.md`。
   4. 跑 `urlchecker::url_check()`。
   5. 跑 `devtools::build_readme()`。
   6. 跑 `devtools::check(remote = TRUE, manual = TRUE)`。
   7. 跑 `devtools::check_win_devel()`。
   8. 跑 `devtools::check_mac_release()`。三个平台加 r-devel 都要过。
   9. 跑 `revdepcheck::revdep_check(num_workers = 4)`（`use_revdep()` 初始化，报告在 `revdep/`。revdepcheck 需安装，发布前装）。
   10. 更新 `cran-comments.md`。
   11. 跑 `usethis::use_version("minor")`。
   12. 跑 `devtools::submit_cran()`，点确认邮件。
   13. 接受后 `use_github_release()`、`use_dev_version(push = TRUE)`、发公告。
3. `cran-comments.md` 内容：`## R CMD check results` 加一行 `0 errors | 0 warnings | 0 notes`，逐条说明剩下的 note，`## revdepcheck results` 粘 `revdep/cran.md`。
   重提交加 `## Resubmission`。它进 git 但 `.Rbuildignore`。两次提交间隔至少一个月，重提交时递增 patch。
4. 首次发布额外做：`use_news_md()`、`use_cran_comments()`、通读 Title 与 Description、每个导出函数有 `@returns` 与可运行例子、`cph` 就位、核对随包文件许可。
5. 站点与 CI：`use_pkgdown()` 加 `pkgdown::build_site()`；`usethis::use_pkgdown_github_pages()` 一次配好 gh-pages、workflow 与 URL。
   参考索引默认字母序。函数一多就在 `_pkgdown.yml` 的 `reference:` 里按 title、subtitle、contents 分组（含 Superseded 组）。
   面向广泛用户时设 `development: {mode: auto}`，让开发版进 `/dev/`；在此之前用默认 release 模式。
   自动链接的前提：函数名写在反引号里且带括号、roxygen 里有 `[pkg::fun()]`、vignette 用 `vignette("topic")`、URL 同时写在 `DESCRIPTION` 与 `_pkgdown.yml`，并且已上 CRAN。
6. CI 至少两个 workflow：`use_github_action("check-standard")` 与 `use_github_action("test-coverage")`，再加 `pr-commands`（`/document`、`/style`）与 pkgdown 部署。
7. `R CMD check` 会抓、可以提前避免的点：Rd 行长、名称与 alias 唯一、`\usage` 与签名一致、S3 方法参数与泛型兼容（`...` 是例外）、替换函数参数名含 `value`、`R/` 里非 ASCII、被 ignore 的残留文件。
8. logo 放 `man/figures/logo.png`，用 `use_logo()`。badge 集中放在 README 的占位注释区：R-CMD-check、CRAN、覆盖率、lifecycle。

## 13. 与 2e 文本不同处

以下不是书的原文，是现状核对结果。引用工具名前先看这里。

1. `LazyData: true`：书里仍推荐随 `data/` 写入。现行《Writing R Extensions》对大数据集不鼓励，实践中常不写并要求 `data()` 或 `pkg::dataset`。小包示例数据可以留着，但不要当硬规则。
2. `rhub`：书里把 `rhub::check_for_cran()`、`rhub::check_with_sanitizers()` 当常规步骤。该服务已收缩。要求本身不变（三平台加 r-devel 都要过 check），工具换成 GitHub Actions、`devtools::check_mac_release()`、win-builder。
3. win-builder：`devtools::check_win_devel()` 仍是 CRAN 要的做法，但服务稳定性时好时坏，不要承诺出结果的时间。
4. `devtools::release()`：书里只提一次。日常路径是 `usethis::use_release_issue()` 加 `devtools::submit_cran()`。
5. mock：书里标为实验并列出 mockr、mockery。现在的稳定做法是 testthat 的 `local_mocked_bindings()`、`with_mocked_bindings()`；mockr 与 mockery 基本不再维护。
6. Quarto：本地文本只讲 `.Rmd`。pkgdown 与 usethis 现在接受 `.qmd` 作 article 与 vignette；`VignetteBuilder: knitr` 与 engine 行的要求不变。
7. 安装依赖：书里预测 pak 会成为推荐。现在 pak 已是常规选择（`pak::pkg_install()`、`pak::pkg_name_check()`）。`devtools::install_github()` 可用，它是 remotes 的再导出。
8. 书中出现的 `RoxygenNote: 7.2.1`、`r-lib/actions @v2`、`testthat (>= 3.0.0)`、体积阈值与依赖数阈值都是写作时的快照。引用前重新核对当前版本。

## 14. 包交付自查

- [ ] 跑过 `devtools::document()`。`NAMESPACE` 与 `man/` 无手工痕迹。包内没有 `library()`、`source()`、`setwd()`、顶层副作用、`T`、`F`。
- [ ] 每个导出函数有标题、描述、全量 `@param`、`@returns`、可运行 `@examples`。内部函数用 `@noRd` 且不导出。
- [ ] `DESCRIPTION` 的依赖与代码里 `::` 的实际使用一致。`Imports` 无未使用包。没有把必需依赖放进 `Suggests`。没有把包塞进 `Depends`。
- [ ] `devtools::test()` 全通过。测试自包含、不联网、只写临时目录。`test-*.R` 与 `R/` 一一对应。快照已审阅并提交。
- [ ] `devtools::check()` 达到 0 error、0 warning、0 note。无法消除的 note 已写进 `cran-comments.md`。
- [ ] `NEWS.md`、版本号、`README`（由 `README.Rmd` 渲染）同步。`inst/extdata/` 与 `data-raw/` 的来源脚本完整。
- [ ] CI（check-standard 与 test-coverage）为绿。发布前跑过 manual check、三平台 check 与 revdepcheck。
