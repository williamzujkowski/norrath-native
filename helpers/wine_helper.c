/*
 * wine_helper.c — Windows API helper for norrath-native
 *
 * Compiled with MinGW, executed via Wine to interact with EQ windows
 * using native Windows APIs. This is necessary because:
 *   - xdotool can't trigger Wine's WM_SIZE (resize without re-render)
 *   - xdotool can't read Wine window properties
 *   - Wine child windows need Windows API for proper interaction
 *
 * Build: x86_64-w64-mingw32-gcc -o wine_helper.exe wine_helper.c -luser32
 * Usage: wine wine_helper.exe <command> [args...]
 */

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ── List all visible windows ── */

static int g_list_index = 0;

BOOL CALLBACK ListProc(HWND hwnd, LPARAM lParam) {
    (void)lParam;
    char title[256] = {0};
    char cls[256] = {0};
    RECT rect;

    if (!IsWindowVisible(hwnd)) return TRUE;

    GetWindowTextA(hwnd, title, sizeof(title));
    GetClassNameA(hwnd, cls, sizeof(cls));
    GetWindowRect(hwnd, &rect);

    if (title[0] == '\0') return TRUE;

    int w = rect.right - rect.left;
    int h = rect.bottom - rect.top;

    printf("%d|%p|%s|%s|%d,%d|%dx%d\n",
        g_list_index, hwnd, title, cls,
        rect.left, rect.top, w, h);

    g_list_index++;
    return TRUE;
}

void cmd_list(void) {
    EnumWindows(ListProc, 0);
}

/* ── Find EQ windows ── */

typedef struct {
    HWND windows[16];
    int count;
} EqWindows;

BOOL CALLBACK FindEqProc(HWND hwnd, LPARAM lParam) {
    EqWindows *eq = (EqWindows*)lParam;
    char title[256] = {0};

    if (!IsWindowVisible(hwnd)) return TRUE;
    GetWindowTextA(hwnd, title, sizeof(title));

    if (strcmp(title, "EverQuest") == 0 && eq->count < 16) {
        eq->windows[eq->count] = hwnd;
        eq->count++;
    }
    return TRUE;
}

void cmd_find(void) {
    EqWindows eq = { .count = 0 };
    EnumWindows(FindEqProc, (LPARAM)&eq);

    for (int i = 0; i < eq.count; i++) {
        RECT r;
        DWORD pid = 0;
        GetWindowRect(eq.windows[i], &r);
        GetWindowThreadProcessId(eq.windows[i], &pid);
        printf("%d|%p|%d,%d|%dx%d|%lu\n",
            i, eq.windows[i],
            r.left, r.top,
            r.right - r.left, r.bottom - r.top,
            (unsigned long)pid);
    }

    if (eq.count == 0) {
        fprintf(stderr, "No EverQuest windows found\n");
    }
}

/* ── Resize window by index ── */

void cmd_resize(int index, int x, int y, int w, int h) {
    EqWindows eq = { .count = 0 };
    EnumWindows(FindEqProc, (LPARAM)&eq);

    if (index >= eq.count) {
        fprintf(stderr, "Window #%d not found (%d EQ windows)\n", index, eq.count);
        return;
    }

    HWND hwnd = eq.windows[index];
    SetWindowPos(hwnd, NULL, x, y, w, h, SWP_NOZORDER);
    InvalidateRect(hwnd, NULL, TRUE);
    UpdateWindow(hwnd);

    printf("Resized window #%d to (%d,%d) %dx%d\n", index, x, y, w, h);
}

/* ── Resize ALL windows from layout spec ── */
/* Format: "X,Y,WxH X,Y,WxH X,Y,WxH" */

void cmd_tile(int argc, char *argv[]) {
    EqWindows eq = { .count = 0 };
    EnumWindows(FindEqProc, (LPARAM)&eq);

    int tile_count = (argc < eq.count) ? argc : eq.count;
    int i;

    for (i = 0; i < tile_count; i++) {
        int x, y, w, h;
        if (sscanf(argv[i], "%d,%d,%dx%d", &x, &y, &w, &h) == 4) {
            SetWindowPos(eq.windows[i], NULL, x, y, w, h,
                         SWP_NOZORDER | SWP_NOACTIVATE);
            InvalidateRect(eq.windows[i], NULL, TRUE);
            printf("Window %d: (%d,%d) %dx%d\n", i, x, y, w, h);
        }
    }
    if (tile_count > 0) {
        SetForegroundWindow(eq.windows[0]);
    }
}

/* ── Focus window by index ── */

void cmd_focus(int index) {
    EqWindows eq = { .count = 0 };
    EnumWindows(FindEqProc, (LPARAM)&eq);

    if (index >= eq.count) {
        fprintf(stderr, "Window #%d not found (%d EQ windows)\n", index, eq.count);
        return;
    }

    HWND hwnd = eq.windows[index];
    SetForegroundWindow(hwnd);
    BringWindowToTop(hwnd);
    printf("Focused window #%d\n", index);
}

/* ── Focus window by HWND directly ── */

void cmd_focus_hwnd(HWND hwnd) {
    SetForegroundWindow(hwnd);
    BringWindowToTop(hwnd);
    printf("Focused HWND %p\n", hwnd);
}

/* ── Focus next window (cycle) ── */

void cmd_focus_next(void) {
    EqWindows eq = { .count = 0 };
    EnumWindows(FindEqProc, (LPARAM)&eq);

    if (eq.count == 0) {
        fprintf(stderr, "No EQ windows found\n");
        return;
    }

    HWND fg = GetForegroundWindow();
    int next = 0;
    int i;
    for (i = 0; i < eq.count; i++) {
        if (eq.windows[i] == fg) {
            next = (i + 1) % eq.count;
            break;
        }
    }

    SetForegroundWindow(eq.windows[next]);
    BringWindowToTop(eq.windows[next]);
    printf("Focused window #%d/%d\n", next + 1, eq.count);
}

/* ── Save window positions ── */

void cmd_save(void) {
    EqWindows eq = { .count = 0 };
    EnumWindows(FindEqProc, (LPARAM)&eq);

    int i;
    for (i = 0; i < eq.count; i++) {
        WINDOWPLACEMENT wp;
        wp.length = sizeof(WINDOWPLACEMENT);
        GetWindowPlacement(eq.windows[i], &wp);

        RECT r;
        GetWindowRect(eq.windows[i], &r);

        printf("%d|%d,%d,%dx%d|%u\n",
            i,
            r.left, r.top,
            r.right - r.left, r.bottom - r.top,
            wp.showCmd);
    }
}

/* ── Diagnostic dump for each EQ window ── */

void cmd_diag(void) {
    EqWindows eq = { .count = 0 };
    EnumWindows(FindEqProc, (LPARAM)&eq);

    HWND fg = GetForegroundWindow();
    HWND active = GetActiveWindow();
    HWND focus = GetFocus();
    HWND capture = GetCapture();

    printf("=== Global State ===\n");
    printf("Foreground:  %p\n", fg);
    printf("Active:      %p\n", active);
    printf("Focus:       %p\n", focus);
    printf("Capture:     %p\n", capture);
    printf("\n");

    for (int i = 0; i < eq.count; i++) {
        HWND hwnd = eq.windows[i];
        RECT r;
        DWORD pid = 0, style, exstyle;
        GetWindowRect(hwnd, &r);
        GetWindowThreadProcessId(hwnd, &pid);
        style = GetWindowLongA(hwnd, GWL_STYLE);
        exstyle = GetWindowLongA(hwnd, GWL_EXSTYLE);

        HWND parent = GetParent(hwnd);
        HWND owner = GetWindow(hwnd, GW_OWNER);
        BOOL enabled = IsWindowEnabled(hwnd);
        BOOL visible = IsWindowVisible(hwnd);

        /* Check what window is at the center of this window */
        int cx = (r.left + r.right) / 2;
        int cy = (r.top + r.bottom) / 2;
        HWND at_center = WindowFromPoint((POINT){cx, cy});

        /* Check what window is at top-left corner of this window */
        HWND at_origin = WindowFromPoint((POINT){r.left + 5, r.top + 5});

        HANDLE x11_wid = GetPropA(hwnd, "__wine_x11_whole_window");

        printf("=== Window %d: HWND %p (PID %lu) ===\n", i, hwnd, (unsigned long)pid);
        printf("  Position:    %d,%d  Size: %dx%d\n",
            r.left, r.top, r.right - r.left, r.bottom - r.top);
        printf("  Style:       0x%08lx  ExStyle: 0x%08lx\n",
            (unsigned long)style, (unsigned long)exstyle);
        printf("  Enabled:     %s  Visible: %s\n",
            enabled ? "yes" : "NO", visible ? "yes" : "NO");
        printf("  Parent:      %p  Owner: %p\n", parent, owner);
        printf("  X11 WID:     %lu\n", (unsigned long)(uintptr_t)x11_wid);
        printf("  IsForeground:%s\n", (hwnd == fg) ? "YES" : "no");
        printf("  HitTest center (%d,%d): %p %s\n",
            cx, cy, at_center,
            (at_center == hwnd) ? "(SELF)" : "(OTHER!)");
        printf("  HitTest corner (%d,%d): %p %s\n",
            r.left + 5, r.top + 5, at_origin,
            (at_origin == hwnd) ? "(SELF)" : "(OTHER!)");
        printf("\n");
    }

    /* Also check what's at some key positions */
    printf("=== Point Hit Tests ===\n");
    int test_points[][2] = {{25,25}, {100,100}, {500,500}, {2240,5}, {2240,725}};
    int npts = sizeof(test_points) / sizeof(test_points[0]);
    for (int j = 0; j < npts; j++) {
        HWND at = WindowFromPoint((POINT){test_points[j][0], test_points[j][1]});
        char title[64] = {0};
        if (at) GetWindowTextA(at, title, sizeof(title));
        printf("  (%d,%d) -> %p '%s'\n",
            test_points[j][0], test_points[j][1], at, title);
    }
}

/* ── Map HWNDs to X11 window IDs ── */
/* Wine stores the X11 WID as a window property "__wine_x11_whole_window" */

void cmd_map(void) {
    EqWindows eq = { .count = 0 };
    EnumWindows(FindEqProc, (LPARAM)&eq);

    for (int i = 0; i < eq.count; i++) {
        RECT r;
        DWORD pid = 0;
        GetWindowRect(eq.windows[i], &r);
        GetWindowThreadProcessId(eq.windows[i], &pid);

        HANDLE x11_wid = GetPropA(eq.windows[i], "__wine_x11_whole_window");

        printf("%d|%p|%d,%d|%dx%d|%lu|%lu\n",
            i, eq.windows[i],
            r.left, r.top,
            r.right - r.left, r.bottom - r.top,
            (unsigned long)pid,
            (unsigned long)(uintptr_t)x11_wid);
    }
}

/* ── Fix X11 stacking for a window ── */
/* The first-launched EQ process's X11 child window gets stuck at the
 * bottom of the Wine desktop's sibling stack. Hide/show forces Wine
 * to unmap and re-map the X11 child, placing it at the top.
 * This MUST run as a separate wine process invocation so the Wine
 * server fully processes the X11 unmap/remap between calls. */

void cmd_fix_stacking(HWND hwnd) {
    RECT r;
    GetWindowRect(hwnd, &r);
    int w = r.right - r.left;
    int h = r.bottom - r.top;

    printf("fix-stacking: hiding HWND %p\n", hwnd);
    ShowWindow(hwnd, SW_HIDE);
    Sleep(200);

    printf("fix-stacking: showing HWND %p\n", hwnd);
    ShowWindow(hwnd, SW_SHOW);
    Sleep(200);

    /* Re-apply position to trigger WM_SIZE for correct render */
    SetWindowPos(hwnd, NULL, r.left, r.top, w, h,
                 SWP_NOZORDER | SWP_NOACTIVATE);
    SetForegroundWindow(hwnd);
    printf("fix-stacking: done (%d,%d %dx%d)\n", r.left, r.top, w, h);
}

/* ── Send text to a window (types characters via WM_CHAR + Enter) ── */

void cmd_send_text(HWND hwnd, const char *text) {
    /* Focus the window first */
    SetForegroundWindow(hwnd);
    Sleep(100);

    /* Send each character via WM_CHAR */
    const char *p;
    for (p = text; *p; p++) {
        PostMessageA(hwnd, WM_CHAR, (WPARAM)(unsigned char)*p, 0);
        Sleep(10);
    }

    /* Press Enter (VK_RETURN) */
    PostMessageA(hwnd, WM_KEYDOWN, VK_RETURN, 0);
    Sleep(10);
    PostMessageA(hwnd, WM_KEYUP, VK_RETURN, 0);

    printf("Sent '%s' + Enter to HWND %p\n", text, hwnd);
}

/* ── Tile by HWND directly ── */

void cmd_tile_hwnd(int argc, char *argv[]) {
    /* Format: HWND X,Y,WxH HWND X,Y,WxH ... */

    typedef struct { HWND hwnd; int x, y, w, h; } TileSpec;
    TileSpec specs[16];
    int count = 0;

    /* Parse all tile specs first */
    int i;
    for (i = 0; i + 1 < argc; i += 2) {
        HWND hwnd = (HWND)(LONG_PTR)strtoull(argv[i], NULL, 0);
        int x, y, w, h;
        if (sscanf(argv[i+1], "%d,%d,%dx%d", &x, &y, &w, &h) == 4) {
            if (count < 16) {
                specs[count].hwnd = hwnd;
                specs[count].x = x;
                specs[count].y = y;
                specs[count].w = w;
                specs[count].h = h;
                count++;
            }
        }
    }

    /* Position all windows and send WM_SIZE for re-render */
    for (i = 0; i < count; i++) {
        SetWindowPos(specs[i].hwnd, NULL,
                     specs[i].x, specs[i].y, specs[i].w, specs[i].h,
                     SWP_NOZORDER | SWP_NOACTIVATE);
        InvalidateRect(specs[i].hwnd, NULL, TRUE);
        printf("HWND %p: (%d,%d) %dx%d\n",
            specs[i].hwnd, specs[i].x, specs[i].y,
            specs[i].w, specs[i].h);
    }

    /* Focus the main window */
    if (count > 0) {
        SetForegroundWindow(specs[0].hwnd);
    }
}

/* ── Main ── */

void usage(void) {
    printf("wine_helper.exe <command> [args...]\n\n");
    printf("Commands:\n");
    printf("  list                  List all visible windows\n");
    printf("  find                  Find EverQuest windows (with PIDs)\n");
    printf("  map                   Map HWNDs to X11 window IDs\n");
    printf("  resize N X Y W H     Resize EQ window by index\n");
    printf("  tile SPEC [...]       Tile EQ windows by index (X,Y,WxH)\n");
    printf("  tile-hwnd HWND SPEC [...] Tile by HWND directly\n");
    printf("  focus N               Focus EQ window by index\n");
    printf("  focus-hwnd HWND       Focus window by HWND directly\n");
    printf("  focus-next            Cycle focus to next EQ window\n");
    printf("  save                  Save current window positions\n");
    printf("  diag                  Diagnostic dump (styles, hit tests, focus)\n");
}

int main(int argc, char *argv[]) {
    if (argc < 2) { usage(); return 1; }

    if (strcmp(argv[1], "list") == 0) {
        cmd_list();
    } else if (strcmp(argv[1], "find") == 0) {
        cmd_find();
    } else if (strcmp(argv[1], "diag") == 0) {
        cmd_diag();
    } else if (strcmp(argv[1], "map") == 0) {
        cmd_map();
    } else if (strcmp(argv[1], "resize") == 0 && argc >= 7) {
        cmd_resize(atoi(argv[2]), atoi(argv[3]), atoi(argv[4]),
                   atoi(argv[5]), atoi(argv[6]));
    } else if (strcmp(argv[1], "tile") == 0 && argc >= 3) {
        cmd_tile(argc - 2, argv + 2);
    } else if (strcmp(argv[1], "tile-hwnd") == 0 && argc >= 4) {
        cmd_tile_hwnd(argc - 2, argv + 2);
    } else if (strcmp(argv[1], "fix-stacking") == 0 && argc >= 3) {
        cmd_fix_stacking((HWND)(LONG_PTR)strtoull(argv[2], NULL, 0));
    } else if (strcmp(argv[1], "send-text") == 0 && argc >= 4) {
        cmd_send_text((HWND)(LONG_PTR)strtoull(argv[2], NULL, 0), argv[3]);
    } else if (strcmp(argv[1], "focus") == 0 && argc >= 3) {
        cmd_focus(atoi(argv[2]));
    } else if (strcmp(argv[1], "focus-hwnd") == 0 && argc >= 3) {
        cmd_focus_hwnd((HWND)(LONG_PTR)strtoull(argv[2], NULL, 0));
    } else if (strcmp(argv[1], "focus-next") == 0) {
        cmd_focus_next();
    } else if (strcmp(argv[1], "save") == 0) {
        cmd_save();
    } else {
        usage();
        return 1;
    }

    return 0;
}
