#include <stdint.h>

#define AF_UNIX 1
#define SOCK_DGRAM 2
#define O_WRONLY 1
#define O_CREAT 64
#define O_APPEND 1024
#define WLAN_MESSAGE_SIZE 8192

struct sockaddr_un {
    uint16_t family;
    char path[108];
};

struct wm_header {
    uint32_t command;
    uint32_t kind;
    uint32_t result;
    uint32_t length;
};

struct pollfd {
    int fd;
    int16_t events;
    int16_t revents;
};

static long call1(long number, long a) {
    register long r0 __asm__("r0") = a;
    register long r7 __asm__("r7") = number;
    __asm__ volatile("svc 0" : "+r"(r0) : "r"(r7) : "memory");
    return r0;
}

static long call3(long number, long a, long b, long c) {
    register long r0 __asm__("r0") = a;
    register long r1 __asm__("r1") = b;
    register long r2 __asm__("r2") = c;
    register long r7 __asm__("r7") = number;
    __asm__ volatile("svc 0" : "+r"(r0) : "r"(r1), "r"(r2), "r"(r7) : "memory");
    return r0;
}

static long call6(long number, long a, long b, long c, long d, long e, long f) {
    register long r0 __asm__("r0") = a;
    register long r1 __asm__("r1") = b;
    register long r2 __asm__("r2") = c;
    register long r3 __asm__("r3") = d;
    register long r4 __asm__("r4") = e;
    register long r5 __asm__("r5") = f;
    register long r7 __asm__("r7") = number;
    __asm__ volatile("svc 0" : "+r"(r0) : "r"(r1), "r"(r2), "r"(r3), "r"(r4), "r"(r5), "r"(r7) : "memory");
    return r0;
}

static unsigned length(const char *text) {
    unsigned result = 0;
    while (text[result]) result++;
    return result;
}

static void clear(void *target, unsigned count) {
    unsigned char *bytes = target;
    while (count--) *bytes++ = 0;
}

static void copy(void *target, const void *source, unsigned count) {
    unsigned char *out = target;
    const unsigned char *in = source;
    while (count--) *out++ = *in++;
}

static int bind_dgram(const char *path) {
    int fd = call3(281, AF_UNIX, SOCK_DGRAM, 0);
    struct sockaddr_un address;
    unsigned size = length(path);
    if (fd < 0 || size >= sizeof(address.path)) return -1;
    clear(&address, sizeof(address));
    address.family = AF_UNIX;
    copy(address.path, path, size + 1);
    call1(10, (long)path);
    if (call3(282, fd, (long)&address, sizeof(address)) < 0) return -1;
    return fd;
}

static void log_line(int fd, const char *line) {
    call3(4, fd, (long)line, length(line));
}

static int run(void) {
    int flow = bind_dgram("/tmp/flowstate.sock");
    int wlan = bind_dgram("/tmp/ha_wm.sock");
    int log = call3(5, (long)"/traces/downstream-stub.log",
                    O_WRONLY | O_CREAT | O_APPEND, 0644);
    unsigned char request[WLAN_MESSAGE_SIZE];
    if (flow < 0 || wlan < 0 || log < 0) return 2;

    for (;;) {
        struct pollfd waits[2] = {{flow, 1, 0}, {wlan, 1, 0}};
        if (call3(168, (long)waits, 2, -1) < 0)
            continue;
        int fd = waits[0].revents & 1 ? flow : wlan;
        struct sockaddr_un peer;
        uint32_t peer_size = sizeof(peer);
        long received = call6(292, fd, (long)request, sizeof(request), 0,
                              (long)&peer, (long)&peer_size);
        if (received < 0) continue;

        if (fd == flow && received == 2 && request[0] == 'F' &&
            (request[1] == 'M' || request[1] == 'D' ||
             request[1] == 'T' || request[1] == 'R')) {
            unsigned char reply[32];
            clear(reply, sizeof(reply));
            reply[0] = request[0];
            reply[1] = request[1];
            reply[2] = ':';
            reply[3] = '0';
            call6(290, fd, (long)reply, sizeof(reply), 0,
                  (long)&peer, peer_size);
            log_line(log, "flow request=2 response=32\n");
        } else if (fd == wlan && received == WLAN_MESSAGE_SIZE) {
            struct wm_header header;
            copy(&header, request, sizeof(header));
            uint32_t payload = header.command == 4 ? 0x198 : 4;
            if ((header.command == 0 || header.command == 3 || header.command == 4) &&
                header.kind == 1 && header.result == 0 && header.length == 0) {
                unsigned char reply[sizeof(header) + 0x198];
                clear(reply, sizeof(reply));
                header.kind = 0;
                header.length = payload;
                copy(reply, &header, sizeof(header));
                call6(290, fd, (long)reply, sizeof(header) + payload, 0,
                      (long)&peer, peer_size);
                if (header.command == 0) log_line(log, "wlan command=0 request=8192 response=20\n");
                if (header.command == 3) log_line(log, "wlan command=3 request=8192 response=20\n");
                if (header.command == 4) log_line(log, "wlan command=4 request=8192 response=424\n");
            }
        }
    }
}

void _start(void) {
    call1(1, run());
    for (;;) {}
}
