import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Common
import "./StockUtils.js" as Utils

/*
 * StockDataManager.qml - Data management for StockManager plugin
 * Handles loading, saving, fetching and parsing stock data
 */
QtObject {
    id: root
    
    // Signals
    signal dataLoaded()
    signal dataSaved()
    signal dataError(string error)
    signal stockDataUpdated()
    
    // Properties
    property var stocks: []
    property var shIndex: ({"currentPrice": 0, "changeAmount": 0, "changePercent": 0})
    property bool isLoading: false
    property string lastUpdateTime: "Never"
    property string stockDataPath: {
        var basePath = Qt.resolvedUrl(".").toString().replace("file://", "");
        // Ensure trailing slash
        if (!basePath.endsWith("/")) basePath += "/";
        return basePath + "StockData.json";
    }
    
    // Sorting state
    property string sortKey: ""
    property bool sortAscending: true
    
    // Default stocks when no data file exists
    property var defaultStocks: [
        {code: "sh000001", name: "上证指数"},
        {code: "sz000559", name: "万向钱潮"},
        {code: "sz002195", name: "岩山科技"},
        {code: "sz002050", name: "三花智控"},
        {code: "sh601138", name: "工业富联"}
    ]
    
    // Private: Create stock object
    function _createStockObj(code, name, costPrice) {
        return {
            code: code,
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
    
    // Add stock to list
    function addStock(code, name, costPrice) {
        if (!code) {
            console.warn("StockDataManager: Empty stock code");
            return false;
        }
        
        // Check if already exists
        for (var i = 0; i < stocks.length; i++) {
            if (stocks[i].code === code) {
                console.warn("StockDataManager: Stock already exists:", code);
                return false;
            }
        }
        
        stocks.push(_createStockObj(code, name, costPrice));
        stocks = Utils.cloneStocks(stocks); // Trigger update
        saveStockData();
        return true;
    }
    
    // Remove stock from list
    function removeStock(code) {
        if (!code) return false;
        
        for (var i = 0; i < stocks.length; i++) {
            if (stocks[i].code === code) {
                stocks.splice(i, 1);
                stocks = Utils.cloneStocks(stocks); // Trigger update
                saveStockData();
                return true;
            }
        }
        return false;
    }
    
    // Sort stocks by key
    function sortStocks(key) {
        if (stocks.length === 0) return;
        
        // Toggle sort order if same key
        if (sortKey === key) {
            sortAscending = !sortAscending;
        } else {
            sortKey = key;
            // Default: name/code ascending, others descending
            sortAscending = (key === "name" || key === "code");
        }
        
        // Separate index from others
        var indexStock = null;
        var others = [];
        
        for (var i = 0; i < stocks.length; i++) {
            if (Utils.isMarketIndex(stocks[i].code)) {
                indexStock = stocks[i];
            } else {
                others.push(stocks[i]);
            }
        }
        
        // Sort others
        var dir = sortAscending ? 1 : -1;
        others.sort(function(a, b) {
            var av, bv;
            switch (key) {
                case "name":
                    av = a.name || "";
                    bv = b.name || "";
                    break;
                case "code":
                    av = Utils.getPureCode(a.code);
                    bv = Utils.getPureCode(b.code);
                    break;
                case "price":
                    av = a.currentPrice || 0;
                    bv = b.currentPrice || 0;
                    break;
                case "change":
                    av = a.changeAmount || 0;
                    bv = b.changeAmount || 0;
                    break;
                case "percent":
                    av = a.changePercent || 0;
                    bv = b.changePercent || 0;
                    break;
                default:
                    return 0;
            }
            if (av === bv) return 0;
            return av > bv ? dir : -dir;
        });
        
        // Reconstruct array with index first
        var newStocks = [];
        if (indexStock) newStocks.push(indexStock);
        for (var j = 0; j < others.length; j++) {
            newStocks.push(others[j]);
        }
        stocks = newStocks;
    }
    
    // Load stock data from file
    function loadStockData() {
        var cmd = `cat "${stockDataPath}" 2>/dev/null || echo "[]"`;
        Proc.runCommand("stockManager:loadData", ["sh", "-c", cmd], function(output, exitCode) {
            if (exitCode !== 0) {
                console.warn("StockDataManager: Failed to read data file");
                loadDefaultStocks();
                return;
            }
            
            try {
                var data = JSON.parse(output.trim());
                if (Array.isArray(data) && data.length > 0) {
                    stocks = [];
                    for (var i = 0; i < data.length; i++) {
                        var stock = data[i];
                        stocks.push(_createStockObj(stock.code, stock.name, stock.costPrice || 0));
                    }
                    console.log("StockDataManager: Loaded", stocks.length, "stocks from file");
                    dataLoaded();
                } else {
                    console.log("StockDataManager: No data in file, loading defaults");
                    loadDefaultStocks();
                }
            } catch (e) {
                console.warn("StockDataManager: Failed to parse data file:", e);
                loadDefaultStocks();
            }
            
            fetchStockData();
        });
    }
    
    // Load default stocks
    function loadDefaultStocks() {
        stocks = [];
        for (var i = 0; i < defaultStocks.length; i++) {
            var s = defaultStocks[i];
            stocks.push(_createStockObj(s.code, s.name, 0));
        }
        console.log("StockDataManager: Loaded", stocks.length, "default stocks");
        saveStockData();
        dataLoaded();
    }
    
    // Save stock data to file
    function saveStockData() {
        var data = [];
        for (var i = 0; i < stocks.length; i++) {
            data.push({
                code: stocks[i].code,
                name: stocks[i].name
            });
        }
        
        var jsonStr = JSON.stringify(data, null, 2);
        // Use printf to avoid shell escaping issues
        var cmd = `printf '%s' '${jsonStr}' > "${stockDataPath}"`;
        
        Proc.runCommand("stockManager:saveData", ["sh", "-c", cmd], function(output, exitCode) {
            if (exitCode === 0) {
                console.log("StockDataManager: Saved stock data to file");
                dataSaved();
            } else {
                console.warn("StockDataManager: Failed to save stock data");
                dataError("Failed to save data");
            }
        });
    }
    
    // Fetch stock data from API
    function fetchStockData() {
        if (stocks.length === 0) return;
        
        isLoading = true;
        var codes = [];
        for (var i = 0; i < stocks.length; i++) {
            codes.push(stocks[i].code);
        }
        
        var apiUrl = Utils.API.TENCENT_QUOTE + codes.join(",");
        var cmd = `curl -s "${apiUrl}" | iconv -f GBK -t UTF-8`;
        
        console.log("StockDataManager: Fetching data for", codes.length, "stocks");
        
        Proc.runCommand("stockManager:fetch", ["sh", "-c", cmd], function(output, exitCode) {
            if (exitCode === 0 && output) {
                parseStockData(output);
            } else {
                console.warn("StockDataManager: Failed to fetch data");
                dataError("Network error");
            }
            isLoading = false;
        });
    }
    
    // Parse API response data
    function parseStockData(data) {
        if (!data) return;
        
        try {
            var lines = data.trim().split('\n');
            var stockMap = {};
            var updatedCodes = [];
            
            // Build lookup map
            for (var i = 0; i < stocks.length; i++) {
                stockMap[stocks[i].code] = i;
            }
            
            for (var j = 0; j < lines.length; j++) {
                var parsed = Utils.parseApiLine(lines[j]);
                if (!parsed) continue;
                
                var idx = stockMap[parsed.code];
                if (idx === undefined) continue;
                
                var stock = stocks[idx];
                if (!stock) continue;
                
                // Update stock data
                if (parsed.name) stock.name = parsed.name;
                if (parsed.currentPrice > 0) {
                    stock.currentPrice = parsed.currentPrice;
                    stock.prevClose = parsed.prevClose;
                    stock.changeAmount = parsed.changeAmount;
                    stock.changePercent = parsed.changePercent;
                    
                    // Calculate profit
                    if (stock.costPrice > 0) {
                        stock.profit = parsed.currentPrice - stock.costPrice;
                        stock.profitPercent = (stock.profit / stock.costPrice) * 100;
                    }
                    
                    // Update SH index
                    if (Utils.isMarketIndex(parsed.code)) {
                        shIndex = {
                            currentPrice: parsed.currentPrice,
                            changeAmount: parsed.changeAmount,
                            changePercent: parsed.changePercent
                        };
                    }
                    
                    updatedCodes.push(parsed.code);
                }
            }
            
            // Trigger UI update
            stocks = Utils.cloneStocks(stocks);
            lastUpdateTime = Utils.getCurrentTimeString();
            
            console.log("StockDataManager: Updated", updatedCodes.length, "stocks");
            stockDataUpdated();
            
        } catch (e) {
            console.warn("StockDataManager: Parse error:", e);
            dataError("Parse error: " + e);
        }
    }
    
    // Preview stock by code (for add dialog)
    function previewStock(code, callback) {
        if (!code || code.length < 8) {
            if (callback) callback(null);
            return;
        }
        
        var apiUrl = Utils.API.TENCENT_QUOTE + code;
        var cmd = `curl -s "${apiUrl}" | iconv -f GBK -t UTF-8`;
        
        Proc.runCommand("stockManager:preview", ["sh", "-c", cmd], function(output, exitCode) {
            if (exitCode !== 0 || !output) {
                if (callback) callback(null);
                return;
            }
            
            try {
                var parsed = Utils.parseApiLine(output.trim());
                if (parsed && parsed.name) {
                    callback({code: parsed.code, name: parsed.name});
                } else {
                    callback(null);
                }
            } catch (e) {
                console.warn("StockDataManager: Preview error:", e);
                callback(null);
            }
        });
    }
    
    // Get filtered stocks (excluding index)
    function getDisplayStocks() {
        return stocks.filter(function(s) { return !Utils.isMarketIndex(s.code); });
    }
    
    // Calculate popout height
    function getPopoutHeight() {
        return Utils.calculatePopoutHeight(stocks);
    }
}
