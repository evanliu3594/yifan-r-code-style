# ---------- 口径登记表：读取、检查、扫候选 ----------
# 用法：在项目根依次调用 read_variables()、check_variables()、
# variables_suggest()。细则见 yifan-r-code-style 的 references/naming.md。

# ---------- 读取 ----------

# 找登记表：先看 R/，再看项目根
variables_path <- function(dir = "R") {
  candidates <- c(file.path(dir, "_variables.json"), "_variables.json")
  hit <- candidates[file.exists(candidates)]
  if (length(hit) == 0) {
    cli::cli_abort(
      "未找到口径登记表。预期 {.path {dir}/_variables.json} 或 {.path _variables.json}。"
    )
  }
  hit[[1]]
}

# 取对象的单个字符串字段
scalar_field <- function(entry, field, index) {
  value <- entry[[field]]
  if (!is.character(value) || length(value) != 1) {
    cli::cli_abort("登记表第 {index} 项的 {.field {field}} 必须是单个字符串。")
  }
  value
}

# 取 aliases 字段，规范成字符向量
alias_field <- function(entry, index) {
  aliases <- entry[["aliases"]]
  if (is.null(aliases)) {
    return(character())
  }
  if (!is.list(aliases)) {
    cli::cli_abort("登记表第 {index} 项的 {.field aliases} 必须是字符串数组。")
  }
  if (length(aliases) == 0) {
    return(character())
  }
  is_string <- vapply(
    aliases,
    function(alias) is.character(alias) && length(alias) == 1,
    logical(1)
  )
  if (!all(is_string)) {
    cli::cli_abort("登记表第 {index} 项的 {.field aliases} 必须是字符串数组。")
  }
  unlist(aliases, use.names = FALSE)
}

# 读表，检查必需字段
read_variables <- function(dir = "R") {
  path <- variables_path(dir)
  raw <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(error) {
      cli::cli_abort("登记表不是合法 JSON：{.path {path}}。")
    }
  )
  if (!is.list(raw) || length(raw) == 0) {
    cli::cli_abort("登记表为空：{.path {path}}。")
  }
  required <- c("name", "concept", "meaning", "unit", "type_shape")
  variables <- lapply(seq_along(raw), function(index) {
    entry <- raw[[index]]
    if (!is.list(entry)) {
      cli::cli_abort("登记表第 {index} 项不是对象。")
    }
    missing <- setdiff(required, names(entry))
    if (length(missing) > 0) {
      cli::cli_abort("登记表第 {index} 项缺字段：{.val {missing}}。")
    }
    where <- entry[["where"]]
    if (is.null(where)) {
      where <- ""
    } else if (!is.character(where) || length(where) != 1) {
      cli::cli_abort("登记表第 {index} 项的 {.field where} 必须是单个字符串。")
    }
    tibble::tibble(
      name = scalar_field(entry, "name", index),
      concept = scalar_field(entry, "concept", index),
      meaning = scalar_field(entry, "meaning", index),
      unit = scalar_field(entry, "unit", index),
      type_shape = scalar_field(entry, "type_shape", index),
      aliases = list(alias_field(entry, index)),
      where = where
    )
  })
  dplyr::bind_rows(variables)
}

# ---------- 检查 ----------

# 一行一条问题
issue <- function(severity, where, message) {
  if (length(where) == 0) {
    return(tibble::tibble(
      severity = character(),
      where = character(),
      message = character()
    ))
  }
  tibble::tibble(severity = severity, where = where, message = message)
}

# 展开 aliases，一行一个别名
alias_table <- function(variables) {
  rows <- lapply(seq_len(nrow(variables)), function(index) {
    aliases <- variables$aliases[[index]]
    if (length(aliases) == 0) {
      return(NULL)
    }
    tibble::tibble(
      concept = rep(variables$concept[index], length(aliases)),
      name = rep(variables$name[index], length(aliases)),
      alias = aliases
    )
  })
  aliases <- dplyr::bind_rows(rows)
  if (nrow(aliases) == 0) {
    return(tibble::tibble(
      concept = character(),
      name = character(),
      alias = character()
    ))
  }
  aliases
}

# 表自身质量
check_table <- function(variables) {
  problems <- list()

  duplicate_concept <- unique(variables$concept[duplicated(variables$concept)])
  problems <- c(problems, list(issue(
    "error",
    duplicate_concept,
    paste0("concept 重复：", duplicate_concept)
  )))

  duplicate_name <- unique(variables$name[duplicated(variables$name)])
  problems <- c(problems, list(issue(
    "error",
    duplicate_name,
    paste0("name 重复：", duplicate_name)
  )))

  empty_meaning <- variables$name[!nzchar(variables$meaning)]
  problems <- c(problems, list(issue(
    "error",
    empty_meaning,
    paste0("meaning 为空：", empty_meaning)
  )))

  empty_unit <- variables$name[!nzchar(variables$unit)]
  problems <- c(problems, list(issue(
    "error",
    empty_unit,
    paste0("unit 为空：", empty_unit)
  )))

  aliases <- alias_table(variables)
  duplicate_alias <- unique(aliases$alias[duplicated(aliases$alias)])
  problems <- c(problems, list(issue(
    "error",
    duplicate_alias,
    paste0("别名指向多个概念：", duplicate_alias)
  )))

  dplyr::bind_rows(problems)
}

# 项目脚本清单：登记表自身不参与扫描
script_files <- function(dir = "R") {
  files <- list.files(dir, pattern = "\\.[Rr]$", full.names = TRUE)
  files[basename(files) != "_variables.R"]
}

# 取 R/ 下所有脚本的符号与字符串常量
scan_tokens <- function(dir = "R") {
  files <- script_files(dir)
  rows <- list()
  skipped <- character()

  for (file in files) {
    parsed <- tryCatch(
      parse(file, keep.source = TRUE, encoding = "UTF-8"),
      error = function(error) NULL
    )
    if (is.null(parsed)) {
      skipped <- c(skipped, basename(file))
      next
    }
    parse_data <- getParseData(parsed)
    if (is.null(parse_data) || nrow(parse_data) == 0) next
    keep <- parse_data$token %in% c(
      "SYMBOL", "SYMBOL_FUNCTION_CALL", "SYMBOL_FORMALS", "STR_CONST"
    )
    if (!any(keep)) next
    rows[[length(rows) + 1L]] <- tibble::tibble(
      file = basename(file),
      line = parse_data$line1[keep],
      text = parse_data$text[keep]
    )
  }

  if (length(rows) == 0) {
    return(list(
      tokens = tibble::tibble(
        file = character(), line = integer(), text = character()
      ),
      skipped = skipped
    ))
  }
  list(tokens = dplyr::bind_rows(rows), skipped = skipped)
}

# 别名命中
check_aliases <- function(variables, tokens) {
  aliases <- alias_table(variables)
  hits <- dplyr::inner_join(
    tokens,
    aliases,
    by = c("text" = "alias"),
    multiple = "all"
  )
  if (nrow(hits) == 0) {
    return(issue("error", character(), character()))
  }
  issue(
    "error",
    paste0(hits$file, ":", hits$line),
    paste0("别名 ", hits$text, " 应改为 ", hits$name, "（", hits$concept, "）")
  )
}

# 登记名未出现且无别名
check_stale <- function(variables, tokens) {
  used <- unique(tokens$text)
  stale <- variables$name[
    !variables$name %in% used & lengths(variables$aliases) == 0
  ]
  if (length(stale) == 0) {
    return(issue("info", character(), character()))
  }
  issue(
    "info",
    paste(stale, collapse = ", "),
    paste0(length(stale), " 个登记名未使用，可能已废弃。")
  )
}

# 主检查：表质量 + 别名命中 + 废弃提示
check_variables <- function(dir = "R", strict = TRUE) {
  variables <- read_variables(dir)
  scan <- scan_tokens(dir)
  issues <- dplyr::bind_rows(
    check_table(variables),
    check_aliases(variables, scan$tokens),
    check_stale(variables, scan$tokens)
  )

  if (length(scan$skipped) > 0) {
    cli::cli_warn("解析失败，已跳过：{paste(scan$skipped, collapse = ', ')}。")
  }

  errors <- issues[issues$severity == "error", ]
  hints <- issues[issues$severity == "info", ]

  if (nrow(errors) == 0) {
    cli::cli_inform("登记表检查通过：{nrow(variables)} 个概念，别名命中 0 处。")
  } else {
    cli::cli_inform("登记表检查发现 {nrow(errors)} 个 error。")
    print(errors, n = Inf)
  }
  if (nrow(hints) > 0) {
    cli::cli_inform("提示：{hints$message}")
  }

  if (strict && nrow(errors) > 0) {
    cli::cli_abort("登记表检查未通过：{nrow(errors)} 个 error。")
  }

  invisible(issues)
}

# ---------- 扫候选名 ----------

# 取赋值目标名
scan_assignments <- function(dir = "R") {
  files <- script_files(dir)
  rows <- list()

  for (file in files) {
    parse_data <- tryCatch(
      getParseData(parse(file, keep.source = TRUE, encoding = "UTF-8")),
      error = function(error) NULL
    )
    if (is.null(parse_data) || nrow(parse_data) == 0) next

    assign_tokens <- c("LEFT_ASSIGN", "EQ_ASSIGN", "ASSIGN")
    assigns <- parse_data[parse_data$token %in% assign_tokens, ]
    for (i in seq_len(nrow(assigns))) {
      children <- parse_data[parse_data$parent == assigns$parent[i], ]
      is_lhs <- children$token == "expr" & children$col1 < assigns$col1[i]
      lhs <- children[is_lhs, ]
      if (nrow(lhs) == 0) next
      name <- parse_data$text[
        parse_data$parent == lhs$id[nrow(lhs)] &
          parse_data$token %in% c("SYMBOL", "STR_CONST")
      ]
      if (length(name) == 0) next
      rows[[length(rows) + 1L]] <- tibble::tibble(
        name = name[[1]],
        file = basename(file),
        line = assigns$line1[i]
      )
    }
  }

  if (length(rows) == 0) {
    return(tibble::tibble(
      name = character(), file = character(), line = integer()
    ))
  }
  dplyr::bind_rows(rows)
}

# 扫出未登记的赋值名，首次建表用
variables_suggest <- function(dir = "R", variables = read_variables(dir)) {
  known <- c(variables$name, alias_table(variables)$alias)
  assigned <- scan_assignments(dir)
  assigned <- assigned[!assigned$name %in% known, ]
  counts <- sort(table(assigned$name), decreasing = TRUE)
  tibble::tibble(
    name = as.character(names(counts)),
    n = as.integer(counts)
  )[, c("n", "name")]
}
