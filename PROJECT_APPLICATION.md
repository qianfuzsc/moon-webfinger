# moon-webfinger 项目申报书

**申报人：** 赵士超　　**GitHub：** `qianfuzsc`　　**邮箱：** `3200329122@qq.com`

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
