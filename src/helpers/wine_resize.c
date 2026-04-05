#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int target_index;
    int current_index;
    HWND found;
} EnumData;

BOOL CALLBACK EnumProc(HWND hwnd, LPARAM lParam) {
    EnumData *data = (EnumData*)lParam;
    char title[256];
    GetWindowTextA(hwnd, title, sizeof(title));
    
    if (strcmp(title, "EverQuest") == 0 && IsWindowVisible(hwnd)) {
        if (data->current_index == data->target_index) {
            data->found = hwnd;
            return FALSE; // stop
        }
        data->current_index++;
    }
    return TRUE;
}

int main(int argc, char *argv[]) {
    if (argc < 6) {
        printf("Usage: wine_resize_by_index.exe INDEX X Y W H\n");
        printf("  INDEX: 0-based index of EverQuest window\n");
        return 1;
    }
    
    int index = atoi(argv[1]);
    int x = atoi(argv[2]);
    int y = atoi(argv[3]);
    int w = atoi(argv[4]);
    int h = atoi(argv[5]);
    
    EnumData data = { index, 0, NULL };
    EnumWindows(EnumProc, (LPARAM)&data);
    
    if (!data.found) {
        printf("EverQuest window #%d not found\n", index);
        return 1;
    }
    
    printf("Found EQ window #%d (HWND %p), resizing to (%d,%d) %dx%d\n",
        index, data.found, x, y, w, h);
    
    SetWindowPos(data.found, NULL, x, y, w, h, SWP_NOZORDER);
    
    // Force a repaint
    InvalidateRect(data.found, NULL, TRUE);
    UpdateWindow(data.found);
    
    printf("Done!\n");
    return 0;
}
