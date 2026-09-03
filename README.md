# DankMaterialShell StockManager Plugin

A market quote monitoring plugin for DankMaterialShell, with support for A-shares, ETFs, indices, and industry boards.


<!-- README.md (英文) 顶部 -->
🇨🇳 **English** | [中文](./README.zh-CN.md)

## Features

- 📊 **Live Quotes** – Automatically refresh quotes at a configurable interval
- 📈 **Intraday & Daily Charts** – One-minute intraday charts and 60-day candlestick charts with MA5/MA10/MA20
- 🔍 **Market Search** – Search and filter A-shares, ETFs, indices, and industry boards
- 📌 **List Management** – Add, remove, reorder, or move a security directly to the top
- 📱 **DankBar Integration** – Pin any tracked security, including the Shanghai Composite Index, to the status bar
- 🎨 **Custom Display** – Configurable gain/loss colors, status-bar format, scrolling, and list sparklines

## Screenshot

![StockManager screenshot](screenshot/sc.png)

## Keyboard Shortcuts

- `R` – Refresh Data
- `Delete` / `Backspace` – Remove Stock
- `Enter` – Pin / Unpin Stock
- `j` / `k` (or `↑` / `↓`) – Navigate List
- `Shift` + `j` / `k` (or `Shift` + `↑` / `↓`) – Move Stock Position
- `gg` / `Shift` + `g` – Jump to the first / last item
- `1`–`5` – Sort by Name / Code / Price / Change / Percent

## Data Source

- Tencent Finance: quotes, search suggestions, and daily candlestick data
- Sina Finance: one-minute intraday data
- Eastmoney: industry-board search, quotes, intraday data, and daily candlestick data

External providers may occasionally be unavailable. Board requests use limited retries, and the daily-chart view distinguishes an empty result from a failed request and allows retrying.

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

### Unreleased

- Added searchable A-share, ETF, index, and industry-board categories with debounced suggestions.
- Added one-minute intraday charts and switchable 60-day candlestick charts.
- Added MA5, MA10, and MA20 overlays to daily charts.
- Added adaptive chart ranges, explicit loading failures, and click-to-retry.
- Added list move-to-top actions and support for pinning any tracked security to the status bar.
- Refreshed the interface and simplified obsolete settings internals.

### v1.2.1 (2026-02-06)

- ✅ **Stock Detail Popup**: Click on any stock to view detailed information.

### v1.2.0 (2026-02-01)

- ✅ **Trend Charts**: Added sparklines to visualize price history in the list view.
- ✅ **Advanced Customization**: Support for custom trend colors (Up/Down), status bar scrolling, and configurable refresh intervals.
- ✅ **Display Modes**: Toggle between Percent/Amount and various Name formats (Pinyin/Hanzi).
- ✅ **Improved Interaction**: Swipe gestures to Pin/Delete stocks.
- ✅ **Keyboard Shortcuts**: Comprehensive keyboard control for navigation, sorting, and editing.
- ✅ **Enhanced Add Dialog**: Search by stock code, name, or pinyin.

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
