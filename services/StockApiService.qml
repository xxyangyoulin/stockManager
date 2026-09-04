import QtQuick
import Quickshell
import Quickshell.Io
import "./StockUtils.js" as Utils

/*
 * StockApiService.qml - Specialized service for handling external API requests
 * Encapsulates fetch and parse logic to allow easy swapping of data providers.
 */

Item {
    id: root

    // --- Configuration: Current Providers ---
    readonly property string quoteProvider: "tencent"

    // --- Internal Process Helper ---
    Component {
        id: procComp
        Process {
            id: procInstance
            property var callback
            property string outputBuffer: ""

            stdout: StdioCollector {
                onStreamFinished: procInstance.outputBuffer = text
            }

            onExited: (ec) => {
                // Wait for the next event loop to ensure any pending dataRead 
                // signals have been processed.
                Qt.callLater(function () {
                    if (callback) {
                        callback(outputBuffer, ec);
                        callback = null;
                    }
                    destroy();
                });
            }
        }
    }

    function runCommand(args, callback) {
        var p = procComp.createObject(root, {
            command: args,
            callback: callback
        });
        p.running = true;
    }

    // --- Public Interface ---

    /**
     * Fetch real-time quotes for a list of stock codes
     */
    function fetchQuotes(codes, callback) {
        if (!codes || codes.length === 0) return callback([]);

        var marketCodes = codes.filter(code => !code.toLowerCase().startsWith("bk"));
        var boardCodes = codes.filter(code => code.toLowerCase().startsWith("bk"));
        var pending = (marketCodes.length > 0 ? 1 : 0) + boardCodes.length;
        var results = [];

        function finish(items) {
            results = results.concat(items);
            pending--;
            if (pending === 0) callback(results);
        }

        if (marketCodes.length > 0) {
            var url = "https://qt.gtimg.cn/q=" + marketCodes.join(",");
            var cmd = `curl -s --max-time 10 "${url}" | iconv -f GBK -t UTF-8`;
            runCommand(["sh", "-c", cmd], function (out, ec) {
                if (ec !== 0 || !out) return finish([]);

                var items = [];
                var lines = out.trim().split('\n');
                for (var i = 0; i < lines.length; i++) {
                    var parsed = parseQuoteLine(lines[i], quoteProvider);
                    if (parsed) items.push(parsed);
                }
                finish(items);
            });
        }

        for (var i = 0; i < boardCodes.length; i++) {
            let boardCode = boardCodes[i];
            let pureCode = Utils.getPureCode(boardCode);
            let url = `https://push2delay.eastmoney.com/api/qt/stock/get?secid=90.${pureCode}&fields=f43,f57,f58,f60,f124,f169,f170`;
            runCommand(["curl", "-s", "--max-time", "10", "--retry", "2", "--retry-all-errors", "--retry-delay", "1", url], function (out, ec) {
                if (ec !== 0 || !out) return finish([]);
                finish(parseBoardQuote(out, boardCode));
            });
        }
    }

    /**
     * Fetch intraday time-sharing data for a single stock
     */
    function fetchIntraday(code, callback) {
        if (!code) return callback([]);

        var lowerCode = code.toLowerCase();
        var market = lowerCode.startsWith("bk") ? "90" : (lowerCode.startsWith("sh") ? "1" : "0");
        var url = `https://push2delay.eastmoney.com/api/qt/stock/trends2/get?secid=${market}.${Utils.getPureCode(code)}&fields1=f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11,f12,f13&fields2=f51,f52,f53,f54,f55,f56,f57,f58&ndays=1`;
        runCommand(["curl", "-s", "--max-time", "10", "--retry", "2", "--retry-all-errors", "--retry-delay", "1", url], function (out, ec) {
            if (ec !== 0 || !out) return callback([]);
            callback(parseEastmoneyIntraday(out));
        });
    }

    function fetchDaily(code, callback) {
        if (!code) return callback([], false);

        if (code.toLowerCase().startsWith("bk")) {
            var pureCode = Utils.getPureCode(code);
            var boardUrl = `https://push2his.eastmoney.com/api/qt/stock/kline/get?secid=90.${pureCode}&ut=7eea3edcaed734bea9cbfc24409ed989&klt=101&fqt=1&beg=0&end=20500101&fields1=f1,f2,f3&fields2=f51,f52,f53,f54,f55,f56`;
            runCommand(["curl", "-s", "--max-time", "10", "--retry", "2", "--retry-all-errors", "--retry-delay", "1", boardUrl], function (out, ec) {
                if (ec !== 0 || !out) return callback([], false);
                var data = parseBoardDaily(out);
                callback(data, data !== null);
            });
            return;
        }

        var url = `https://web.ifzq.gtimg.cn/appstock/app/fqkline/get?param=${code},day,,,60,qfq`;
        var cmd = `curl -s --max-time 10 "${url}"`;

        runCommand(["sh", "-c", cmd], function (out, ec) {
            if (ec !== 0 || !out) return callback([], false);

            try {
                var json = JSON.parse(out);
                var stockData = json.data && json.data[code];
                var rows = stockData ? (stockData.qfqday || stockData.day || []) : [];
                callback(rows.slice(-60).map(function (row) {
                    return {
                        date: row[0],
                        open: parseFloat(row[1]),
                        close: parseFloat(row[2]),
                        high: parseFloat(row[3]),
                        low: parseFloat(row[4]),
                        volume: parseFloat(row[5])
                    };
                }), true);
            } catch (e) {
                callback([], false);
            }
        });
    }

    /**
     * Search/Suggest stocks by keyword
     */
    function searchStocks(keyword, callback) {
        if (!keyword || keyword.trim().length < 1) return callback([]);

        var marketResults = [];
        var boardResults = [];
        var marketDone = false;
        var boardDone = false;

        function publish() {
            if (!marketDone) return;
            callback(boardDone ? boardResults.concat(marketResults) : marketResults.slice());
        }

        var marketUrl = `https://smartbox.gtimg.cn/s3/?q=${encodeURIComponent(keyword)}&t=all`;
        runCommand(["curl", "-s", "--max-time", "5", marketUrl], function (out, ec) {
            if (ec === 0 && out) marketResults = parseTencentSuggestions(out);
            marketDone = true;
            publish();
        });

        var boardUrl = `https://searchapi.eastmoney.com/api/suggest/get?input=${encodeURIComponent(keyword)}&type=14&token=D43BF722C8E33BE4941CC34E21284D5F4`;
        runCommand(["curl", "-s", "--max-time", "5", boardUrl], function (out, ec) {
            if (ec === 0 && out) boardResults = parseBoardSuggestions(out);
            boardDone = true;
            publish();
        });
    }

    // --- Private Parsers ---

    function parseTencentSuggestions(data) {
        var match = data.match(/v_hint="([^"]*)"/);
        if (!match || !match[1] || match[1] === "N") return [];

        var decoded = match[1].replace(/\\u([0-9a-fA-F]{4})/g, function (_, hex) {
            return String.fromCharCode(parseInt(hex, 16));
        });
        var results = [];
        var rows = decoded.split("^");
        for (var i = 0; i < rows.length; i++) {
            var parts = rows[i].split("~");
            if (parts.length < 5 || !/^(sh|sz|bj)$/.test(parts[0])) continue;

            var type = parts[4];
            if (!(type.startsWith("GP") || type === "ETF" || type === "LOF" || type === "ZS")) continue;
            results.push({
                name: parts[2],
                pureCode: parts[1],
                code: parts[0] + parts[1],
                type: type === "ZS" ? "指数" : (type === "ETF" || type === "LOF" ? "ETF" : "股票")
            });
        }
        return results.slice(0, 12);
    }

    function parseBoardSuggestions(data) {
        try {
            var json = JSON.parse(data);
            var rows = json.QuotationCodeTable && json.QuotationCodeTable.Data
                    ? json.QuotationCodeTable.Data : [];
            var results = [];
            for (var i = 0; i < rows.length; i++) {
                if (rows[i].Classify !== "BK") continue;
                results.push({
                    name: rows[i].Name,
                    pureCode: rows[i].Code,
                    code: "bk" + rows[i].Code,
                    type: "板块"
                });
            }
            return results.slice(0, 8);
        } catch (e) {
            return [];
        }
    }

    function parseBoardQuote(data, code) {
        try {
            var item = JSON.parse(data).data;
            if (!item || !item.f43 || !item.f60) return [];

            var quoteDate = "";
            var quoteTime = "";
            if (item.f124) {
                var date = new Date(item.f124 * 1000);
                quoteDate = Qt.formatDateTime(date, "yyyy-MM-dd");
                quoteTime = Qt.formatDateTime(date, "HH:mm");
            }
            return [{
                code: code,
                name: item.f58,
                currentPrice: item.f43 / 100,
                prevClose: item.f60 / 100,
                changeAmount: item.f169 / 100,
                changePercent: item.f170 / 100,
                quoteDate: quoteDate,
                quoteTime: quoteTime
            }];
        } catch (e) {
            return [];
        }
    }

    function parseEastmoneyIntraday(data) {
        try {
            var rows = JSON.parse(data).data.trends || [];
            var results = [];
            for (var i = 0; i < rows.length; i++) {
                var parts = rows[i].split(",");
                var dateTime = parts[0].split(" ");
                if (dateTime.length < 2 || dateTime[1] < "09:30" || dateTime[1] > "15:00") continue;
                results.push({
                    date: dateTime[0],
                    time: dateTime[1],
                    price: parseFloat(parts[2]),
                    averagePrice: parseFloat(parts[7])
                });
            }
            return results;
        } catch (e) {
            return [];
        }
    }

    function parseBoardDaily(data) {
        try {
            var rows = JSON.parse(data).data.klines || [];
            return rows.slice(-60).map(function (line) {
                var row = line.split(",");
                return {
                    date: row[0],
                    open: parseFloat(row[1]),
                    close: parseFloat(row[2]),
                    high: parseFloat(row[3]),
                    low: parseFloat(row[4]),
                    volume: parseFloat(row[5])
                };
            });
        } catch (e) {
            return null;
        }
    }

    function parseQuoteLine(line, provider) {
        if (provider === "tencent") {
            return Utils.parseApiLine(line);
        }
        return null;
    }

}
