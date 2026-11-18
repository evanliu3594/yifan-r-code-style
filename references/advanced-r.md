# 高级技巧细则：数据结构、函数、条件、调试与性能

依据 Hadley Wickham, *Advanced R* 2e（2019，用到 Foundations、Vectors、Names-values、Subsetting、Control-flow、Functions、Function-operators、Function-factories、Functionals、FP、FP-whole-game、Conditions、Debugging、Perf-measure、Perf-improve、Expressions、Quotation、Environments、Evaluation、S3、R6、Connections 章）。
书是 2019 年版，冲突时以当前版本为准。

## 1. 数据结构与类型

1. R 没有标量，一切是长度 1 的向量，`1[1]` 合法。不要假设 `length(x) == 1`，要校验：`stopifnot(length(x) == 1)` 或 `rlang::is_scalar_double()`。
2. `c()` 的类型提升顺序：逻辑 → 整数 → 双精度 → 复数 → 字符。原子向量所有元素同一类型。
3. `NA` 是逻辑型，会随上下文提升。构造混合向量时用带类型的 `NA_integer_`、`NA_real_`、`NA_character_`，不要混用裸 `NA`。
4. 查类型：`typeof()` 看底层类型，`class()` 看 S3 派发，`str()` 看结构。
   禁止用 `is.vector()`、`is.atomic()`、`is.numeric()`、`mode()`、`storage.mode()`。`is.numeric(TRUE)` 是 FALSE。
5. 属性容易丢。绝大多数操作会剥掉属性，只有 `names` 与 `dim` 通常保留。其他元信息要靠 S3 类才守得住。
6. `dim` 是属性：`dim(z) <- c(3, 2)` 把向量变矩阵；普通向量的 `dim` 是 `NULL`。
7. 列表存引用，`list(x, x, x)` 只比 `x` 多几十字节。`NULL` 是缺失的向量，`NA` 是向量里缺失的元素。
8. 只有长度 1 的回收可信。书的建议是不要依赖其他长度的回收，基 R 各处实现不一致。
   基 R 对不整除的回收发警告。

## 2. 取值与子集

1. 取单个元素用 `[[`。`[` 返回子集，会带着原对象的类与属性，还可能降维。取列用 `[[` 或 `$`。
   `[[` 对列表支持递归下标（长度为 2 的整数向量等于两层取值），这个特性少有人知，禁止在脚本里用，改用 `purrr::pluck()`。
2. `坑`：`$` 会左侧部分匹配。打开 `options(warnPartialMatchDollar = TRUE)` 暴露它。tibble 的 `$` 不部分匹配，列名不存在会警告，这是本项目要求 tibble 的理由之一。
3. 函数内对二维对象取值必须写 `drop = FALSE`，否则单行或单列会降成向量，下游 `ncol()` 变成 `NULL`。
   基 R 默认不报警告。因子的 `drop` 是另一回事（控制水平），默认 `FALSE`。
4. 六种下标的行为要记住：
   - 正整数：可以重复，双精度会截断成整数。
   - 负整数：不能与正数混用。
   - 逻辑：下标里的 NA 会在结果里产出 NA。
   - 空下标：取全部，赋值时很有用。
   - 零长度下标：产出空结果。
   - 字符：永远精确匹配。
   `坑`：`x[NA]` 全是 NA（`NA` 是逻辑型被回收）；`x[NA_integer_]` 是越界；不能用因子做下标（会用它的底层整数）。
5. 三种子赋值的规则：
   - `x[i] <- value`：保证 `length(value)` 等于 `length(x[i])`，且 `i` 无重复。否则回收规则复杂到不可预测。
   - `x[[i]] <- NULL` 删除该元素（列表）。要存一个 NULL 就写 `x[i] <- list(NULL)`。
   - `x[] <- y` 替换内容但保留类与结构。`mtcars[] <- lapply(mtcars, as.integer)` 仍是数据框，直接赋值就不是。
6. `坑`：`x[which(y)]` 与 `x[y]` 等价，没有优化。`x[-which(y)]` 不等于 `x[!y]`：全不匹配时前者返回整个 `x`。反向选择一律写 `x[!y]`。`which()` 只在你要第一个或极少数 TRUE 的位置时用。
7. 常用写法：把下标变逻辑向量、用下标矩阵取散点、用 `match()` 做键对齐。

```r
unwhich <- function(i, n) {
  out <- rep_len(FALSE, n)
  out[i] <- TRUE
  out
}
cells <- A[cbind(row_idx, col_idx)]
A[cbind(row_idx, col_idx)] <- 0
```

8. 矩阵与数组按列优先存储，一维线性下标按这个顺序。二维转置用 `t()`，三维以上用 `aperm()`。
   对应关系：`names` → `rownames`/`colnames` → `dimnames`；`length` → `nrow`/`ncol` → `dim`；`c` → `rbind`/`cbind` → `abind::abind`。
9. 数据框一个下标像列表（选列），两个下标像矩阵（先行后列）。`df["x"]` 与 `df[, "x"]` 维度不同。删列写 `df$z <- NULL`。
10. 集合运算用 `intersect`、`union`、`setdiff`，它们分别等价于 `&`、`|`、`&!`。展开用 `rep(idx, counts)`。排序用 `order()` 取下标。
    自举重采样用 `sample(nrow(df), replace = TRUE)` 取行，并写 `drop = FALSE`。

## 3. 控制流

1. 循环下标用 `seq_along(x)` 或 `seq_len(n)`。禁止 `1:length(x)`：`x` 长度为 0 时它等于 `1:0`，循环会执行一次。`lintr::seq_linter()` 默认报。
2. `for` 会剥掉 S3 向量的属性，遍历时取 `xs[[i]]`。`for` 会覆盖同名的已存在变量。
3. 选最不灵活的工具：`for` 优于 `while` 优于 `repeat`；函数式写法优于手写循环。没有 do-while。
4. `if` 只接受长度 1 的逻辑值。给字符、空逻辑向量、NA、长度大于 1 都出错或报警。向量分支用 `if_else()`、`case_when()`。
   `if` 没有 `else` 时隐形返回 `NULL`；`y <- if (cond) 3` 在条件为假时 `y` 是 `NULL`。
5. `switch()` 取代嵌套 `if`。最后一个分支必须抛错，否则不匹配时隐形返回 `NULL`。只给字符型 `EXPR`；数值型有不良失败模式。支持 fall-through。
6. 短路只用于入口守卫：`!is.null(x) && length(x) == 1 && x > 0`。写成 `&` 版本会全部求值而报错。

## 4. 函数设计

1. 函数有三个成分：`formals()`、`body()`、`environment()`。基 R 原始函数（`sum`、`[`）的 `typeof` 是 `builtin` 或 `special`，三者为 `NULL`。
2. 词法作用域四条规则：名称遮蔽；函数与变量分道查找；每次调用新建环境（函数不记得上次）；运行时动态查找。
   查函数是否偷用全局：`codetools::findGlobals(f)`。把 `environment(f) <- emptyenv()` 能立刻暴露漏掉的依赖。
3. 参数惰性求值，只求值一次。要立刻固定或防止闭包捕获的变量漂移，就 `force(arg)`。
4. 位置参数只用于前 1 到 2 个。禁止依赖部分匹配：打开 `options(warnPartialMatchArgs = TRUE)`。
5. `...` 有两个代价：必须文档化它流向哪里；拼错的参数被静默忽略（`sum(1, NA, na_rm = TRUE)` 不报错）。传列表用 `rlang::list2()` 与 `!!!`。
6. 返回一个值或者抛错，不要返回哨兵值。纯副作用函数返回 `invisible()`。
7. 退出清理必须写 `on.exit(..., add = TRUE)`：还原 `par()`、`options()`，关闭连接，删除临时目录。临时状态首选 `withr::local_*()`。
8. 早返回优于深嵌套。非法输入先 `return()` 或 `cli::cli_abort()`，不要把主体包进四层 `if`。
9. 函数工厂：被生成函数用到的每个参数都要 `force()`，否则工厂外的变量变化会带进生成函数。大对象用完 `rm()`，因为生成函数会一直持有执行环境。
10. 跨调用保存状态优先用显式返回值或环境。`<<-` 少量使用；需要维护两三个以上变量时改用 R6。
11. 可选参数写 `x = NULL` 再用 `%||%` 判空，比 `missing()` 清楚。函数与变量不要用同名。匿名函数只写一行且不含 `{}`。

## 5. 条件系统

1. 三类信号各有用途：错误表示无法继续，警告表示可疑但已恢复，消息表示进度与说明。
   首选 `cli::cli_abort()`、`cli::cli_warn()`、`cli::cli_inform()`，它们默认不打印调用栈。基 R 的 `stop()`、`warning()` 必须加 `call. = FALSE`。
2. 报错文案写四项：哪一步、哪个对象、期望什么、能怎么办。断言用 `stopifnot()`，命名断言失败时会显示标签。
3. 自定义错误类别，不要按消息文本捕获（文本可翻译、会变）。

```r
if (!is.numeric(conc)) {
  cli::cli_abort(
    c(x = "{.arg conc} must be numeric.", i = "Got {.cls {class(conc)}} instead."),
    class = "r4ds_error_not_numeric",
    arg = "conc"
  )
}
```

4. `tryCatch()` 是退出式处理器，用于错误与中断，处理器的返回值就是结果。`withCallingHandlers()` 是调用式处理器，用于警告与消息，返回值被忽略，只做副作用，配合 `rlang::cnd_muffle()` 阻止继续上抛。
   `tryCatch(..., finally = )` 等价于作用范围更小的 `on.exit()`。
5. `坑`：匹配的是第一个符合类别的处理器，不是最具体的那个。最具体的类写在前。
6. 禁止吞异常。`try()` 的结果拿来当数据用，书里明确不推荐。`suppressWarnings()`、`suppressMessages()` 无法只抑制一类而放过其他类。
   批量任务用 `purrr::safely()`，先收齐再报告：

```r
safe_read <- purrr::safely(read_csv, quiet = TRUE)
res <- purrr::map(paths, safe_read)
ok <- purrr::map_lgl(res, ~ is.null(.$error))
msg <- purrr::map_chr(res[!ok], ~ .$error$message)
writeLines(paste0(paths[!ok], " : ", msg))
```

7. 警告要节制。只有弃用提醒和你确信能恢复的情况才发警告。基 R 滥发警告（`formals(1)`、删除不存在的文件、`as.numeric("50+")` 应该报错）。
   进度、耗时任务、非平凡默认值用 `message()`，并提供 `quiet = TRUE`。
8. `print()`、`cat()` 不作为日志。`message()` 是回答用户的询问，`cat()` 是开发者自己插话；本项目统一用 cli 的消息函数。
9. 非交互运行时设 `options(warn = 1)` 让警告即时可见。排查阶段设 `options(warn = 2)` 把警告升级为错误，这是定位警告来源最快的办法。

## 6. 迭代与函数式工具

1. 对应关系：`map()` 对应 `lapply()`；`map_dbl()` 对应 `vapply(FUN.VALUE = )`。
   禁止 `sapply()`：非交互环境里自动简化会静默改变返回类型。禁止 `apply()` 作用于数据框：会先强转矩阵。
   `Map()` 对所有参数向量化，无法传不随元素变化的参数；`mapply()` 是多重 `sapply()`，没有类型受控的多参数版本。多参数用 `map2()`、`pmap()`。
2. purrr 是 4 乘 4 的正交矩阵：`map`、`map2`、`imap`、`pmap` 各配 `_lgl`、`_int`、`_dbl`、`_chr`，另有 `modify` 系与 `walk` 系。
   成批写文件（对象加路径）用 `walk2()`。`modify()` 不是原地修改。
3. 多参数场景给 `pmap()` 传一张参数表，不要嵌套循环。

```r
params <- tribble(~scen, ~year, ~species,
                  "MRBRT", 2019, "PM2_5",
                  "SSP37", 2030, "PM2_5")
out <- purrr::pmap(params, \(scen, year, species) calc_burden(scen, year, species))
```

4. 传给 `map()` 的参数一律具名（`map(x, mean, trim = 0.1)`）。靠参数位置匹配传 `.x` 的写法书里明确不推荐。
5. 在函数里用 `reduce()` 必须给 `.init`：求和给 0，求积给 1，取最小给 `Inf`，取最大给 `-Inf`。想清楚长度 0 和 1 的输入再测。累加序列用 `accumulate()`。
6. 谓词用 `some()`、`every()`、`none()`（短路），`detect()`、`detect_index()`，`keep()`、`discard()`，`map_if()`、`modify_if()`。
7. 合并结果用 `list_rbind()`、`list_cbind()`、`list_flatten()` 或 `bind_rows()`。取元素用 `pluck()`（给 `.default`），要报错用 `chuck()`。
8. `purrr::invoke()` 在 1.2.2 已弃用，提示改用 `exec()`。调用存在变量或列表里的函数用 `rlang::exec()` 或 `do.call()`；动态参数名写 `!!name := value`。
9. 宁可多几个简单步骤，不要一个复杂步骤。没有现成 functional 匹配循环形状就保留 `for`。自己要写 functional 的前提是同一个模式已经重复两次。
   匿名函数跨行或含 `{}` 就应该改名。
10. 昂贵且纯的函数可以 `memoise::memoise()`。`坑`：给不纯的函数加 memoise 是真 bug 源（书中举了缓存 `available.packages()` 的例子）。跨脚本、跨会话的缓存走 step0 中间文件，不要用 memoise 替代。

## 7. 调试

1. 书里的调试策略是四步：
   1. 拿报错信息去搜，先去掉自己的变量名。
   2. 做成可重复的最小例子。用 `reprex::reprex()`，再逐步缩小，记下不失败的情形。修好后把它变成测试。
   3. 定位问题在哪。先用工具，再做假设驱动实验，然后带着小例子求助。
   4. 修复并测试。
   方法论：逐条确认你相信为真的前提，直到发现其中一条不真。
2. 工具顺序：`traceback()`（自下而上读，能给文件与行号）→ `options(error = rlang::entrace)` 或 `rlang::global_entrace()` → `rlang::last_trace()`、`rlang::trace_back()`。
   书里教的 `rlang::with_abort()` 在 rlang 1.2.0 已不存在，导出表里只有 `entrace`、`global_entrace`、`with_options`、`cnd_entrace`。
   进函数用 `browser()`（写在 `if` 里就是条件断点）或 `debugonce()`（比 `debug()` 好，退出时自动取消）。
   没有源码的函数用 `trace()`、`untrace()` 或 `utils::setBreakpoint()`。非交互崩溃用 `dump.frames(to.file = TRUE)` 加 `debugger()`。兜底是打印调试。
   `browser()` 里的命令：`n`、`s`、`f`、`c`、`Q`、`where`。
3. 写新函数时不该频繁用这些工具。交互里小块推进，代码块越小定位越快。
4. 交互能跑、`Rscript` 不能跑时逐项排查：全局环境内容、工作目录、`PATH`、`R_LIBS` 与 `R_LIBS_USER`、本地与全局 `options`。本项目最常见原因是工作目录不同与 `library()` 缺失（脚本假定 RStudio 已加载的包）。
5. 非错误型失败：意外警告用 `options(warn = 2)`（忽略 `.signalSimpleWarning` 一类栈帧）；意外消息用 `withCallingHandlers()`，在消息处理器里 `cli::cli_abort()` 转成可回溯的错误；一直不返回就中断后读 `traceback()`；进程直接崩是编译层问题。
6. 修完留守卫。能写测试就写测试（见 `package-dev.md` §7），否则至少留 `stopifnot()` 断言或一个校验脚本，并把发现存成诊断产物。

## 8. 性能：先测量，再优化

1. 顺序不可颠倒。先用 `profvis::profvis()` 找瓶颈，再用 `bench::mark()` 比方案（需安装）。
   `system.time()` 精度低，只适合粗看长任务，而且要重复多次再除以次数。
2. 读 `bench` 结果看 `min` 与 `median`，不要比均值（分布右偏）。同时看 `itr/sec`、`mem_alloc`、`n_gc`。结果合法地不相等时加 `check = FALSE`。
3. 火焰图里 `<GC>` 占比高，说明短命对象太多。典型症状是循环里写 `x <- c(x, i)`。
   `profvis` 有三个限制：不采编译层；匿名函数无法归因，要起名；惰性求值会把调用记到错误位置，用 `force()` 修正。
4. 内存诊断：`lobstr::obj_size()`、`obj_addr()`、`ref()`（需安装）。替代方案：`tracemem()` 看复制、`gcinfo(TRUE)` 看回收、`memory.size()` 看总量。不要手动 `gc()` 来释放内存。
   `坑`：R 的引用计数只有 0、1、多三种，几乎每次函数调用都会加引用，所以“传进函数会不会复制”不能靠直觉，要 `tracemem()` 实测。
   ALTREP 让 `1:1e9` 与 `1:3` 实占同样内存。
5. 少做事比微优化有效：`rowSums()`、`colSums()`、`rowMeans()` 优于 `apply()`；`vapply()` 优于 `sapply()`；`any(x == 10)` 优于 `10 %in% x`；
   读取时只读需要的列与类型；`factor(levels = )` 先给水平；`cut(labels = FALSE)` 或 `findInterval()`；`unlist(x, use.names = FALSE)`；`interaction(drop = TRUE)`。
   `坑`：绕开 S3 派发（直接调 `mean.default()`、`.Internal(mean())`）被书里标为 risky 和 even riskier。`quickdf()` 快在它会造出非法数据框。
6. 向量化就是整体思考并调用 C 层实现：`x[is.na(x)] <- 0` 批量替换、下标矩阵取散点、`cumsum()`、`diff()`、矩阵代数交给 BLAS（`%*%`、`solve()`）。代价是规模变化时性能不可预测，必须重测。
7. 第二大忌是在循环里增长对象：`c()`、`append()`、`rbind()`、`cbind()`、`paste()`。字符串折叠用 `paste(collapse = )` 或 `str_flatten()`。
   热循环里优先用矩阵或列表而不是数据框：数据框每次列替换在内部会复制多次。
8. 优化流程按这个纪律做：
   1. 每个候选实现写成独立函数。
   2. 所有尝试（含失败的）记在一个 Rmd 里。
   3. 造一个耗时几秒的代表性案例。
   4. 用 `bench::mark()` 比较，并配单元测试确保行为没变。
   5. 设定目标时间，达到就停。不要为省几秒机时花几小时人力。
9. 并行与 C++ 是最后手段。并行前要有明确瓶颈证据、固定种子、可复现结果，交互调试阶段不要开并行。
   只有向量化解决不了、或发现自己在用奇怪技巧避复制时才写编译代码（`cpp11` 或 `Rcpp`）。

## 9. 程序化列引用

1. 只有函数必须把作者代码与用户代码拼在一起时才动引号。频繁处理“装着代码的字符串”说明流程错了：改用准引用生成表达式。禁止用 `paste()` 拼代码。
2. 词汇表（dplyr 1.2.1、rlang 1.2.0 支持）：传列用 `{{ col }}`；需要进一步操作才 `enquo()` 加 `!!`；`...` 用 `enquos()`；
   列表值用 tidy dots（`list2()`、`!!!`）；动态列名用 `all_of(var)` 或 `.data[[var]]`；外部变量用 `.env` 或 `!!var`；只允许名字的场合用 `ensym()`。
3. `坑`：涉及数据掩码时必须 `enquo()`，不能 `enexpr()`，后者会带错环境求值。
   数据掩码里的歧义本身是一类 bug：外部值与列同名时裸写法取到哪个不确定。`threshold` 这类外部值与同名列共存会静默错算。
   规则：作者写死的表达式对作者负责，用户传入的表达式对用户负责，函数内部一律 `{{ }}` 或显式 `.data[[ ]]`、`.env`。
4. 打印代码用 `expr_text()`、`expr_label()`。不要用 `deparse()`：长表达式返回多行字符向量，是真 bug 源。
   查 AST 用 `lobstr::ast()`（未装时用 `rlang::expr()` 加 `str()`）。AST 里调用是 1 基，函数在 `[[1]]`，参数从 `[[2]]` 起；取参数前先 `rlang::call_standardise()`。
   递归模板是「符号与常数终止，调用与配对列表递归」。
5. 中间变量放局部环境：`local({...})`。不要用 `rm()` 收拾全局。`with()` 优于 `attach()`；`attach()` 只有一种正当用法（临时挂一组函数）。
6. 环境当状态用：引用语义（不复制）、名唯一无序、有父环境。`<<-` 在父环境重绑定，找不到就建在全局环境，通常不是你想要的。
   程序化操作用 `rlang::env_bind()`、`env_poke()`、`env_get(default = )`、`env_has()`、`env_unbind()`。`e$a <- NULL` 不会删除绑定，与列表不同。
   比较环境用 `identical()`。静态检查用 `codetools::checkUsage()`。

## 10. 面向对象最小集

1. 优先 S3。书里说 R6 更容易写出非惯用的 R 代码；在 R 里函数式编程比 OOP 更重要。
2. S3 配方：`structure(base_object, class = "my_class")`，类名只用字母与下划线、加包名前缀。配三个函数：构造器 `new_myclass()`（每个基对象与属性一个参数、`stopifnot()` 校验、便宜、不打扰用户）、
   可选的 `validate_myclass()`（放昂贵的检查）、面向用户的便捷构造 `myclass()`（末尾调构造器与校验器）。判类型用 `inherits()`。
3. 必须调用泛型，不要直接调方法（写 `print(x)`，不写 `print.myclass(x)`）。查派发用 `sloop::s3_dispatch()`（需另装）。
   `坑`：自定义 `str()` 方法会藏住内部结构；`unclass()` 会退回基类型行为。
4. R6 只在需要引用语义时用：建模独立于 R 存在的东西、外部 API、跨调用的可变状态。
   规则：复制用 `$clone(deep = TRUE)`；一个函数要么返回值要么改输入，不要两者都做；嵌套字段在 `$initialize()` 里分配（写在类级默认值会被所有实例共享）；`$finalize()` 只清私有资源。

## 11. 连接与文件

1. 打开连接后必须保证关闭：`on.exit(close(con))` 或 `tryCatch(finally = close(con))`。
2. 临时文件用 `tempfile()`、`tempdir()`，删除用 `unlink(recursive = TRUE)`。
3. 文本读写指定编码：`fileEncoding = "UTF-8"`。`encoding` 与 `fileEncoding` 语义不同，不要混用。本项目统一 UTF-8。
4. 二进制用 `readBin()`、`writeBin()`。路径操作用 `fs::path()`、`fs::dir_ls()`。

## 12. 科学计算专项

1. 多维数组：`dimnames` 是列名唯一来源。`sweep()` 按维度序号工作，`aperm()` 调轴顺序，`colSums()`、`rowSums()` 折叠前先确认维度顺序。
   `坑`：`prop.table(x, margin = )` 的 `margin` 是维度序号，轴顺序一变结果全错。改轴顺序必须同时更新断言。
2. 守恒与稳定性：双精度累加与顺序有关；比较用 `all.equal()` 或 `waldo::compare()`，不要用 `==`。守恒检查写成断言，偏差超阈值就 `stopifnot()` 失败。
3. 线性代数交给 BLAS：`solve(A, b)` 优于先求逆再乘。稀疏问题才上稀疏矩阵包。
4. 并行用 `furrr` 加 `future`，设 `future.seed = TRUE` 保证 `plan(multisession)` 下 `set.seed()` 仍可复现。
   并行前先确认瓶颈不是 I/O 或内存：栅格任务常见卡点是磁盘与 `terra` 的 tempdir。
5. 大对象传参一般不复制（copy-on-modify），但增量修改会反复复制。把逐格累加改成一次成表，或把状态放进环境、R6。

## 13. 交付自查

- [ ] 取值用 `[[` 或带 `drop = FALSE`。没有因子下标、没有 `x[-which()]`、没有 `1:length()`。
- [ ] 函数无隐藏全局依赖（`codetools::findGlobals()` 查过）。闭包工厂已 `force()` 参数。
- [ ] `on.exit(add = TRUE)` 或 `withr::local_*()` 还原所有全局状态。连接与临时目录在 `finally` 里清理。
- [ ] 错误走 `cli::cli_abort()` 且带自定义类别。没有把 `try()` 结果当数据用。没有无条件的 `suppress*()`。
- [ ] 遍历是 `map_*()` 且返回类型显式。`reduce()` 给了 `.init`。没有 `sapply()`、没有 `apply(df, ...)`。
- [ ] 性能结论有 `profvis` 或 `bench::mark()` 证据。循环没有增长式赋值。随机与并行结果可复现。
- [ ] 程序化列引用统一 `{{ }}`、`.data[[ ]]`。没有拼字符串造代码。
