/*
 * StockUtils.js - Utility functions for StockManager plugin
 * Constants and helper functions for stock data processing
 */

// Market type prefixes
var MARKET_PREFIX = {
    SHANGHAI: "sh",
    SHENZHEN: "sz",
    HONG_KONG: "hk",
    USA: "us"
};

// Color constants
var COLORS = {
    UP: "#ff4d4f",      // Red for price up
    DOWN: "#52c41a",    // Green for price down
    NEUTRAL: "#888888", // Gray for no change
    WHITE: "#ffffff",
    DELETE: "#ff4d4f"
};

// UI Constants
var UI = {
    HEADER_HEIGHT: 30,
    ROW_HEIGHT: 32,
    ROW_SPACING: 2,
    DIALOG_WIDTH: 280,
    DIALOG_HEIGHT: 160,
    DELETE_BUTTON_WIDTH: 52,
    DELETE_THRESHOLD: -35,
    DELETE_MAX_DRAG: -70,
    REFRESH_INTERVAL: 30000, // 30 seconds
    POPOUT_MIN_HEIGHT: 320,
    POPOUT_MAX_HEIGHT: 750,
    POPOUT_BASE_HEIGHT: 140
};

// Column widths
var COLUMN_WIDTH = {
    NAME: 80,
    CODE: 70,
    PRICE: 60,
    CHANGE: 60,
    PERCENT: 70
};

// API endpoints
var API = {
    TENCENT_QUOTE: "https://qt.gtimg.cn/q="
};

// Stock codes
var STOCK_CODES = {
    SH_INDEX: "sh000001"
};

/**
 * Get country emoji from stock code
 * @param {string} code - Stock code with prefix
 * @returns {string} Emoji representing the market
 */
function getCountryEmoji(code) {
    if (!code) return "🌐";
    if (code.startsWith(MARKET_PREFIX.SHANGHAI) || code.startsWith(MARKET_PREFIX.SHENZHEN)) {
        return "🇨🇳";
    }
    if (code.startsWith(MARKET_PREFIX.USA)) return "🇺🇸";
    if (code.startsWith(MARKET_PREFIX.HONG_KONG)) return "🇭🇰";
    return "🌐";
}

/**
 * Get pure stock code without market prefix
 * @param {string} code - Stock code with prefix
 * @returns {string} Stock code without prefix
 */
function getPureCode(code) {
    if (!code) return "";
    return code.replace(/^(sh|sz|us|hk)/i, "");
}

/**
 * Determine market prefix from stock number
 * @param {string} number - Stock number (6 digits)
 * @returns {string} Market prefix (sh/sz)
 */
function getMarketPrefix(number) {
    if (!number || number.length !== 6) return MARKET_PREFIX.SHANGHAI;
    var firstDigit = number.charAt(0);
    // Shenzhen: 0xxxxx, 3xxxxx
    if (firstDigit === '0' || firstDigit === '3') {
        return MARKET_PREFIX.SHENZHEN;
    }
    // Shanghai: 6xxxxx, others default to sh
    return MARKET_PREFIX.SHANGHAI;
}

/**
 * Auto-complete stock code from input
 * @param {string} input - User input
 * @returns {string|null} Complete stock code or null
 */
function autoCompleteStockCode(input) {
    if (!input) return null;
    var pureNumber = input.replace(/[^0-9]/g, '');
    if (pureNumber.length !== 6) return null;
    return getMarketPrefix(pureNumber) + pureNumber;
}

/**
 * Get color based on change amount
 * @param {number} change - Change amount
 * @returns {string} Color code
 */
function getChangeColor(change) {
    if (change > 0) return COLORS.UP;
    if (change < 0) return COLORS.DOWN;
    return COLORS.NEUTRAL;
}

/**
 * Get color based on profit
 * @param {number} profit - Profit amount
 * @returns {string} Color code
 */
function getProfitColor(profit) {
    if (profit > 0) return COLORS.UP;
    if (profit < 0) return COLORS.DOWN;
    return COLORS.WHITE;
}

/**
 * Format number with fixed decimal places
 * @param {number} value - Number to format
 * @param {number} digits - Decimal places (default 2)
 * @returns {string} Formatted string
 */
function formatNumber(value, digits) {
    digits = digits || 2;
    if (value === undefined || value === null || isNaN(value)) return "--";
    return value.toFixed(digits);
}

/**
 * Format change value with sign
 * @param {number} value - Change value
 * @param {number} digits - Decimal places
 * @returns {string} Formatted string with sign
 */
function formatChange(value, digits) {
    digits = digits || 2;
    if (value === undefined || value === null || isNaN(value) || value === 0) return "--";
    return (value >= 0 ? "+" : "") + value.toFixed(digits);
}

/**
 * Format percentage with sign and % symbol
 * @param {number} value - Percentage value
 * @param {number} digits - Decimal places
 * @returns {string} Formatted string with %
 */
function formatPercent(value, digits) {
    digits = digits || 2;
    if (value === undefined || value === null || isNaN(value) || value === 0) return "--";
    return (value >= 0 ? "+" : "") + value.toFixed(digits) + "%";
}

/**
 * Format current time as HH:MM:SS
 * @returns {string} Formatted time
 */
function getCurrentTimeString() {
    var now = new Date();
    return padZero(now.getHours()) + ":" + 
           padZero(now.getMinutes()) + ":" + 
           padZero(now.getSeconds());
}

/**
 * Pad number with leading zero
 * @param {number} num - Number to pad
 * @returns {string} Padded string
 */
function padZero(num) {
    return num.toString().padStart(2, '0');
}

/**
 * Create empty stock object
 * @param {string} code - Stock code
 * @param {string} name - Stock name
 * @param {number} costPrice - Cost price (optional)
 * @returns {object} Stock object
 */
function createStock(code, name, costPrice) {
    return {
        code: code || "",
        name: name || "",
        costPrice: costPrice || 0,
        currentPrice: 0,
        prevClose: 0,
        changeAmount: 0,
        changePercent: 0,
        profit: 0,
        profitPercent: 0
    };
}

/**
 * Check if stock is market index
 * @param {string} code - Stock code
 * @returns {boolean} True if index
 */
function isMarketIndex(code) {
    return code === STOCK_CODES.SH_INDEX;
}

/**
 * Get display stocks count (excluding index)
 * @param {Array} stocks - Stock array
 * @returns {number} Count
 */
function getDisplayStockCount(stocks) {
    if (!stocks || !Array.isArray(stocks)) return 0;
    return stocks.filter(function(s) { return !isMarketIndex(s.code); }).length;
}

/**
 * Calculate popout height based on stock count
 * @param {Array} stocks - Stock array
 * @returns {number} Calculated height
 */
function calculatePopoutHeight(stocks) {
    var count = getDisplayStockCount(stocks);
    var calculated = UI.POPOUT_BASE_HEIGHT + (count * UI.ROW_HEIGHT);
    return Math.max(UI.POPOUT_MIN_HEIGHT, Math.min(UI.POPOUT_MAX_HEIGHT, calculated));
}

/**
 * Parse API response line
 * @param {string} line - Raw API response line
 * @returns {object|null} Parsed data or null
 */
function parseApiLine(line) {
    if (!line) return null;
    
    var match = line.match(/v_.*="(.*)"/);
    if (!match || match.length < 2) return null;
    
    var parts = match[1].split('~');
    if (parts.length < 33) return null;
    
    var codePart = match[0].split('=')[0];
    var code = codePart.substring(codePart.indexOf('_') + 1);
    
    return {
        code: code,
        name: parts[1],
        currentPrice: parseFloat(parts[3]) || 0,
        prevClose: parseFloat(parts[4]) || 0,
        changeAmount: parseFloat(parts[31]) || 0,
        changePercent: parseFloat(parts[32]) || 0
    };
}

/**
 * Deep clone array of stocks
 * @param {Array} stocks - Stock array
 * @returns {Array} Cloned array
 */
function cloneStocks(stocks) {
    if (!stocks || !Array.isArray(stocks)) return [];
    return stocks.slice();
}
