//+------------------------------------------------------------------+
//|                            gui.mqh                               |
//|               Drawdown Protection Expert Advisor                 |
//+------------------------------------------------------------------+
#property strict

#define CLR_BG          C'18,18,28'    // #12121C
#define CLR_HEADER_BG   C'30,30,45'    // slightly lighter for header
#define CLR_TXT_DEFAULT C'185,185,205' // Lighter #B9B9CD
#define CLR_TXT_DISABLED C'50,50,65'   // Darker #323241
#define CLR_UI_ACCENT   C'75,75,92'    // #4B4B5C (Title, Header, Border)

//+------------------------------------------------------------------+
//| Update GUI                                                       |
//+------------------------------------------------------------------+
void UpdateGUI() {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    string currency = GetCurrencySymbol();

    double dailyLimit    = GetEffectiveLimit(InputDailyDrawdownLimit, InputDailyDrawdownMode, StartDayBalanceOrEquity);
    double trailingLimit = GetEffectiveLimit(InputTrailingDrawdownLimit, InputTrailingDrawdownMode, HighestBalance);
    double staticLimit   = GetEffectiveLimit(InputStaticDrawdownLimit, InputStaticDrawdownMode, InitialBalance);

    // --- Section Enable Flags
    bool isDailyActive    = (InputDailyDrawdownMode != MODE_DISABLED && InputDailyDrawdownLimit > 0);
    bool isTrailingActive = (InputTrailingDrawdownMode != MODE_DISABLED && InputTrailingDrawdownLimit > 0);
    bool isStaticActive   = (InputStaticDrawdownMode != MODE_DISABLED && InputStaticDrawdownLimit > 0);
    bool isProfitActive   = (InputProfitTargetMode != MODE_DISABLED && InputProfitTargetLimit > 0);
    bool isRecoveryActive = (InputRecoveryMode != MODE_DISABLED && InputRecoveryLimit > 0);

    color activeLblClr = CLR_TXT_DEFAULT;
    color inactiveLblClr = CLR_TXT_DISABLED;

    // --- Recovery Info
    string recoveryStr = "n/a";
    if (isRecoveryActive) {
        recoveryStr = (InputRecoveryMode == MODE_PERCENT) ? StringFormat("%.1f%% buffer", InputRecoveryLimit) : StringFormat("%.1f%s buffer", InputRecoveryLimit, currency);
    }

    // --- Daily Infos
    double dailyDiff = StartDayBalanceOrEquity - equity; 
    double dailyDDPct = (StartDayBalanceOrEquity > 0) ? (dailyDiff / StartDayBalanceOrEquity) * 100.0 : 0.0;
    string dailyDDStr = "n/a";
    if (isDailyActive) {
        if (InputDailyDrawdownMode == MODE_PERCENT) {
            dailyDDStr = StringFormat("%.1f%% / %.1f%%", dailyDDPct, dailyLimit);
            if (dailyLimit != InputDailyDrawdownLimit) dailyDDStr += StringFormat(" (%.1f%%)", InputDailyDrawdownLimit);
        }
        else if (InputDailyDrawdownMode == MODE_CURRENCY) {
            dailyDDStr = StringFormat("%.1f%s / %.1f%s", dailyDiff, currency, dailyLimit, currency);
            if (dailyLimit != InputDailyDrawdownLimit) dailyDDStr += StringFormat(" (%.1f%s)", InputDailyDrawdownLimit, currency);
        }
    }

    double dailyValue = (InputDailyDrawdownMode == MODE_PERCENT) ? dailyDDPct : dailyDiff;
    double dailyRatio = (isDailyActive) ? (dailyValue / dailyLimit) : 0;
    color dailyClr = clrLimeGreen;
    if (!isDailyActive) dailyClr = CLR_TXT_DISABLED;
    else if (dailyRatio >= 1.0) dailyClr = clrRed;
    else if (dailyRatio >= 0.7) dailyClr = clrOrange;
    else if (dailyRatio >= 0.5) dailyClr = clrYellow;

    // --- Static Infos
    double staticDiff = InitialBalance - equity;
    double staticDDPct = (InitialBalance > 0) ? (staticDiff / InitialBalance) * 100.0 : 0.0;
    string staticDDStr = "n/a";
    if (isStaticActive) {
        if (InputStaticDrawdownMode == MODE_PERCENT) {
            staticDDStr = StringFormat("%.1f%% / %.1f%%", staticDDPct, staticLimit);
            if (staticLimit != InputStaticDrawdownLimit) staticDDStr += StringFormat(" (%.1f%%)", InputStaticDrawdownLimit);
        }
        else if (InputStaticDrawdownMode == MODE_CURRENCY) {
            staticDDStr = StringFormat("%.1f%s / %.1f%s", staticDiff, currency, staticLimit, currency);
            if (staticLimit != InputStaticDrawdownLimit) staticDDStr += StringFormat(" (%.1f%s)", InputStaticDrawdownLimit, currency);
        }
    }

    double staticValue = (InputStaticDrawdownMode == MODE_PERCENT) ? staticDDPct : staticDiff;
    double staticRatio = (isStaticActive) ? (staticValue / staticLimit) : 0;
    color staticClr = clrLimeGreen;
    if (!isStaticActive) staticClr = CLR_TXT_DISABLED;
    else if (staticRatio >= 1.0) staticClr = clrRed;
    else if (staticRatio >= 0.7) staticClr = clrOrange;
    else if (staticRatio >= 0.5) staticClr = clrYellow;

    // --- Trailing Infos
    double trailingDiff = HighestBalance - equity;
    double trailingDDPct = (HighestBalance > 0) ? (trailingDiff / HighestBalance) * 100.0 : 0.0;
    string trailingDDStr = "n/a";
    if (isTrailingActive) {
        if (InputTrailingDrawdownMode == MODE_PERCENT) {
            trailingDDStr = StringFormat("%.1f%% / %.1f%%", trailingDDPct, trailingLimit);
            if (trailingLimit != InputTrailingDrawdownLimit) trailingDDStr += StringFormat(" (%.1f%%)", InputTrailingDrawdownLimit);
        }
        else if (InputTrailingDrawdownMode == MODE_CURRENCY) {
            trailingDDStr = StringFormat("%.1f%s / %.1f%s", trailingDiff, currency, trailingLimit, currency);
            if (trailingLimit != InputTrailingDrawdownLimit) trailingDDStr += StringFormat(" (%.1f%s)", InputTrailingDrawdownLimit, currency);
        }
    }

    double trailingValue = (InputTrailingDrawdownMode == MODE_PERCENT) ? trailingDDPct : trailingDiff;
    double trailingRatio = (isTrailingActive) ? (trailingValue / trailingLimit) : 0;
    color trailingClr = clrLimeGreen;
    if (!isTrailingActive) trailingClr = CLR_TXT_DISABLED;
    else if (trailingRatio >= 1.0) trailingClr = clrRed;
    else if (trailingRatio >= 0.7) trailingClr = clrOrange;
    else if (trailingRatio >= 0.5) trailingClr = clrYellow;

    // --- Profit Target
    double profitDiff = equity - InitialBalance;
    double profitPct = (InitialBalance > 0) ? (profitDiff / InitialBalance) * 100.0 : 0.0;
    string profitStr = "n/a";
    if (isProfitActive) {
        if (InputProfitTargetMode == MODE_PERCENT)
            profitStr = StringFormat("%.1f%% / %.1f%%", profitPct, InputProfitTargetLimit);
        else if (InputProfitTargetMode == MODE_CURRENCY)
            profitStr = StringFormat("%.1f%s / %.1f%s", profitDiff, currency, InputProfitTargetLimit, currency);
    }
    double profitValue = (InputProfitTargetMode == MODE_PERCENT) ? profitPct : profitDiff;
    double profitRatio = (isProfitActive) ? (profitValue / InputProfitTargetLimit) : 0;
    color profitClr = CLR_TXT_DEFAULT;
    if (!isProfitActive) profitClr = CLR_TXT_DISABLED;
    else if (profitRatio >= 1.0) profitClr = clrLimeGreen;

    string closeChartsStr = InputShouldCloseAllCharts ? "Yes" : "No";

    // --- Layout Constants
#ifdef __MQL5__
    int panelW = 800; 
    int panelX = 60; 
    int panelY = 60; 
    int startX = panelX + 30; 
    int valX   = panelX + panelW - 30; 
    int currY  = panelY;
    int lineHeight = 32; 
    int sectionSpacing = 45; 
    int totalH = 900; 
    int headerH = 70;
    int titleOffset = 20;
    int initialMargin = 90; 
#else
    int panelW = 400; 
    int panelX = 30; 
    int panelY = 30; 
    int startX = panelX + 15; 
    int valX   = panelX + panelW - 15; 
    int currY  = panelY;
    int lineHeight = 16; 
    int sectionSpacing = 22; 
    int totalH = 450; 
    int headerH = 35;
    int titleOffset = 10;
    int initialMargin = 45; 
#endif

    // Draw main background and initial header
    DrawRect("BG", panelX, panelY, panelW, totalH, CLR_BG, CLR_UI_ACCENT);
    DrawRect("Header", panelX, panelY, panelW, headerH, CLR_HEADER_BG, CLR_UI_ACCENT); 
    DrawLabel("Title", panelX + (panelW/2), panelY + titleOffset, "PROP MARSHAL", 11, clrWhite, true, ANCHOR_UPPER);
    
    currY += initialMargin; 

    // --- Recovery Section
    string recoveryHead = "RECOVERY BUFFER";
    color recoveryHeadClr = CLR_UI_ACCENT;
    if (!isRecoveryActive) {
        recoveryHead += " (disabled)";
        recoveryHeadClr = CLR_TXT_DISABLED;
    }
#ifdef __MQL5__
    DrawLabel("RecoveryHead", startX, currY, recoveryHead, 11, recoveryHeadClr, true); currY += lineHeight + 8;
#else
    DrawLabel("RecoveryHead", startX, currY, recoveryHead, 11, recoveryHeadClr, true); currY += lineHeight + 3;
#endif
    
    if (isRecoveryActive) {
        DrawLabel("Recovery1L", startX, currY, "Active buffer:", 9, activeLblClr, false);
        DrawLabelRight("Recovery1V", valX, currY, recoveryStr, 9, activeLblClr, false); currY += sectionSpacing;
    } else {
        ObjectDelete(0, "PropM_Recovery1L");
        ObjectDelete(0, "PropM_Recovery1V");
#ifdef __MQL5__
        currY += 8; 
#else
        currY += 3; 
#endif
    }

    // --- Daily Section
#ifdef __MQL5__
    currY += 24; // Extra margin before border
    DrawRect("Sep1", panelX + 20, currY - 23, panelW - 40, 1, CLR_UI_ACCENT, CLR_UI_ACCENT);
#else
    currY += 12; // Extra margin before border
    DrawRect("Sep1", panelX + 10, currY - 12, panelW - 20, 1, CLR_UI_ACCENT, CLR_UI_ACCENT);
#endif
    
    string dailyHead = "DAILY DRAWDOWN";
    color dailyHeadClr = CLR_UI_ACCENT;
    if (!isDailyActive) {
        dailyHead += " (disabled)";
        dailyHeadClr = CLR_TXT_DISABLED;
    }
    
    datetime nowInZone = TimeGMT() + (InputGmtOffset * 3600);
    MqlDateTime dt;
    TimeToStruct(nowInZone, dt);
    dt.hour = 0; dt.min = 0; dt.sec = 0;
    datetime nextReset = StructToTime(dt) + 86400;
    long diff = (long)nextReset - (long)nowInZone;
    string resetTimeStr = isDailyActive ? StringFormat("%02d:%02d:%02d", (int)(diff/3600), (int)((diff%3600)/60), (int)(diff%60)) : "n/a";

#ifdef __MQL5__
    DrawLabel("DailyHead", startX, currY, dailyHead, 11, dailyHeadClr, true); currY += lineHeight + 8;
#else
    DrawLabel("DailyHead", startX, currY, dailyHead, 11, dailyHeadClr, true); currY += lineHeight + 3;
#endif
    
    if (isDailyActive) {
        DrawLabel("Daily1L", startX, currY, "Start of day balance:", 9, activeLblClr, false);
        DrawLabelRight("Daily1V", valX, currY, StringFormat("%.1f%s", StartDayBalanceOrEquity, currency), 9, activeLblClr, false); currY += lineHeight;
        DrawLabel("DailyResetL", startX, currY, "Daily reset in:", 9, activeLblClr, false);
        DrawLabelRight("DailyResetV", valX, currY, resetTimeStr, 9, activeLblClr, false); currY += lineHeight;
        DrawLabel("Daily2L", startX, currY, "Current drawdown:", 9, activeLblClr, false);
        DrawLabelRight("Daily2V", valX, currY, dailyDDStr, 9, dailyClr, false); currY += sectionSpacing;
    } else {
        ObjectDelete(0, "PropM_Daily1L"); ObjectDelete(0, "PropM_Daily1V");
        ObjectDelete(0, "PropM_DailyResetL"); ObjectDelete(0, "PropM_DailyResetV");
        ObjectDelete(0, "PropM_Daily2L"); ObjectDelete(0, "PropM_Daily2V");
#ifdef __MQL5__
        currY += 8;
#else
        currY += 3;
#endif
    }

    // --- Trailing Section
#ifdef __MQL5__
    currY += 24; // Extra margin before border
    DrawRect("Sep2", panelX + 20, currY - 23, panelW - 40, 1, CLR_UI_ACCENT, CLR_UI_ACCENT);
#else
    currY += 12; // Extra margin before border
    DrawRect("Sep2", panelX + 10, currY - 12, panelW - 20, 1, CLR_UI_ACCENT, CLR_UI_ACCENT);
#endif
    
    string trailingHead = "TRAILING DRAWDOWN";
    color trailingHeadClr = CLR_UI_ACCENT;
    if (!isTrailingActive) {
        trailingHead += " (disabled)";
        trailingHeadClr = CLR_TXT_DISABLED;
    }
#ifdef __MQL5__
    DrawLabel("TrailingHead", startX, currY, trailingHead, 11, trailingHeadClr, true); currY += lineHeight + 8;
#else
    DrawLabel("TrailingHead", startX, currY, trailingHead, 11, trailingHeadClr, true); currY += lineHeight + 3;
#endif
    
    if (isTrailingActive) {
        DrawLabel("Trailing1L", startX, currY, "Highest balance:", 9, activeLblClr, false);
        DrawLabelRight("Trailing1V", valX, currY, StringFormat("%.1f%s", HighestBalance, currency), 9, activeLblClr, false); currY += lineHeight;
        DrawLabel("Trailing2L", startX, currY, "Current drawdown:", 9, activeLblClr, false);
        DrawLabelRight("Trailing2V", valX, currY, trailingDDStr, 9, trailingClr, false); currY += sectionSpacing;
    } else {
        ObjectDelete(0, "PropM_Trailing1L"); ObjectDelete(0, "PropM_Trailing1V");
        ObjectDelete(0, "PropM_Trailing2L"); ObjectDelete(0, "PropM_Trailing2V");
#ifdef __MQL5__
        currY += 8;
#else
        currY += 3;
#endif
    }

    // --- Static Section
#ifdef __MQL5__
    currY += 24; // Extra margin before border
    DrawRect("Sep3", panelX + 20, currY - 23, panelW - 40, 1, CLR_UI_ACCENT, CLR_UI_ACCENT);
#else
    currY += 12; // Extra margin before border
    DrawRect("Sep3", panelX + 10, currY - 12, panelW - 20, 1, CLR_UI_ACCENT, CLR_UI_ACCENT);
#endif
    
    string staticHead = "STATIC DRAWDOWN";
    color staticHeadClr = CLR_UI_ACCENT;
    if (!isStaticActive) {
        staticHead += " (disabled)";
        staticHeadClr = CLR_TXT_DISABLED;
    }
#ifdef __MQL5__
    DrawLabel("StaticHead", startX, currY, staticHead, 11, staticHeadClr, true); currY += lineHeight + 8;
#else
    DrawLabel("StaticHead", startX, currY, staticHead, 11, staticHeadClr, true); currY += lineHeight + 3;
#endif
    
    if (isStaticActive) {
        DrawLabel("Static1L", startX, currY, "Initial balance:", 9, activeLblClr, false);
        DrawLabelRight("Static1V", valX, currY, StringFormat("%.1f%s", InitialBalance, currency), 9, activeLblClr, false); currY += lineHeight;
        DrawLabel("Static2L", startX, currY, "Current drawdown:", 9, activeLblClr, false);
        DrawLabelRight("Static2V", valX, currY, staticDDStr, 9, staticClr, false); currY += sectionSpacing;
    } else {
        ObjectDelete(0, "PropM_Static1L"); ObjectDelete(0, "PropM_Static1V");
        ObjectDelete(0, "PropM_Static2L"); ObjectDelete(0, "PropM_Static2V");
#ifdef __MQL5__
        currY += 8;
#else
        currY += 3;
#endif
    }

    // --- Profit Section
#ifdef __MQL5__
    currY += 24; // Extra margin before border
    DrawRect("Sep4", panelX + 20, currY - 23, panelW - 40, 1, CLR_UI_ACCENT, CLR_UI_ACCENT);
#else
    currY += 12; // Extra margin before border
    DrawRect("Sep4", panelX + 10, currY - 12, panelW - 20, 1, CLR_UI_ACCENT, CLR_UI_ACCENT);
#endif
    
    string profitHead = "PROFIT TARGET";
    color profitHeadClr = CLR_UI_ACCENT;
    if (!isProfitActive) {
        profitHead += " (disabled)";
        profitHeadClr = CLR_TXT_DISABLED;
    }
#ifdef __MQL5__
    DrawLabel("ProfitHead", startX, currY, profitHead, 11, profitHeadClr, true); currY += lineHeight + 8;
#else
    DrawLabel("ProfitHead", startX, currY, profitHead, 11, profitHeadClr, true); currY += lineHeight + 3;
#endif
    
    if (isProfitActive) {
        DrawLabel("Profit1L", startX, currY, "Target:", 9, activeLblClr, false);
        DrawLabelRight("Profit1V", valX, currY, profitStr, 9, profitClr, false); currY += sectionSpacing;
    } else {
        ObjectDelete(0, "PropM_Profit1L"); ObjectDelete(0, "PropM_Profit1V");
#ifdef __MQL5__
        currY += 8;
#else
        currY += 3;
#endif
    }

    // --- Others Section
#ifdef __MQL5__
    currY += 24; // Extra margin before border
    DrawRect("Sep5", panelX + 20, currY - 23, panelW - 40, 1, CLR_UI_ACCENT, CLR_UI_ACCENT);
#else
    currY += 12; // Extra margin before border
    DrawRect("Sep5", panelX + 10, currY - 12, panelW - 20, 1, CLR_UI_ACCENT, CLR_UI_ACCENT);
#endif
    DrawLabel("OtherHead", startX, currY, "SETTINGS", 11, CLR_UI_ACCENT, true); 
#ifdef __MQL5__
    currY += lineHeight + 8;
#else
    currY += lineHeight + 3;
#endif
    DrawLabel("Other1L", startX, currY, "Close all charts:", 9, CLR_TXT_DEFAULT, false);
    DrawLabelRight("Other1V", valX, currY, closeChartsStr, 9, CLR_TXT_DEFAULT, false); currY += lineHeight;

    if (ArraySize(ClosedCharts) > 0) {
#ifdef __MQL5__
        DrawButton("BtnRestore", startX, currY, "Restore " + IntegerToString(ArraySize(ClosedCharts)) + " closed chart(s)", panelW - 60, 48, 9);
        currY += 65;
#else
        DrawButton("BtnRestore", startX, currY, "Restore " + IntegerToString(ArraySize(ClosedCharts)) + " closed chart(s)", panelW - 30, 24, 9);
        currY += 32;
#endif
    } else {
        if(ObjectFind(0, "PropM_BtnRestore") >= 0) ObjectDelete(0, "PropM_BtnRestore");
    }

    // Adjust total height
    int finalH = currY - panelY + 10;
    ObjectSetInteger(0, "PropM_BG", OBJPROP_YSIZE, finalH);
   
    ChartRedraw();
}

void DeleteGUI() {
    ObjectsDeleteAll(0, "PropM_");
    ChartRedraw();
}

void DrawLabel(string id, int x, int y, string text, int fontSize = 9, color clr = clrWhite, bool isBold = false, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER) {
    string objName = "PropM_" + id;
    if(ObjectFind(0, objName) < 0) {
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
        ObjectSetString(0,  objName, OBJPROP_FONT, isBold ? "Calibri bold" : "Calibri");
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    }
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
}

void DrawLabelRight(string id, int x, int y, string text, int fontSize = 9, color clr = clrWhite, bool isBold = false) {
    string objName = "PropM_" + id;
    if(ObjectFind(0, objName) < 0) {
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
        ObjectSetString(0,  objName, OBJPROP_FONT, isBold ? "Calibri bold" : "Calibri");
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    }
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
}

void DrawButton(string id, int x, int y, string text, int w = 310, int h = 30, int fontSize = 9, color clr = clrWhite, color bgClr = CLR_HEADER_BG) {
    string objName = "PropM_" + id;
    if(ObjectFind(0, objName) < 0) {
        ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
        ObjectSetString(0,  objName, OBJPROP_FONT, "Calibri");
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgClr);
        ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, CLR_UI_ACCENT);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
        ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
    }
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, objName, OBJPROP_STATE, false);
}

void DrawRect(string id, int x, int y, int w, int h, color bgClr, color borderClr) {
    string objName = "PropM_" + id;
    if(ObjectFind(0, objName) < 0) {
        ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_BACK, false);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
    }
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgClr);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, borderClr);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
}
