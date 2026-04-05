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
        GetWindowRect(eq.windows[i], &r);
        printf("%d|%p|%d,%d|%dx%d\n",
            i, eq.windows[i],
            r.left, r.top,
            r.right - r.left, r.bottom - r.top);
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

    int i;
    for (i = 0; i < argc && i < eq.count; i++) {
        int x, y, w, h;
        if (sscanf(argv[i], "%d,%d,%dx%d", &x, &y, &w, &h) == 4) {
            SetWindowPos(eq.windows[i], NULL, x, y, w, h, SWP_NOZORDER);
            InvalidateRect(eq.windows[i], NULL, TRUE);
            printf("Window %d: (%d,%d) %dx%d\n", i, x, y, w, h);
        }
    }
}

/* ── Main ── */

void usage(void) {
    printf("wine_helper.exe <command> [args...]\n\n");
    printf("Commands:\n");
    printf("  list                  List all visible windows\n");
    printf("  find                  Find EverQuest windows\n");
    printf("  resize N X Y W H     Resize EQ window #N\n");
    printf("  tile SPEC [SPEC...]   Tile EQ windows (SPEC: X,Y,WxH)\n");
    printf("\nSPEC format: x,y,wxh  e.g. 0,0,2236x1440\n");
}

int main(int argc, char *argv[]) {
    if (argc < 2) { usage(); return 1; }

    if (strcmp(argv[1], "list") == 0) {
        cmd_list();
    } else if (strcmp(argv[1], "find") == 0) {
        cmd_find();
    } else if (strcmp(argv[1], "resize") == 0 && argc >= 7) {
        cmd_resize(atoi(argv[2]), atoi(argv[3]), atoi(argv[4]),
                   atoi(argv[5]), atoi(argv[6]));
    } else if (strcmp(argv[1], "tile") == 0 && argc >= 3) {
        cmd_tile(argc - 2, argv + 2);
    } else {
        usage();
        return 1;
    }

    return 0;
}
