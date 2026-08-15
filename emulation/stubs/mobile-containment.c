/* Fail-closed interposition layer for an offline mobile-daemon smoke test.
 *
 * This object deliberately has no libc dependency.  It logs fixed event names
 * only, then rejects operations which could escape or mutate the sandbox.
 */

typedef unsigned int socklen_t;

struct sockaddr {
    unsigned short sa_family;
    char sa_data[14];
};

struct sockaddr_un {
    unsigned short sun_family;
    char sun_path[108];
};

enum { AF_UNIX = 1 };

static long arm_syscall3(long nr, long a, long b, long c) {
    register long r0 __asm__("r0") = a;
    register long r1 __asm__("r1") = b;
    register long r2 __asm__("r2") = c;
    register long r7 __asm__("r7") = nr;
    __asm__ volatile("svc 0" : "+r"(r0) : "r"(r1), "r"(r2), "r"(r7) : "memory");
    return r0;
}

static unsigned text_len(const char *s) {
    unsigned n = 0;
    while (s[n]) ++n;
    return n;
}

static int text_equal(const char *a, const char *b) {
    while (*a && *a == *b) { ++a; ++b; }
    return *a == *b;
}

static int text_starts(const char *text, const char *prefix) {
    while (*prefix && *text == *prefix) { ++text; ++prefix; }
    return *prefix == 0;
}

static int text_contains(const char *text, const char *needle) {
    while (*text) {
        if (text_starts(text, needle)) return 1;
        ++text;
    }
    return 0;
}

static int tmp_path(const char *path) {
    return path[0] == '/' && path[1] == 't' && path[2] == 'm' &&
           path[3] == 'p' && path[4] == '/';
}

static void record(const char *event) {
    static const char prefix[] = "{\"event\":\"";
    static const char suffix[] = "\"}\n";
    static const char path[] = "/traces/mobile-containment.jsonl";
    long fd = arm_syscall3(5, (long)path, 0101 | 02000, 0600); /* open: WRONLY|CREAT|APPEND */
    if (fd < 0) return;
    (void)arm_syscall3(4, fd, (long)prefix, sizeof(prefix) - 1);
    (void)arm_syscall3(4, fd, (long)event, text_len(event));
    (void)arm_syscall3(4, fd, (long)suffix, sizeof(suffix) - 1);
    (void)arm_syscall3(6, fd, 0, 0);
}

int system(const char *command) {
    (void)command;
    record("system-denied");
    return 125;
}

int unlink(const char *path) {
    (void)path;
    record("unlink-denied");
    return -1;
}

int remove(const char *path) {
    (void)path;
    record("remove-denied");
    return -1;
}

int open(const char *path, int flags, ...) {
    unsigned mode = 0;
    if (flags & 0100) {
        __builtin_va_list args;
        __builtin_va_start(args, flags);
        mode = __builtin_va_arg(args, unsigned);
        __builtin_va_end(args);
    }
    if (!path ||
        (text_starts(path, "/dev/") && !text_equal(path, "/dev/null")) ||
        text_starts(path, "/sys/") || text_starts(path, "/host-rootfs/") ||
        (text_starts(path, "/proc/") &&
         (text_contains(path, "/root/") || text_contains(path, "/fd/")))) {
        record("device-path-open-denied");
        return -1;
    }
    return (int)arm_syscall3(5, (long)path, flags, mode);
}

long syscall(long number, ...) {
    (void)number;
    record("raw-syscall-denied");
    return -1;
}

int socket(int domain, int type, int protocol) {
    if (domain != AF_UNIX) {
        record("network-socket-denied");
        return -1;
    }
    return (int)arm_syscall3(281, domain, type, protocol);
}

int connect(int fd, const struct sockaddr *address, socklen_t length) {
    const struct sockaddr_un *unix_address = (const struct sockaddr_un *)address;
    if (!address || address->sa_family != AF_UNIX || length < 3 ||
        !text_equal(unix_address->sun_path, "/tmp/atcmd")) {
        record("connect-denied");
        return -1;
    }
    return (int)arm_syscall3(283, fd, (long)address, length);
}

int sendto(int fd, const void *buffer, unsigned long length, int flags,
           const struct sockaddr *destination, socklen_t address_length) {
    register long r0 __asm__("r0") = fd;
    register long r1 __asm__("r1") = (long)buffer;
    register long r2 __asm__("r2") = length;
    register long r3 __asm__("r3") = flags;
    register long r4 __asm__("r4") = (long)destination;
    register long r5 __asm__("r5") = address_length;
    register long r7 __asm__("r7") = 290;
    if (destination) {
        const struct sockaddr_un *unix_destination =
            (const struct sockaddr_un *)destination;
        if (destination->sa_family != AF_UNIX || address_length < 3 ||
            !tmp_path(unix_destination->sun_path)) {
            record("sendto-denied");
            return -1;
        }
    }
    __asm__ volatile("svc 0" : "+r"(r0) : "r"(r1), "r"(r2), "r"(r3),
                     "r"(r4), "r"(r5), "r"(r7) : "memory");
    return (int)r0;
}

#define DENY0(name) int name(void) { record(#name "-denied"); return -1; }

DENY0(send_wan_ipv4_connect_msg)
DENY0(send_wan_ipv4_disconnect_msg)
DENY0(send_wan_ipv6_connect_msg)
DENY0(send_wan_ipv6_disconnect_msg)
DENY0(send_set_wan_mtu_msg)
DENY0(wm_connect)
DENY0(wm_disconnect)
DENY0(wm_lte_wifi_coex_notify)
