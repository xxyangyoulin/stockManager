# DankMaterialShell StockManager Plugin

A real-time A-share stock quote monitoring plugin for DankMaterialShell.


<!-- README.md (英文) 顶部 -->
🇨🇳 **English** | [中文](./README.zh-CN.md)


## Features

- 📊 **Live Quotes** – Automatically refreshes stock data every 30 seconds
- 📈 **Gain/Loss Display** – Red for gain, green for loss, clear at a glance
- 🔍 **Multi-Stock Monitoring** – Monitor multiple stocks simultaneously
- 📱 **DankBar Integration** – Shows Shanghai Composite Index change in the status bar

## Screenshot

![StockManager screenshot](screenshot/sc.png)

## Data Source

Real-time A-share market data is fetched from the Tencent Finance API.

## Displayed Fields

- **Name** – Stock name
- **Last** – Latest price
- **Change** – Price change (points)
- **Change %** – Percentage change

## API Field Mapping

Tencent stock API response data mapping:
- `parts[3]` – Current price
- `parts[4]` – Previous close price
- `parts[31]` – Price change
- `parts[32]` – Change percentage

## Dependencies

- **curl** – Fetch stock data
- **iconv** – Convert GBK to UTF-8

## Author

leemeng0x61@gmail.com

## Changelog

### v1.1.0 (2026-01-30)
- ✅ Code refactoring with modular architecture
- ✅ Separated data management and UI components
- ✅ Unified utility function library
- ✅ Performance optimizations, reduced unnecessary re-renders
- ✅ Improved code maintainability

### v1.0.0 (2026-01-14)
- ✅ Real-time quote display
- ✅ Gain/loss color highlighting
- ✅ DankBar integration to show Shanghai Composite Index
- ✅ Auto refresh mechanism
- ✅ JSON-based configuration support

## License
MIT License - See LICENSE file for details
