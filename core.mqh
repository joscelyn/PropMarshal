//+------------------------------------------------------------------+
//|                           core.mqh                               |
//|               Drawdown Protection Expert Advisor                 |
//+------------------------------------------------------------------+

#ifdef __MQL5__
#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\PositionInfo.mqh>
#endif

//--- Enumerations
enum ENUM_MODE {
    MODE_DISABLED = 0, // Disabled
    MODE_CURRENCY = 1, // Currency Amount (currency)
    MODE_PERCENT  = 2  // Percentage (%)
};

enum ENUM_ALERT_TYPE {
    ALERT_NONE         = 0, // Nothing
    ALERT_ONLY         = 1, // Alert
    ALERT_NOTIF        = 2, // Alert & Notification
    ALERT_EMAIL        = 3, // Alert & Email
    ALERT_ALL          = 4  // Everything (Alert, Notification & Email)
};

//--- Input Parameters
input group "=== Initial Balance ==="
input double          InputInitialBalance = 0.0;                // Initial balance (0 = use account balance)
input string initialbalancewarning1 = "";                       // We recommend to set this value to avoid issue on restart

input group "=== Recovery Buffer ==="
input ENUM_MODE       InputRecoveryMode  = MODE_PERCENT;         // Recovery buffer mode
input double          InputRecoveryLimit = 15.0;                 // Recovery buffer (0 = disabled)

input group "=== Daily Drawdown ==="
input ENUM_MODE    InputDailyDrawdownMode  = MODE_PERCENT;       // Daily drawdown mode
input double          InputDailyDrawdownLimit = 0.0;             // Daily drawdown limit (0 = disabled)
input ENUM_ALERT_TYPE InputDailyAlertType     = ALERT_ALL;      // Daily alert type
input int             InputGmtOffset          = 2;               // Daily reset GMT offset (hours)

input group "=== Trailing Drawdown ==="
input ENUM_MODE    InputTrailingDrawdownMode  = MODE_PERCENT;      // Trailing drawdown mode
input double          InputTrailingDrawdownLimit = 0.0;            // Trailing drawdown limit (0 = disabled)
input ENUM_ALERT_TYPE InputTrailingAlertType     = ALERT_ALL;     // Trailing alert type

input group "=== Static Drawdown ==="
input ENUM_MODE    InputStaticDrawdownMode  = MODE_PERCENT;      // Static drawdown mode
input double          InputStaticDrawdownLimit = 0.0;            // Static drawdown limit (0 = disabled)
input ENUM_ALERT_TYPE InputStaticAlertType     = ALERT_ALL;     // Static alert type

input group "=== Profit Target ==="
input ENUM_MODE       InputProfitTargetMode  = MODE_PERCENT;       // Profit target mode
input double          InputProfitTargetLimit = 0.0;                // Profit target limit (0 = disabled)
input ENUM_ALERT_TYPE InputProfitAlertType   = ALERT_ALL;         // Profit target alert type

input group "=== Close charts ==="
input bool            InputShouldCloseAllCharts      = true;        // Close all charts when drawdown is triggered (recommended)
input string closechartswarning1 = "EAs can try to open positions indefinitely if the charts are not closed."; // WARNING
input string closechartswarning2 = "If EAs open new positions, the PropMarshal will close them automatically"; // .
input string closechartswarning3 = "but it can create multiple small losses that may exceed the drawdown limit."; // .
input string closechartswarning4 = "When charts are closed, the PropMarshal will save them as templates and you"; // .
input string closechartswarning5 = "will be able to restore them later using a button."; // .
input string closechartswarning6 = "If the charts have been closed because of a daily drawdown, the PropMarshal"; // .
input string closechartswarning7 = "will automatically reopen the charts the next day."; // .

//--- Global variables
#ifdef __MQL5__
CTrade Trade;
#endif

double InitialBalance = 0.0;
double StartDayBalanceOrEquity = 0.0;
double HighestBalance = 0.0;
datetime LastDayChecked = 0;

struct ClosedChartData {
    string symbol;
    ENUM_TIMEFRAMES period;
    string templateName;
};
ClosedChartData ClosedCharts[];
bool IsLastCloseDailyDD = false;

//+------------------------------------------------------------------+
//| Calculate the effective limit after applying the recovery buffer |
//+------------------------------------------------------------------+
double GetEffectiveLimit(double limit, ENUM_MODE ddMode, double baseline) {
    if (limit <= 0 || InputRecoveryLimit <= 0 || InputRecoveryMode == MODE_DISABLED || baseline <= 0) {
        return limit;
    }

    double buffer = 0;
    if (ddMode == MODE_PERCENT) {
        if (InputRecoveryMode == MODE_PERCENT) {
            buffer = limit * (InputRecoveryLimit / 100.0);
        } else { // MODE_CURRENCY
            buffer = (InputRecoveryLimit / baseline) * 100.0;
        }
    } else { // ddMode == MODE_CURRENCY
        if (InputRecoveryMode == MODE_PERCENT) {
            buffer = limit * (InputRecoveryLimit / 100.0);
        } else { // MODE_CURRENCY
            buffer = InputRecoveryLimit;
        }
    }

    return MathMax(0, limit - buffer);
}

//+------------------------------------------------------------------+
//| Get the currency symbol from the account currency code           |
//+------------------------------------------------------------------+
string GetCurrencySymbol() {
    string currency = AccountInfoString(ACCOUNT_CURRENCY);
    if(currency == "USD") return "$";
    if(currency == "EUR") return "€";
    if(currency == "GBP") return "£";
    if(currency == "JPY") return "¥";
    if(currency == "CHF") return "₣";
    if(currency == "AUD") return "A$";
    if(currency == "CAD") return "C$";
    if(currency == "NZD") return "NZ$";
    return currency; // Fallback to code
}

#include "gui.mqh"

//+------------------------------------------------------------------+
//| State Persistence                                                |
//+------------------------------------------------------------------+
string GetGVName(string statName) {
    return StringFormat("PropM_%I64u_%s", AccountInfoInteger(ACCOUNT_LOGIN), statName);
}

void SaveState() {
    GlobalVariableSet(GetGVName("DailyBase"), StartDayBalanceOrEquity);
    GlobalVariableSet(GetGVName("HighestBal"), HighestBalance);
    GlobalVariableSet(GetGVName("LastDayTime"), (double)LastDayChecked);
}

void LoadState() {
    if (GlobalVariableCheck(GetGVName("DailyBase"))) 
        StartDayBalanceOrEquity = GlobalVariableGet(GetGVName("DailyBase"));
    if (GlobalVariableCheck(GetGVName("HighestBal"))) 
        HighestBalance = GlobalVariableGet(GetGVName("HighestBal"));
    if (GlobalVariableCheck(GetGVName("LastDayTime"))) 
        LastDayChecked = (datetime)GlobalVariableGet(GetGVName("LastDayTime"));
}

void ResetDailyBaseline(); // Forward declaration

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    PrintPP("EA initialized.");

    // --- Check Algo Trading authorization
    bool terminalTrade = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
    bool eaTrade       = (bool)MQLInfoInteger(MQL_TRADE_ALLOWED);
    bool accountTrade  = (bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT);

    if (!terminalTrade || !eaTrade || !accountTrade) {
        string errorMsg = "WARNING: Algo Trading is NOT authorized! PropMarshal may NOT be able to close positions.";
        if (!terminalTrade) errorMsg += "\n- Terminal 'Algo Trading' button is OFF.";
        if (!eaTrade)       errorMsg += "\n- EA 'Allow Algo Trading' checkbox is UNCHECKED.";
        if (!accountTrade)  errorMsg += "\n- Automated trading is disabled for this account/expert.";
        
        PrintAndAlertPP(errorMsg);
    }

#ifdef __MQL5__
    Trade.SetExpertMagicNumber(56390);
#endif

    InitialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    if (InputInitialBalance > 0) {
        InitialBalance = InputInitialBalance;
    }
    PrintPP(StringFormat("Initial balance initialized to: % .2f", InitialBalance));

    HighestBalance = MathMax(InitialBalance, AccountInfoDouble(ACCOUNT_EQUITY));

    LoadState();

    datetime nowLocal = TimeGMT() + (InputGmtOffset * 3600);
    MqlDateTime dt;
    TimeToStruct(nowLocal, dt);
    dt.hour = 0; dt.min = 0; dt.sec = 0;
    datetime todayMidnight = StructToTime(dt);

    // If day changed or no state was loaded, reset daily baseline
    if (LastDayChecked != todayMidnight || StartDayBalanceOrEquity <= 0) {
        ResetDailyBaseline();
    } else {
        PrintPP(StringFormat("Loaded saved daily baseline: %.2f", StartDayBalanceOrEquity));
        if (HighestBalance > 0) PrintPP(StringFormat("Loaded saved highest water mark: %.2f", HighestBalance));
    }

    EventSetTimer(1); // Check every second

    UpdateGUI();
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
    DeleteGUI();
    PrintPP(StringFormat("PropMarshal EA removed. Reason: %d", reason));
}

void CheckAndProtect(); // Forward declaration

//+------------------------------------------------------------------+
//| Timer event — main protection logic runs here                   |
//+------------------------------------------------------------------+
void OnTimer() {
    // Reset daily baseline at the start of each new day (using GMT + offset)
    datetime nowLocal = TimeGMT() + (InputGmtOffset * 3600);
    MqlDateTime dt;
    TimeToStruct(nowLocal, dt);
    dt.hour = 0;
    dt.min = 0;
    dt.sec = 0;
    datetime todayMidnight = StructToTime(dt);

    if (todayMidnight != LastDayChecked) {
        ResetDailyBaseline();
    }

    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    if (currentEquity > HighestBalance) {
        HighestBalance = currentEquity;
        SaveState();
    }

    UpdateGUI();
    CheckAndProtect();
}

//+------------------------------------------------------------------+
//| OnTick — also run the check on each tick for faster response    |
//+------------------------------------------------------------------+
void OnTick() {
    UpdateGUI();
    CheckAndProtect();
}

void RestoreClosedCharts(); // Forward declaration

//+------------------------------------------------------------------+
//| Reset the daily balance baseline                                 |
//+------------------------------------------------------------------+
void ResetDailyBaseline() {
    datetime nowLocal = TimeGMT() + (InputGmtOffset * 3600);
    MqlDateTime dt;
    TimeToStruct(nowLocal, dt);
    dt.hour = 0;
    dt.min = 0;
    dt.sec = 0;
    LastDayChecked = StructToTime(dt);

    StartDayBalanceOrEquity = AccountInfoDouble(ACCOUNT_BALANCE);
    double startDayEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    if (startDayEquity > StartDayBalanceOrEquity) {
        StartDayBalanceOrEquity = startDayEquity;
    }

    SaveState(); // Save the newly established baseline

    PrintPP(StringFormat("Daily baseline reset: % .2f at % s", StartDayBalanceOrEquity, TimeToString(LastDayChecked, TIME_DATE)));

    // Auto-restore charts if they were closed because of a daily DD hit
    if (IsLastCloseDailyDD && ArraySize(ClosedCharts) > 0) {
        RestoreClosedCharts();
        IsLastCloseDailyDD = false;
        PrintPP("Daily drawdown reset: automatically restored previously closed charts.");
    }
}

string CheckDrawdown(const string label, const ENUM_MODE mode, const double limit, const double baseline, const double equity); // Forward
string CheckProfitTarget(const string label, const ENUM_MODE mode, const double target, const double baseline, const double equity); // Forward
void SendAlerts(const string message, const ENUM_ALERT_TYPE alertType); // Forward declaration
void TriggerProtection(bool isDailyDD); // Forward declaration

//+------------------------------------------------------------------+
//| Core protection check                                            |
//+------------------------------------------------------------------+
void CheckAndProtect() {
#ifdef __MQL5__
    int orderCount = PositionsTotal() + OrdersTotal();
#else
    int orderCount = OrdersTotal();
#endif
    if (orderCount == 0) {
        // No trades or pending orders - nothing to protect
        return;
    }

    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

    double dailyLimit = GetEffectiveLimit(InputDailyDrawdownLimit, InputDailyDrawdownMode, StartDayBalanceOrEquity);
    double trailingLimit = GetEffectiveLimit(InputTrailingDrawdownLimit, InputTrailingDrawdownMode, HighestBalance);
    double staticLimit = GetEffectiveLimit(InputStaticDrawdownLimit, InputStaticDrawdownMode, InitialBalance);

    string dailyDDBreachedMessage    = CheckDrawdown("Daily",    InputDailyDrawdownMode,    dailyLimit,    StartDayBalanceOrEquity, equity);
    string trailingDDBreachedMessage = CheckDrawdown("Trailing", InputTrailingDrawdownMode, trailingLimit, HighestBalance,           equity);
    string staticDDBreachedMessage   = CheckDrawdown("Static",   InputStaticDrawdownMode,   staticLimit,   InitialBalance,          equity);

    string totalPTReachedMessage = CheckProfitTarget("Total", InputProfitTargetMode, InputProfitTargetLimit, InitialBalance, equity);
  
    string message = "";
    ENUM_ALERT_TYPE alertType = ALERT_NONE;

    if (dailyDDBreachedMessage != "") {
        message = dailyDDBreachedMessage;
        alertType = InputDailyAlertType;
    } else if (trailingDDBreachedMessage != "") {
        message = trailingDDBreachedMessage;
        alertType = InputTrailingAlertType;
    } else if (staticDDBreachedMessage != "") {
        message = staticDDBreachedMessage;
        alertType = InputStaticAlertType;
    } else if (totalPTReachedMessage != "") {
        message = totalPTReachedMessage;
        alertType = InputProfitAlertType;
    }

    if (message == "") {
        return;
    }

    SendAlerts(message, alertType);
    TriggerProtection(dailyDDBreachedMessage != "");
}

//+------------------------------------------------------------------+
//| Generic profit target reached check                              |
//+------------------------------------------------------------------+
string CheckProfitTarget(const string label, const ENUM_MODE mode, const double target, const double baseline, const double equity) {
    if (mode == MODE_DISABLED || target <= 0.0 || baseline <= 0.0) {
        return "";
    }

    double profit = equity - baseline;

    if (mode == MODE_PERCENT) {
        double profitPct = (profit / baseline) * 100.0;
        if (profitPct >= target) {
            return StringFormat("%s %.2f%% profit target reached: %.2f%% >= %.2f%%", label, target, profitPct, target);
        }
    } else { // MODE_CURRENCY
        if (profit >= target) {
            string symbol = GetCurrencySymbol();
            return StringFormat("%s %.2f%s profit target reached: %.2f%s >= %.2f%s", label, target, symbol, profit, symbol, target, symbol);
        }
    }

    return "";
}

//+------------------------------------------------------------------+
//| Generic drawdown breach check                                    |
//+------------------------------------------------------------------+
string CheckDrawdown(const string label, const ENUM_MODE mode, const double limit, const double baseline, const double equity) {
    if (mode == MODE_DISABLED || limit <= 0.0 || baseline <= 0.0) {
        return "";
    }

    double loss = baseline - equity;

    if (mode == MODE_PERCENT) {
        double lossPct = (loss / baseline) * 100.0;
        if (lossPct >= limit) {
            return StringFormat("%s %.2f%% drawdown breached: %.2f%% >= %.2f%%", label, limit, lossPct, limit);
        }
    } else { // MODE_CURRENCY
        if (loss >= limit) {
            string symbol = GetCurrencySymbol();
            return StringFormat("%s %.2f%s drawdown breached: %.2f%s >= %.2f%s", label, limit, symbol, loss, symbol, limit, symbol);
        }
    }

    return "";
}

void CloseOtherCharts(); // Forward declaration
void DeleteAllPendingOrders(); // Forward declaration
void CloseAllPositions(); // Forward declaration

//+------------------------------------------------------------------+
//| Main protection trigger                                          |
//+------------------------------------------------------------------+
void TriggerProtection(bool isDailyDD) {
    IsLastCloseDailyDD = isDailyDD;
    CloseOtherCharts();
    DeleteAllPendingOrders();
    CloseAllPositions();
}

//+------------------------------------------------------------------+
//| Fire alerts based on the selected alert type                     |
//+------------------------------------------------------------------+
void SendAlerts(const string message, const ENUM_ALERT_TYPE alertType) {
    static string lastMessage = "";
    static datetime lastAlertTime = 0;
    
    // Rate limit exact same alerts to once every 60 seconds
    if (message == lastMessage && TimeCurrent() - lastAlertTime < 60) {
        return; 
    }
    
    PrintPP(message);
    lastMessage = message;
    lastAlertTime = TimeCurrent();

    if (alertType == ALERT_NONE) return;

    if (alertType == ALERT_ONLY || alertType == ALERT_NOTIF || alertType == ALERT_EMAIL || alertType == ALERT_ALL)
        Alert(message);
    if (alertType == ALERT_NOTIF || alertType == ALERT_ALL)
        SendNotification(message);
    if (alertType == ALERT_EMAIL || alertType == ALERT_ALL)
        SendMail("PropMarshal", message);
}

//+------------------------------------------------------------------+
//| Delete all pending orders                                        |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders() {
#ifdef __MQL5__
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if (ticket > 0) {
            if (Trade.OrderDelete(ticket)) {
                PrintPP(StringFormat("Deleted pending order # %I64u", ticket));
            } else {
                PrintAndAlertPP(StringFormat("Failed to delete order # %I64u: %s", ticket, Trade.ResultComment()));
            }
        }
    }
#else
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderType() > OP_SELL) {
                ulong ticket = OrderTicket();
                if (OrderDelete((int)ticket, clrNONE)) {
                    PrintPP(StringFormat("Deleted pending order # %I64u", ticket));
                } else {
                    int err = GetLastError();
                    PrintAndAlertPP(StringFormat("Failed to delete order # %I64u: %d", ticket, err));
                }
            }
        }
    }
#endif
}

//+------------------------------------------------------------------+
//| Close all open positions                                         |
//+------------------------------------------------------------------+
void CloseAllPositions() {
#ifdef __MQL5__
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (ticket > 0) {
            if (Trade.PositionClose(ticket)) {
                PrintPP(StringFormat("Closed position # %I64u", ticket));
            } else {
                PrintAndAlertPP(StringFormat("Failed to close position # %I64u: %s", ticket, Trade.ResultComment()));   
            }
        }
    }
#else
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderType() <= OP_SELL) {
                ulong ticket = OrderTicket();
                bool res = false;
                if(OrderType() == OP_BUY)
                    res = OrderClose((int)ticket, OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), 10, clrNONE);
                else 
                    res = OrderClose((int)ticket, OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), 10, clrNONE);
                
                if (res) {
                    PrintPP(StringFormat("Closed position # %I64u", ticket));
                } else {
                    int err = GetLastError();
                    PrintAndAlertPP(StringFormat("Failed to close position # %I64u: %d", ticket, err));   
                }
            }
        }
    }
#endif
}

//+------------------------------------------------------------------+
//| Close all charts except the EA's own chart                       |
//+------------------------------------------------------------------+
void CloseOtherCharts() {
    if (!InputShouldCloseAllCharts) {
        return;
    }

    long myChart = ChartID();
    long chartIds[];
    ArrayFree(chartIds);

    long chartId = ChartFirst();
    while(chartId >= 0) {
        if (chartId != myChart) {
#ifdef __MQL5__
            string eaName = ChartGetString(chartId, CHART_EXPERT_NAME);
            if (eaName != "ShowMyTrades") {
                int size = ArraySize(chartIds);
                ArrayResize(chartIds, size + 1);
                chartIds[size] = chartId;
            }
#else
            // MQL4 does not support checking EA names on other charts natively
            int size = ArraySize(chartIds);
            ArrayResize(chartIds, size + 1);
            chartIds[size] = chartId;
#endif
        }
        chartId = ChartNext(chartId);
        if (chartId == -1) break;
    }

    int total = ArraySize(chartIds);
    for (int i = 0; i < total; i++) {
        long currentId = chartIds[i];
        
        // Save chart template
        string symbol = ChartSymbol(currentId);
        ENUM_TIMEFRAMES period = ChartPeriod(currentId);
        string periodStr = EnumToString(period);
        string timeStr = IntegerToString(TimeCurrent());
        string tmplName = StringFormat("PropMarshal_%s_%s_%s_%I64u.tpl", timeStr, symbol, periodStr, currentId);
        
        if (ChartSaveTemplate(currentId, tmplName)) {
            PrintPP(StringFormat("Saved template '%s' for chart %I64u", tmplName, currentId));
            
            int size = ArraySize(ClosedCharts);
            ArrayResize(ClosedCharts, size + 1);
            ClosedCharts[size].symbol = symbol;
            ClosedCharts[size].period = period;
            ClosedCharts[size].templateName = tmplName;
        } else {
            PrintAndAlertPP(StringFormat("Failed to save template for chart %s %s %I64u", symbol, periodStr, currentId));
        }
        
        // Close chart
        ChartClose(currentId);
    }
}

//+------------------------------------------------------------------+
//| Restore closed charts                                            |
//+------------------------------------------------------------------+
void RestoreClosedCharts() {
    int total = ArraySize(ClosedCharts);
    for (int i = 0; i < total; i++) {
        long newChart = ChartOpen(ClosedCharts[i].symbol, ClosedCharts[i].period);
        if (newChart > 0) {
            if (ChartApplyTemplate(newChart, ClosedCharts[i].templateName)) {
                PrintPP(StringFormat("Restored template '%s' for %s", ClosedCharts[i].templateName, ClosedCharts[i].symbol));
            } else {
                PrintAndAlertPP(StringFormat("Failed to apply template '%s'", ClosedCharts[i].templateName));
            }
        }
    }
    ArrayResize(ClosedCharts, 0);
    UpdateGUI();
}

void PrintPP(string message) {
    message = "PropMarshal: " + message;
    Print(message);
}

void PrintAndAlertPP(string message) {
    message = "PropMarshal: " + message;
    Print(message);
    Alert(message);
}

//+------------------------------------------------------------------+
//| OnChartEvent — Handles UI clicks                                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) { 
    if (id == CHARTEVENT_OBJECT_CLICK) {
        if (sparam == "PropM_BtnRestore") {
            RestoreClosedCharts();
        }
    }
}
