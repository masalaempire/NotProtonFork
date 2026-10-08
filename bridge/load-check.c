#include <dlfcn.h>
#include <stdio.h>
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    void *bridge = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!bridge) { fprintf(stderr, "%s\n", dlerror()); return 1; }
    if (!dlsym(bridge, "__wine_unix_call_funcs")) {
        fprintf(stderr, "missing Wine entry table\n"); return 1;
    }
    puts("Bridge loads against the installed CrossOver 26.1 ntdll.so; entry table exists.");
    return 0;
}
