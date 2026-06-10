# core internal/strconv vs strconv 路径冲突

[![CI: strconv path conflict](https://github.com/conglinyizhi/moonbit-bug-strconv-path/actions/workflows/ci.yml/badge.svg)](https://github.com/conglinyizhi/moonbit-bug-strconv-path/actions/workflows/ci.yml)

## 环境

MoonBit 0.1.20260608 (60bc8c3 2026-06-08) / moonc v0.10.0，Linux x86_64

## 问题现象

当项目中使用了 `@strconv.parse_int`（或依赖了 `mizchi/experimental_crypto` 这类涉及路径解析的第三方包）时，`moon build --target native` 会报 GCC 符号未定义错误：

```
/home/abc/.../parser.mbt: error: '_M0FPC28internal7strconv18parse__int_2einner' undeclared
  (did you mean '_M0FPC17strconv18parse__int_2einner'?)
```

## 怎么发现的

在发现 [moonbit-bug-core-bundle](https://github.com/conglinyizhi/moonbit-bug-core-bundle) 那个 bug 的基础上，发现带 `mizchi/experimental_crypto` 依赖时还会多出一套完全不同的错误——GCC 引用了 `_M0FPC28internal7strconv` 这个符号，但说找不到定义，建议用 `_M0FPC17strconv`。

一开始以为是 `mizchi/experimental_crypto` 包的问题，后来发现这是 core 库本身路径迁移不干净导致的。

## 根因

MoonBit v0.10 重构了 core 库的包路径，`strconv` 从 `moonbitlang/core/internal/strconv` 移到了 `moonbitlang/core/strconv`。

但在 `~/.moon/lib/core/` 目录中，新旧两个路径同时存在：

```
~/.moon/lib/core/strconv/            # 新路径（v0.10）
~/.moon/lib/core/internal/strconv/   # 旧路径（残留）
```

moonc 编译器把两者都编译进了 `main.c`，生成了两套不同的 C 符号名：
- 旧路径 → `_M0FPC28internal7strconv`（28 字符编码）
- 新路径 → `_M0FPC17strconv`（17 字符编码）

旧路径的符号在 `main.c` 中只有**引用**没有**定义**（GCC undeclared），因为实际函数体在新路径的那一份里。

## CI 结果

GitHub Actions 每次提交会自动运行以下指令，以验证问题是否仍然存在：

```yaml
- moon check --target native   # 应 ✅
- moon build --target native   # 应 ❌（CI 容忍失败）
```

详细 workflow 见 `.github/workflows/ci.yml`。

## 关联仓库

- [moonbit-bug-core-bundle](https://github.com/conglinyizhi/moonbit-bug-core-bundle) — 更基础的 bug，core 源码被重复编译到 `main.c` 导致 abort 函数 redefinition。本仓库的问题是在那个基础上多了一层符号名不匹配。如果 core bundle 的双重编译修好了，这个也会跟着消失。

## 项目结构

```
moon.mod              # 依赖 moonbitlang/async@0.19.2
moon.pkg              # 空
cmd/main/
├── moon.pkg          # 导入 async/http + core/strconv
└── main.mbt          # 使用 @strconv.parse_int
.github/workflows/
└── ci.yml            # CI 自动验证
```
