# DankMaterialShell StockManager 插件

A股股票行情监控插件，用于 DankMaterialShell。

<!-- README.zh-CN.md (中文) 顶部 -->
🇺🇸 [English](./README.md) | **中文**

## 功能特性

- 📊 **实时行情** - 30秒自动刷新股票数据
- 📈 **涨跌显示** - 红涨绿跌，清晰直观
- 🔍 **多股票监控** - 支持同时监控多只股票
- 📱 **DankBar集成** - 在状态栏显示上证指数涨跌

## 屏幕截图
![Wallpaper Discovery screenshot](screenshot/sc.png)

## 数据来源

使用腾讯财经API获取实时A股行情数据。

## 显示字段

- **名字** - 股票名称
- **最新** - 最新价格
- **涨跌** - 涨跌额（点数）
- **涨幅** - 涨跌幅度（百分比）

## 数据字段说明

腾讯股票API返回数据格式：
- `parts[3]` - 当前价
- `parts[4]` - 昨收价
- `parts[31]` - 涨跌额
- `parts[32]` - 涨幅%

## 依赖

- curl - 用于获取股票数据
- iconv - 用于GBK转UTF-8

## 作者

leemeng0x61@gmail.com 

## 更新日志

### v1.0.0 (2026-01-14)
- ✅ 实时行情显示
- ✅ 涨跌颜色标识
- ✅ DankBar集成显示上证指数
- ✅ 自动刷新机制
- ✅ JSON配置支持
