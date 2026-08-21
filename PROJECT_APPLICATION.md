# moon-webfinger 项目申报书

**申报人：** 赵士超　　**GitHub：** `qianfuzsc`　　**联系方式：** 已通过赛事官方报名渠道提交

## 一、项目名称和仓库地址

- 项目名称：`moon-webfinger`
- GitHub 仓库：<https://github.com/qianfuzsc/moon-webfinger>

## 二、项目简介

`moon-webfinger` 是使用 MoonBit 开发的 RFC 7033 WebFinger 与 JSON Resource Descriptor（JRD）工具库。项目面向本地、确定性的数据处理，提供 JRD 解析、序列化、请求目标构造、关系查询、响应上下文验证和安全审计能力，不在库内发起网络请求。项目包含可复用 API、命令行工具、示例程序、完整文档及跨 target 验证脚本。

## 三、项目方向与适用场景

项目属于网络协议、身份发现和开发者工具方向，可用于去中心化身份系统、Fediverse／ActivityPub 周边工具、WebFinger 客户端或服务端的数据层、身份发现服务、协议测试工具及 MoonBit 网络协议基础组件。调用方可自行接入 HTTP 与 TLS，本项目专注于协议数据模型和安全边界。

## 四、拟实现的核心功能

1. 构造 `/.well-known/webfinger` 请求目标，正确编码 `resource` 与多个 `rel` 参数；
2. 解析、构建和确定性序列化 JRD，支持 subject、aliases、properties、links、localized titles 及扩展成员；
3. 提供关系、媒体类型、href 和属性查询接口；
4. 验证 URI、HTTPS 响应上下文、状态码与 `application/jrd+json` 媒体类型；
5. 提供结构化错误、可配置资源限制、安全审计、九个 CLI 命令和五个示例；
6. 在 wasm-gc、JavaScript 和 native target 上进行自动化测试与复现验证。

## 五、项目来源说明

本项目为原创 MoonBit 实现，不是对现有开源 WebFinger 项目的移植，也未复制第三方库源码。协议行为参考 IETF RFC 7033、RFC 3986、RFC 7565、RFC 8259 和 RFC 9110，少量 RFC 示例仅用于兼容性测试，并已在 `THIRD_PARTY_NOTICES.md` 中标注来源。项目代码采用 Apache License 2.0 发布。

## 六、完成度与终审交付

- 当前终审版本为 `0.1.0`，已发布到 Mooncakes，模块名、GitHub 仓库和包名保持一致；
- 有效 MoonBit 源码共 5955 行，其中核心库代码 4000 行、测试代码 1078 行、CLI 与示例代码 877 行；
- 具有 94 个命名测试、1000 个确定性属性用例和 772 个截断输入用例；
- wasm、wasm-gc、JavaScript 与 native 四个目标均通过 `--deny-warn` 严格检查和测试；
- 提供九命令 CLI、五个可运行示例、架构与使用文档、RFC 规范映射、限制说明和安全边界；
- 提供一键本地验证脚本与 GitHub Actions，覆盖格式、公开 API、编译、测试、CLI、示例和打包清单；
- 项目仅依赖 MoonBit 标准库，采用 Apache-2.0 许可证，标准测试素材来源已单独声明。

项目核心功能已达到成熟 MVP 范围。本次终审整理没有进行无意义扩写，主要完成稳定版号、纯 WebAssembly 兼容、新编译器废弃接口适配、严格质量门禁、持续集成和公开材料隐私清理。
