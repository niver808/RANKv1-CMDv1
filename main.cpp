#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <dwmapi.h>
#include <tlhelp32.h>
#include <string>
#include <vector>
#include <mutex>
#include <thread>
#include <cstdio>

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif

// ============================================================================
// COLOR PALETTE
// ============================================================================
static const COLORREF C_BG      = RGB(6, 5, 8);
static const COLORREF C_WHITE   = RGB(215, 215, 220);
static const COLORREF C_GREEN   = RGB(40, 200, 75);
static const COLORREF C_DIM     = RGB(75, 75, 88);
static const COLORREF C_ORAN    = RGB(255, 80, 20);
static const COLORREF C_SPINNER = RGB(255, 70, 20);

static const COLORREF LOGO_COLORS[7] = {
    RGB(255, 120, 120),
    RGB(255, 75, 75),
    RGB(240, 45, 45),
    RGB(215, 25, 25),
    RGB(185, 12, 12),
    RGB(145, 5, 5),
    RGB(100, 2, 2)
};

// ============================================================================
// CONSTANTS & STRINGS (\u escapes for MSVC /utf-8 safety)
// ============================================================================
static const int WIN_W = 630;
static const int WIN_H = 560;

static const UINT_PTR TIMER_TITLE   = 1;
static const UINT_PTR TIMER_BLINK   = 2;
static const UINT_PTR TIMER_SPINNER = 3;

enum AppState {
    S_MENU = 0,
    S_RUN  = 1,
    S_DONE = 2
};

static const wchar_t* TITLE_PHRASES[5] = {
    L"RANK1 | \u30E9\u30F3\u30AF1\u30B7\u30E7\u30C3\u30D7\u3088\u308A\u611B\u3092\u8FBC\u3081\u3066 \u2665",
    L"RANK1 | \u611B\u3057\u3066\u308B\u3001\u30E9\u30F3\u30AF1 \u2665",
    L"RANK1 | rank1shop \u304B\u3089\u3042\u306A\u305F\u3078 \u2665",
    L"RANK1 | \u6C38\u9060\u306B\u3042\u308A\u304C\u3068\u3046 \u2665 rank1shop",
    L"RANK1 | \u6700\u9AD8\u306E\u30C4\u30FC\u30EB\u3001\u6700\u9AD8\u306E\u611B \u2665"
};

// Block art characters:
// \u2588 = █, \u2593 = ▓, \u2592 = ▒, \u2591 = ░
// \u2580 = ▀, \u2584 = ▄, \u258C = ▌, \u2590 = ▐
static const wchar_t* LOGO_LINES[7] = {
    L"\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2584 \u2584\u2588\u2588\u2588\u2588\u2588\u2588\u2584 \u2588\u2588\u2588\u2584 \u2588\u2588\u2588\u2588 \u2588\u2588\u2588\u2588 \u2588\u2588\u2588\u2588 \u2588\u2588\u2588\u2588",
    L"\u2588\u2588\u2588\u2588 \u2580\u2588\u2588\u2588\u258C \u258C\u2593\u2588\u2593\u2588 \u2588\u2588\u2593\u258C \u2588\u2588\u2593\u2588\u2588\u2584\u2588\u2588\u2593 \u2588\u2588\u2593\u2588 \u2584\u2588\u2588\u2593\u2580 \u2588\u2588\u2593\u2588",
    L"\u2592\u2593\u2588\u2588\u2584\u2593\u2588\u2593\u2580 \u2592\u2593\u2588\u2593\u2593\u2580\u2592\u2588\u2593 \u2592\u2593\u2588\u2593 \u2580\u2592\u2588\u2593 \u2592\u2593\u2588\u2593\u2580\u2592\u2593\u2584 \u2592\u2593\u2588\u2593",
    L"\u2591\u2591\u2592\u2593\u2580\u2593\u2592\u2592\u2593\u2584 \u2591\u2591\u2592\u2593 \u2591\u2591\u2592\u2593 \u2591\u2591\u2592\u2593 \u2591\u2591\u2592\u2593 \u2591\u2591\u2592\u2593 \u2591\u2591\u2592\u2593",
    L" \u2591 \u2591\u2591\u2592\u2591\u258C \u2591 \u2591 \u2591 \u2591 \u2591 \u2591 \u2591",
    L" \u2580 \u2580 \u2580\u2580\u2580\u2580 \u2580\u2580\u2580\u2580 \u2580\u2580\u2580\u2580 \u2580\u2580\u2580\u2580 \u2580\u2580\u2580\u2580",
    L" \u2580 "
};

static const wchar_t* TARGET_PROCESSES[] = {
    L"FiveM_GTAProcess.exe",
    L"FiveM_b2060_GTAProcess.exe",
    L"FiveM_b2189_GTAProcess.exe",
    L"FiveM_b2372_GTAProcess.exe",
    L"FiveM_b2545_GTAProcess.exe",
    L"FiveM_b2612_GTAProcess.exe",
    L"FiveM_b2699_GTAProcess.exe",
    L"FiveM_b2802_GTAProcess.exe",
    L"FiveM_b2944_GTAProcess.exe",
    L"FiveM_b3095_GTAProcess.exe",
    L"FiveM_b3179_GTAProcess.exe",
    L"FiveM_b3258_GTAProcess.exe",
    L"FiveM_b3323_GTAProcess.exe",
    L"FiveM_b3407_GTAProcess.exe",
    L"FiveM_b3411_GTAProcess.exe",
    L"FiveM_b3751_GTAProcess.exe"
};

// ============================================================================
// AOB PATCH DEFINITION
// ============================================================================
struct AobPatch {
    const wchar_t* name;
    BYTE search[16];
    int searchLen;
    BYTE patch[16];
    int patchLen;
    BYTE orig[16];
    bool hasOrig;
    std::vector<LPVOID> addrs;
};

static AobPatch g_aobs[2] = {
    {
        L"AOB_1",
        { 0xCD, 0xCC, 0x94, 0x40, 0x01, 0x00, 0x00, 0x00 },
        8,
        { 0x77, 0x77, 0x97, 0x40, 0x01, 0x00, 0x00, 0x00 },
        8,
        { 0 },
        false,
        {}
    },
    {
        L"AOB_2",
        { 0x77, 0x77, 0x97, 0x40, 0x01, 0x00, 0x00, 0x00 },
        8,
        { 0xCD, 0xCC, 0x94, 0x40, 0x01, 0x00, 0x00, 0x00 },
        8,
        { 0 },
        false,
        {}
    }
};

// ============================================================================
// GLOBALS
// ============================================================================
static HWND g_hwnd = nullptr;
static HFONT g_fLogo  = nullptr;
static HFONT g_fMenu  = nullptr;
static HFONT g_fSmall = nullptr;
static HFONT g_fTiny  = nullptr;

static AppState g_state = S_MENU;
static int g_activeMode = 0; // 1 = INSTALL, 2 = RESET
static int g_titleIdx = 0;
static bool g_blinkOn = true;
static int g_spinnerIdx = 0;

static std::mutex g_logMutex;
static std::vector<std::wstring> g_logs;
static std::thread g_worker;

// ============================================================================
// FONT & GDI HELPERS
// ============================================================================
static HFONT MakeCourierFont(int ptSize, int weight) {
    HDC hdc = GetDC(nullptr);
    int dpi = hdc ? GetDeviceCaps(hdc, LOGPIXELSY) : 96;
    if (hdc) ReleaseDC(nullptr, hdc);
    int height = -MulDiv(ptSize, dpi, 72);
    return CreateFontW(
        height,
        0,
        0,
        0,
        weight,
        FALSE,
        FALSE,
        FALSE,
        DEFAULT_CHARSET,
        OUT_DEFAULT_PRECIS,
        CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY,
        FIXED_PITCH | FF_MODERN,
        L"Courier New"
    );
}

static void HLineRange(HDC dc, int x1, int x2, int y, int thickness, COLORREF color) {
    if (x2 < x1) return;
    HPEN pen = CreatePen(PS_SOLID, thickness, color);
    if (!pen) return;
    HGDIOBJ old = SelectObject(dc, pen);
    if (thickness <= 1) {
        MoveToEx(dc, x1, y, nullptr);
        LineTo(dc, x2 + 1, y);
    } else {
        for (int i = 0; i < thickness; ++i) {
            MoveToEx(dc, x1, y + i, nullptr);
            LineTo(dc, x2 + 1, y + i);
        }
    }
    SelectObject(dc, old);
    DeleteObject(pen);
}

static void DrawCenteredText(HDC dc, HFONT font, int y, const std::wstring& text, COLORREF color) {
    SetBkMode(dc, TRANSPARENT);
    HGDIOBJ oldFont = SelectObject(dc, font);
    SIZE sz = { 0, 0 };
    GetTextExtentPoint32W(dc, text.c_str(), static_cast<int>(text.size()), &sz);
    int x = (WIN_W - sz.cx) / 2;
    SetTextColor(dc, color);
    TextOutW(dc, x, y, text.c_str(), static_cast<int>(text.size()));
    SelectObject(dc, oldFont);
}

static void DrawGlowCenteredText(HDC dc, HFONT font, int y, const std::wstring& text, COLORREF mainColor, COLORREF shadowColor) {
    SetBkMode(dc, TRANSPARENT);
    HGDIOBJ oldFont = SelectObject(dc, font);
    SIZE sz = { 0, 0 };
    GetTextExtentPoint32W(dc, text.c_str(), static_cast<int>(text.size()), &sz);
    int x = (WIN_W - sz.cx) / 2;

    SetTextColor(dc, shadowColor);
    TextOutW(dc, x + 1, y + 1, text.c_str(), static_cast<int>(text.size()));

    SetTextColor(dc, mainColor);
    TextOutW(dc, x, y, text.c_str(), static_cast<int>(text.size()));
    SelectObject(dc, oldFont);
}

static void AppendLog(const std::wstring& line) {
    {
        std::lock_guard<std::mutex> lock(g_logMutex);
        g_logs.push_back(line);
    }
    if (g_hwnd && IsWindow(g_hwnd)) {
        InvalidateRect(g_hwnd, nullptr, FALSE);
    }
}

static void ClearLogs() {
    std::lock_guard<std::mutex> lock(g_logMutex);
    g_logs.clear();
}

// ============================================================================
// PROCESS FINDER
// ============================================================================
static HANDLE OpenTarget() {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) {
        return nullptr;
    }

    PROCESSENTRY32W pe;
    pe.dwSize = sizeof(pe);
    DWORD foundPid = 0;

    if (Process32FirstW(snap, &pe)) {
        do {
            for (const wchar_t* target : TARGET_PROCESSES) {
                if (_wcsicmp(pe.szExeFile, target) == 0) {
                    foundPid = pe.th32ProcessID;
                    break;
                }
            }
            if (foundPid != 0) break;
        } while (Process32NextW(snap, &pe));
    }

    CloseHandle(snap);

    if (foundPid == 0) {
        return nullptr;
    }

    return OpenProcess(PROCESS_ALL_ACCESS, FALSE, foundPid);
}

// ============================================================================
// AOB SCANNER & PATCHER
// ============================================================================
static std::vector<LPVOID> ScanAobAll(HANDLE hp, const BYTE* pat, int plen) {
    std::vector<LPVOID> matches;
    if (!hp || !pat || plen <= 0) return matches;

    SYSTEM_INFO si;
    GetSystemInfo(&si);

    const BYTE* minAddr = static_cast<const BYTE*>(si.lpMinimumApplicationAddress);
    const BYTE* maxAddr = static_cast<const BYTE*>(si.lpMaximumApplicationAddress);
    const SIZE_T CHUNK_SIZE = 0x10000;
    std::vector<BYTE> buf(CHUNK_SIZE + static_cast<SIZE_T>(plen));

    const BYTE* cur = minAddr;
    while (cur < maxAddr) {
        MEMORY_BASIC_INFORMATION mbi;
        if (VirtualQueryEx(hp, cur, &mbi, sizeof(mbi)) == 0) {
            break;
        }

        const BYTE* regionStart = static_cast<const BYTE*>(mbi.BaseAddress);
        SIZE_T regionSize = mbi.RegionSize;

        bool scannable = (mbi.State == MEM_COMMIT) &&
                         ((mbi.Protect & PAGE_GUARD) == 0) &&
                         ((mbi.Protect & PAGE_NOACCESS) == 0) &&
                         ((mbi.Protect & PAGE_EXECUTE_READ) ||
                          (mbi.Protect & PAGE_EXECUTE_READWRITE) ||
                          (mbi.Protect & PAGE_READWRITE));

        if (scannable && regionSize >= static_cast<SIZE_T>(plen)) {
            SIZE_T offset = 0;
            while (offset < regionSize) {
                SIZE_T remaining = regionSize - offset;
                SIZE_T toRead = (remaining < CHUNK_SIZE) ? remaining : CHUNK_SIZE;
                SIZE_T overlap = 0;
                if (offset + toRead < regionSize && remaining > toRead) {
                    SIZE_T extra = remaining - toRead;
                    overlap = (extra < static_cast<SIZE_T>(plen - 1)) ? extra : static_cast<SIZE_T>(plen - 1);
                }

                SIZE_T bytesRead = 0;
                if (ReadProcessMemory(hp, regionStart + offset, buf.data(), toRead + overlap, &bytesRead) &&
                    bytesRead >= static_cast<SIZE_T>(plen)) {
                    for (SIZE_T i = 0; i + static_cast<SIZE_T>(plen) <= bytesRead; ) {
                        bool eq = true;
                        for (int j = 0; j < plen; ++j) {
                            if (buf[i + static_cast<SIZE_T>(j)] != pat[j]) {
                                eq = false;
                                break;
                            }
                        }
                        if (eq) {
                            matches.push_back(const_cast<BYTE*>(regionStart + offset + i));
                            i += static_cast<SIZE_T>(plen - 1);
                        } else {
                            ++i;
                        }
                    }
                }

                offset += toRead;
            }
        }

        const BYTE* next = regionStart + regionSize;
        if (next <= cur) break;
        cur = next;
    }

    return matches;
}

static void PatchAll(HANDLE hp, AobPatch& p, const BYTE* bytes, int len) {
    if (!hp || !bytes || len <= 0 || len > 16) return;

    for (size_t idx = 0; idx < p.addrs.size(); ++idx) {
        LPVOID addr = p.addrs[idx];
        if (idx == 0 && !p.hasOrig) {
            SIZE_T readBytes = 0;
            if (ReadProcessMemory(hp, addr, p.orig, static_cast<SIZE_T>(len), &readBytes) &&
                readBytes == static_cast<SIZE_T>(len)) {
                p.hasOrig = true;
            }
        }

        DWORD oldProtect = 0;
        if (VirtualProtectEx(hp, addr, static_cast<SIZE_T>(len), PAGE_EXECUTE_READWRITE, &oldProtect)) {
            SIZE_T written = 0;
            WriteProcessMemory(hp, addr, bytes, static_cast<SIZE_T>(len), &written);
            DWORD dummy = 0;
            VirtualProtectEx(hp, addr, static_cast<SIZE_T>(len), oldProtect, &dummy);
        }
    }
}

// ============================================================================
// WORKER THREADS (INSTALL / RESET)
// ============================================================================
static void RunInstallWorker() {
    AppendLog(L">> opening process handle...");
    HANDLE hp = OpenTarget();
    if (!hp) {
        AppendLog(L"[!!] Error: Failed to open process handle.");
        g_state = S_DONE;
        InvalidateRect(g_hwnd, nullptr, FALSE);
        return;
    }

    AppendLog(L"[OK] process handle acquired.");
    AppendLog(L">> Step 2: Applying Memory Patches...");

    for (int i = 0; i < 2; ++i) {
        AobPatch& p = g_aobs[i];
        std::wstring scanMsg = L">> scanning: ";
        scanMsg += p.name;
        AppendLog(scanMsg);

        p.addrs = ScanAobAll(hp, p.search, p.searchLen);
        int n = static_cast<int>(p.addrs.size());
        if (n > 0) {
            PatchAll(hp, p, p.patch, p.patchLen);
            wchar_t buf[128];
            swprintf_s(buf, L"[OK] %d patch(es) applied.", n);
            AppendLog(buf);
        } else {
            AppendLog(L"[--] pattern not found (may already be patched).");
        }
    }

    AppendLog(L">> Step 5: Finalizing Synchronization...");
    AppendLog(L"*** INSTALL COMPLETE -- RANK1 ACTIVE ***");

    CloseHandle(hp);
    g_state = S_DONE;
    InvalidateRect(g_hwnd, nullptr, FALSE);
}

static void RunResetWorker() {
    AppendLog(L">> opening process handle...");
    HANDLE hp = OpenTarget();
    if (!hp) {
        AppendLog(L"[!!] Error: Failed to open process handle.");
        g_state = S_DONE;
        InvalidateRect(g_hwnd, nullptr, FALSE);
        return;
    }

    AppendLog(L"[OK] process handle acquired.");
    AppendLog(L">> Step 2: Reverting Memory Patches...");

    for (int i = 1; i >= 0; --i) {
        AobPatch& p = g_aobs[i];
        std::wstring restoreMsg = L">> restoring: ";
        restoreMsg += p.name;
        AppendLog(restoreMsg);

        if (!p.addrs.empty() && p.hasOrig) {
            int n = static_cast<int>(p.addrs.size());
            for (LPVOID addr : p.addrs) {
                DWORD oldProtect = 0;
                if (VirtualProtectEx(hp, addr, static_cast<SIZE_T>(p.patchLen), PAGE_EXECUTE_READWRITE, &oldProtect)) {
                    SIZE_T written = 0;
                    WriteProcessMemory(hp, addr, p.orig, static_cast<SIZE_T>(p.patchLen), &written);
                    DWORD dummy = 0;
                    VirtualProtectEx(hp, addr, static_cast<SIZE_T>(p.patchLen), oldProtect, &dummy);
                }
            }
            wchar_t buf[128];
            swprintf_s(buf, L"[OK] %d addr(s) restored.", n);
            AppendLog(buf);
        } else {
            std::vector<LPVOID> found = ScanAobAll(hp, p.patch, p.patchLen);
            int n = static_cast<int>(found.size());
            if (n > 0) {
                for (LPVOID addr : found) {
                    DWORD oldProtect = 0;
                    if (VirtualProtectEx(hp, addr, static_cast<SIZE_T>(p.searchLen), PAGE_EXECUTE_READWRITE, &oldProtect)) {
                        SIZE_T written = 0;
                        WriteProcessMemory(hp, addr, p.search, static_cast<SIZE_T>(p.searchLen), &written);
                        DWORD dummy = 0;
                        VirtualProtectEx(hp, addr, static_cast<SIZE_T>(p.searchLen), oldProtect, &dummy);
                    }
                }
                wchar_t buf[128];
                swprintf_s(buf, L"[OK] %d addr(s) restored via re-scan.", n);
                AppendLog(buf);
            } else {
                AppendLog(L"[--] not found.");
            }
        }
    }

    AppendLog(L">> Step 5: Finalizing Synchronization...");
    AppendLog(L"*** RESET COMPLETE -- RANK1 Cleaned Successfully ***");

    CloseHandle(hp);
    g_state = S_DONE;
    InvalidateRect(g_hwnd, nullptr, FALSE);
}

static void StartMode(int mode) {
    if (g_worker.joinable()) {
        g_worker.join();
    }
    ClearLogs();
    g_activeMode = mode;
    g_state = S_RUN;
    g_spinnerIdx = 0;
    InvalidateRect(g_hwnd, nullptr, FALSE);

    if (mode == 1) {
        g_worker = std::thread(RunInstallWorker);
    } else if (mode == 2) {
        g_worker = std::thread(RunResetWorker);
    }
}

// ============================================================================
// PAINTING
// ============================================================================
static COLORREF GetLogLineColor(const std::wstring& line) {
    if (line.rfind(L"[OK]", 0) == 0)   return C_GREEN;
    if (line.rfind(L"***", 0) == 0)    return C_ORAN;
    if (line.rfind(L"[--]", 0) == 0)   return C_DIM;
    if (line.rfind(L"[!!]", 0) == 0)   return C_ORAN;
    if (line.rfind(L" press", 0) == 0) return C_DIM;
    return C_WHITE;
}

static void DrawBottomBar(HDC dc) {
    int barTop = WIN_H - 24;
    HLineRange(dc, 24, WIN_W - 24, barTop, 1, RGB(50, 8, 8));
    HLineRange(dc, 24, WIN_W - 24, barTop + 2, 1, RGB(25, 3, 3));
    DrawCenteredText(
        dc,
        g_fTiny,
        barTop + 6,
        L"\u2665 rank1shop.com \u2014 RANK1 CMD V.1 \u2665",
        RGB(55, 12, 12)
    );
}

static void RenderMenu(HDC dc) {
    int y = 10;
    HGDIOBJ oldFont = SelectObject(dc, g_fLogo);
    SIZE sz0 = { 0, 0 };
    GetTextExtentPoint32W(dc, LOGO_LINES[0], static_cast<int>(wcslen(LOGO_LINES[0])), &sz0);
    int logoX = (WIN_W - sz0.cx) / 2;

    SetBkMode(dc, TRANSPARENT);
    for (int i = 0; i < 7; ++i) {
        int lineY = y + i * 13;
        SetTextColor(dc, RGB(20, 0, 0));
        TextOutW(dc, logoX + 1, lineY + 1, LOGO_LINES[i], static_cast<int>(wcslen(LOGO_LINES[i])));
        SetTextColor(dc, LOGO_COLORS[i]);
        TextOutW(dc, logoX, lineY, LOGO_LINES[i], static_cast<int>(wcslen(LOGO_LINES[i])));
    }
    SelectObject(dc, oldFont);

    int divY = y + 7 * 13 + 6;
    HLineRange(dc, 36, WIN_W - 36, divY + 0, 1, RGB(120, 5, 5));
    HLineRange(dc, 36, WIN_W - 36, divY + 2, 2, RGB(200, 12, 12));
    HLineRange(dc, 36, WIN_W - 36, divY + 5, 1, RGB(80, 3, 3));

    int curY = divY + 14;
    DrawCenteredText(
        dc,
        g_fSmall,
        curY,
        L"\u30E9\u30F3\u30AF1 \u2665 RANK1SHOP \u2665 \u30E9\u30F3\u30AF1",
        RGB(60, 18, 18)
    );

    curY += 24 + 12;
    DrawGlowCenteredText(
        dc,
        g_fSmall,
        curY,
        L"\u2014\u2014 S E L E C T   M O D E \u2014\u2014",
        RGB(140, 22, 22),
        RGB(40, 3, 3)
    );

    curY += 28;
    HLineRange(dc, 110, WIN_W - 110, curY, 1, RGB(40, 8, 8));

    curY += 18;
    DrawGlowCenteredText(
        dc,
        g_fMenu,
        curY,
        L">> [ 1 ]  I N S T A L L  <<",
        RGB(255, 55, 55),
        RGB(80, 5, 5)
    );

    curY += 42;
    DrawGlowCenteredText(
        dc,
        g_fMenu,
        curY,
        L">> [ 2 ]  R E S E T  <<",
        RGB(190, 20, 20),
        RGB(60, 3, 3)
    );

    curY += 46;
    HLineRange(dc, 110, WIN_W - 110, curY, 1, RGB(40, 8, 8));

    curY += 22;
    std::wstring cursorText = g_blinkOn ? L" >> \u2588" : L" >>  ";
    DrawGlowCenteredText(
        dc,
        g_fMenu,
        curY,
        cursorText,
        RGB(220, 30, 30),
        RGB(60, 3, 3)
    );

    DrawBottomBar(dc);
}

static void RenderRunOrDone(HDC dc) {
    const wchar_t* header = (g_activeMode == 1)
        ? L">> I N S T A L L   M O D E  <<"
        : L">> R E S E T   M O D E  <<";

    int y = 24;
    DrawGlowCenteredText(dc, g_fMenu, y, header, RGB(255, 55, 55), RGB(80, 5, 5));

    int divY = y + 38;
    HLineRange(dc, 28, WIN_W - 28, divY, 1, RGB(120, 5, 5));
    HLineRange(dc, 28, WIN_W - 28, divY + 2, 1, RGB(50, 8, 8));

    std::vector<std::wstring> snapLogs;
    {
        std::lock_guard<std::mutex> lock(g_logMutex);
        snapLogs = g_logs;
    }

    const int maxVisible = 14;
    int startIdx = 0;
    if (static_cast<int>(snapLogs.size()) > maxVisible) {
        startIdx = static_cast<int>(snapLogs.size()) - maxVisible;
    }

    int logY = divY + 18;
    SetBkMode(dc, TRANSPARENT);
    HGDIOBJ oldFont = SelectObject(dc, g_fSmall);

    for (int i = startIdx; i < static_cast<int>(snapLogs.size()); ++i) {
        SetTextColor(dc, GetLogLineColor(snapLogs[i]));
        TextOutW(dc, 34, logY, snapLogs[i].c_str(), static_cast<int>(snapLogs[i].size()));
        logY += 19;
    }

    if (g_state == S_RUN) {
        static const wchar_t spinChars[4] = { L'-', L'/', L'|', L'\\' };
        wchar_t ch = spinChars[g_spinnerIdx & 3];
        wchar_t spinBuf[64];
        swprintf_s(spinBuf, L" %c working...", ch);
        SetTextColor(dc, C_SPINNER);
        TextOutW(dc, 34, logY + 6, spinBuf, static_cast<int>(wcslen(spinBuf)));
    } else if (g_state == S_DONE) {
        const wchar_t* doneHint = L" press [R] to return / [ESC] to exit";
        SetTextColor(dc, C_DIM);
        TextOutW(dc, 34, logY + 8, doneHint, static_cast<int>(wcslen(doneHint)));
    }

    SelectObject(dc, oldFont);
    DrawBottomBar(dc);
}

static void RenderFrame(HWND hwnd, HDC hdc) {
    RECT rc;
    GetClientRect(hwnd, &rc);
    int w = rc.right - rc.left;
    int h = rc.bottom - rc.top;
    if (w <= 0 || h <= 0) return;

    HDC memDc = CreateCompatibleDC(hdc);
    HBITMAP memBmp = CreateCompatibleBitmap(hdc, w, h);
    HGDIOBJ oldBmp = SelectObject(memDc, memBmp);

    HBRUSH bgBrush = CreateSolidBrush(C_BG);
    FillRect(memDc, &rc, bgBrush);
    DeleteObject(bgBrush);

    if (g_state == S_MENU) {
        RenderMenu(memDc);
    } else {
        RenderRunOrDone(memDc);
    }

    BitBlt(hdc, 0, 0, w, h, memDc, 0, 0, SRCCOPY);

    SelectObject(memDc, oldBmp);
    DeleteObject(memBmp);
    DeleteDC(memDc);
}

// ============================================================================
// WINDOW PROCEDURE
// ============================================================================
static void ApplyDarkTitleBar(HWND hwnd) {
    BOOL darkTrue = TRUE;
    DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &darkTrue, sizeof(darkTrue));
    DwmSetWindowAttribute(hwnd, 19, &darkTrue, sizeof(darkTrue));
    COLORREF capColor = RGB(0, 0, 0);
    DwmSetWindowAttribute(hwnd, DWMWA_CAPTION_COLOR, &capColor, sizeof(capColor));
}

static void HandleCharInput(wchar_t ch) {
    if (g_state == S_MENU) {
        if (ch == L'1') {
            StartMode(1);
        } else if (ch == L'2') {
            StartMode(2);
        }
    } else if (g_state == S_DONE) {
        if (ch == L'r' || ch == L'R' || ch == L'\r') {
            g_state = S_MENU;
            InvalidateRect(g_hwnd, nullptr, FALSE);
        }
    }
}

static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_CREATE: {
        g_hwnd = hwnd;
        ApplyDarkTitleBar(hwnd);
        SetLayeredWindowAttributes(hwnd, 0, 230, LWA_ALPHA);

        g_fLogo  = MakeCourierFont(13, FW_BOLD);
        g_fMenu  = MakeCourierFont(18, FW_BOLD);
        g_fSmall = MakeCourierFont(14, FW_NORMAL);
        g_fTiny  = MakeCourierFont(12, FW_NORMAL);

        SetWindowTextW(hwnd, TITLE_PHRASES[0]);
        SetTimer(hwnd, TIMER_TITLE, 2500, nullptr);
        SetTimer(hwnd, TIMER_BLINK, 500, nullptr);
        SetTimer(hwnd, TIMER_SPINNER, 100, nullptr);
        return 0;
    }

    case WM_ERASEBKGND:
        return 1;

    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        RenderFrame(hwnd, hdc);
        EndPaint(hwnd, &ps);
        return 0;
    }

    case WM_TIMER: {
        if (wParam == TIMER_TITLE) {
            g_titleIdx = (g_titleIdx + 1) % 5;
            SetWindowTextW(hwnd, TITLE_PHRASES[g_titleIdx]);
        } else if (wParam == TIMER_BLINK) {
            if (g_state == S_MENU) {
                g_blinkOn = !g_blinkOn;
                InvalidateRect(hwnd, nullptr, FALSE);
            }
        } else if (wParam == TIMER_SPINNER) {
            if (g_state == S_RUN) {
                g_spinnerIdx = (g_spinnerIdx + 1) % 4;
                InvalidateRect(hwnd, nullptr, FALSE);
            }
        }
        return 0;
    }

    case WM_KEYDOWN: {
        if (wParam == VK_ESCAPE) {
            DestroyWindow(hwnd);
            return 0;
        }
        if (g_state == S_DONE && wParam == VK_RETURN) {
            g_state = S_MENU;
            InvalidateRect(hwnd, nullptr, FALSE);
            return 0;
        }
        break;
    }

    case WM_CHAR: {
        HandleCharInput(static_cast<wchar_t>(wParam));
        return 0;
    }

    case WM_DESTROY: {
        KillTimer(hwnd, TIMER_TITLE);
        KillTimer(hwnd, TIMER_BLINK);
        KillTimer(hwnd, TIMER_SPINNER);

        if (g_worker.joinable()) {
            g_worker.join();
        }

        if (g_fLogo)  { DeleteObject(g_fLogo);  g_fLogo = nullptr; }
        if (g_fMenu)  { DeleteObject(g_fMenu);  g_fMenu = nullptr; }
        if (g_fSmall) { DeleteObject(g_fSmall); g_fSmall = nullptr; }
        if (g_fTiny)  { DeleteObject(g_fTiny);  g_fTiny = nullptr; }

        PostQuitMessage(0);
        return 0;
    }
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, PWSTR, int nCmdShow) {
    const wchar_t* CLASS_NAME = L"RANK1_CMD_WNDCLASS";

    WNDCLASSEXW wc = {};
    wc.cbSize        = sizeof(wc);
    wc.style         = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc   = WndProc;
    wc.hInstance     = hInstance;
    wc.hCursor       =LoadCursorW(nullptr, MAKEINTRESOURCEW(32512))
    wc.hbrBackground = nullptr;
    wc.lpszClassName = CLASS_NAME;

    if (!RegisterClassExW(&wc)) {
        return 1;
    }

    DWORD style   = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX;
    DWORD exStyle = WS_EX_APPWINDOW | WS_EX_LAYERED;

    RECT rect = { 0, 0, WIN_W, WIN_H };
    AdjustWindowRectEx(&rect, style, FALSE, exStyle);

    int outerW = rect.right - rect.left;
    int outerH = rect.bottom - rect.top;
    int screenW = GetSystemMetrics(SM_CXSCREEN);
    int screenH = GetSystemMetrics(SM_CYSCREEN);
    int posX = (screenW - outerW) / 2;
    int posY = (screenH - outerH) / 2;

    HWND hwnd = CreateWindowExW(
        exStyle,
        CLASS_NAME,
        TITLE_PHRASES[0],
        style,
        posX,
        posY,
        outerW,
        outerH,
        nullptr,
        nullptr,
        hInstance,
        nullptr
    );

    if (!hwnd) {
        return 1;
    }

    ShowWindow(hwnd, nCmdShow);
    UpdateWindow(hwnd);

    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    return static_cast<int>(msg.wParam);
}
