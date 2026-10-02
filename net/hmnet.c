// hmnet.dll - UDP link for the Hotline Miami co-op mod.
// Called from GameMaker 7 GML via external_define(..., dll_cdecl, ...).
//
// Two channels share one packet sent every step:
//  * state:  NFIELDS doubles, newest packet wins (sequence numbers drop late datagrams);
//  * events: reliable, ordered (kills, floor transitions). Each packet carries the oldest
//            un-acked events; the receiver acks the highest in-order id it has delivered.
//
// Config: hmcoop.txt next to the exe (read by net_start):
//   port=7777            local UDP port
//   peer=1.2.3.4:7777    partner address; empty = wait for the partner to talk first
//   name=P1              shown above your ghost on the other screen
//   skin=jacket          jacket | beard | richter | corey | jake | son | writer | pardo | henchman | random
//   beard_chance=50      percent, for skin=random

#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define EXPORT __declspec(dllexport) double __cdecl
#define NFIELDS 32
#define MAGIC 0x34434D48u /* "HMC4": protocol 4 (carries the mod version, kept from now on) */
#define EMAGIC 0x34454D48u /* "HME4": enemy state packet */
#define MOD_VERSION 60   /* v0.6: compared with the partner's, a difference is reported */
#define ES_MAX 48
#define EV_PER_PACKET 8
#define EV_QUEUE 1024

#pragma pack(push, 1)
typedef struct {
    unsigned int id;
    unsigned int type;
    double a[4];
} Event;

typedef struct {
    unsigned int magic;
    unsigned int modver;   // MOD_VERSION of the sender
    unsigned int session;  // random per game launch: a restarted partner resets the event stream
    unsigned int seq;
    char name[16];
    double f[NFIELDS];
    unsigned int ack;  // highest in-order event id we have delivered from the peer
    unsigned int nev;
    Event ev[EV_PER_PACKET];
} Packet;
// Enemy state: the enemies this side simulates ("owns"), sent ~30 times a second.
typedef struct {
    int uid;
    short obj, spr;
    float x, y, dir, img;
    int alert;
} EState;

typedef struct {
    unsigned int magic;
    unsigned int session;
    unsigned int seq;
    unsigned int count;
    EState e[ES_MAX];
} EPacket;
#pragma pack(pop)

static EPacket es_out, es_in;
static unsigned int es_last_seq = 0;
static DWORD es_rx_time = 0;
static int es_have = 0;

static SOCKET sock = INVALID_SOCKET;
static struct sockaddr_in peer;
static int have_peer = 0;
static Packet out, in;
static unsigned int last_seq = 0;
static int have_in = 0;
static DWORD last_rx = 0;
static char status[256] = "not started";
static char peer_name[17] = "";
static unsigned long n_tx = 0, n_rx = 0, n_err = 0, n_bad = 0, n_old = 0;
static int last_err = 0;
static DWORD last_log = 0;
static char logpath[300] = "hmnet_log.txt";
static double skin_pref = 0, beard_chance = 50;
static double tick = 0;
static int peer_modver = 0;
static DWORD last_old = 0;              // when the last packet of another mod version arrived
#define OLD_RECENT (n_old && GetTickCount() - last_old < 3000)            // version of a partner we could not talk to (0 = older than v0.6)
static char local_addrs[200] = "";

// outgoing events: ring of ids (out_next_id - out_count .. out_next_id - 1)
static Event outq[EV_QUEUE];
static unsigned int out_first = 1, out_next = 1;  // ids
// incoming delivered-but-unread events
static Event inq[EV_QUEUE];
static int in_head = 0, in_count = 0;
static unsigned int rx_next = 1;  // next event id expected from the peer
static unsigned long n_ev_tx = 0, n_ev_rx = 0;
static unsigned int peer_session = 0;

static void write_log(void) {
    DWORD now = GetTickCount();
    if (now - last_log < 2000) return;
    last_log = now;
    FILE *f = fopen(logpath, "w");
    if (!f) return;
    fprintf(f, "status: %s\n", status);
    if (have_peer) fprintf(f, "peer: %s:%d\n", inet_ntoa(peer.sin_addr), ntohs(peer.sin_port));
    else fprintf(f, "peer: not known yet\n");
    fprintf(f, "sent: %lu  received: %lu  bad packets: %lu  other-version: %lu  socket errors: %lu (last %d)\n",
            n_tx, n_rx, n_bad, n_old, n_err, last_err);
    fprintf(f, "events sent: %lu (unacked %u)  events received: %lu\n", n_ev_tx, out_next - out_first, n_ev_rx);
    fprintf(f, "partner: %s, last packet %ld ms ago\n", peer_name[0] ? peer_name : "-", have_in ? (long)(now - last_rx) : -1L);
    if (n_old) fprintf(f, "WARNING: partner runs a different mod version - reinstall the same version on both PCs\n");
    fclose(f);
}

static void trim(char *s) {
    size_t n = strlen(s);
    while (n && (s[n - 1] == '\r' || s[n - 1] == '\n' || s[n - 1] == ' ')) s[--n] = 0;
}

static int resolve(const char *hostport, struct sockaddr_in *sa) {
    char host[200];
    int port = 7777;
    strncpy(host, hostport, sizeof host - 1);
    host[sizeof host - 1] = 0;
    char *c = strrchr(host, ':');
    if (c) { *c = 0; port = atoi(c + 1); }
    struct addrinfo hints = {0}, *res = NULL;
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    if (getaddrinfo(host, NULL, &hints, &res) != 0 || !res) return 0;
    *sa = *(struct sockaddr_in *)res->ai_addr;
    sa->sin_port = htons((u_short)port);
    freeaddrinfo(res);
    return 1;
}

static void find_local_addrs(int port) {
    char host[256];
    struct addrinfo hints = {0}, *res = NULL, *r;
    local_addrs[0] = 0;
    if (gethostname(host, sizeof host) != 0) return;
    hints.ai_family = AF_INET;
    if (getaddrinfo(host, NULL, &hints, &res) != 0) return;
    for (r = res; r; r = r->ai_next) {
        unsigned char *b = (unsigned char *)&((struct sockaddr_in *)r->ai_addr)->sin_addr;
        const char *a = inet_ntoa(((struct sockaddr_in *)r->ai_addr)->sin_addr);
        // skip loopback, link-local and 172.16/12 (WSL, Docker, Hyper-V switches): nobody connects to those
        if (b[0] == 127 || (b[0] == 169 && b[1] == 254) || (b[0] == 172 && b[1] >= 16 && b[1] < 32)) continue;
        if (strlen(local_addrs) + strlen(a) + 12 >= sizeof local_addrs) continue;
        if (b[0] == 26) {  // Radmin VPN first
            char t[200];
            snprintf(t, sizeof t, "%s%s%s", a, local_addrs[0] ? "  " : "", local_addrs);
            strcpy(local_addrs, t);
            continue;
        }
        if (local_addrs[0]) strcat(local_addrs, "  ");
        strcat(local_addrs, a);
    }
    freeaddrinfo(res);
    (void)port;
}

EXPORT net_start(const char *cfgpath) {
    WSADATA w;
    int port = 7777;
    char line[256], peerstr[200] = "";
    if (sock != INVALID_SOCKET) return 1;  // game_restart / game_load re-run the init script
    memset(&out, 0, sizeof out);
    out.magic = MAGIC;
    out.modver = MOD_VERSION;
    out.session = GetTickCount() ^ (GetCurrentProcessId() << 16) ^ 0x9E3779B9u;
    if (!out.session) out.session = 1;
    strcpy(out.name, "P?");

    // log goes next to the config file
    strncpy(logpath, cfgpath, sizeof logpath - 20);
    logpath[sizeof logpath - 20] = 0;
    char *slash = strrchr(logpath, 92);
    if (slash) strcpy(slash + 1, "hmnet_log.txt"); else strcpy(logpath, "hmnet_log.txt");

    FILE *f = fopen(cfgpath, "r");
    if (f) {
        while (fgets(line, sizeof line, f)) {
            trim(line);
            if (!strncmp(line, "port=", 5)) port = atoi(line + 5);
            else if (!strncmp(line, "peer=", 5)) strncpy(peerstr, line + 5, sizeof peerstr - 1);
            else if (!strncmp(line, "name=", 5)) { strncpy(out.name, line + 5, 15); out.name[15] = 0; }
            else if (!strncmp(line, "skin=", 5)) {
                const char *v = line + 5;
                static const char *names[] = {"jacket", "beard", "richter", "corey", "jake", "son", "writer",
                                              "pardo", "henchman"};
                skin_pref = (v[0] >= '0' && v[0] <= '9') ? atoi(v) : 0;
                for (int k = 0; k < 9; k++)
                    if (!_stricmp(v, names[k])) skin_pref = k;
                if (!_stricmp(v, "random")) skin_pref = -1;
            } else if (!strncmp(line, "beard_chance=", 13)) beard_chance = atof(line + 13);
        }
        fclose(f);
    }

    if (WSAStartup(MAKEWORD(2, 2), &w) != 0) { strcpy(status, "WSAStartup failed"); return -1; }
    sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (sock == INVALID_SOCKET) { strcpy(status, "socket failed"); return -2; }
    u_long nb = 1;
    ioctlsocket(sock, FIONBIO, &nb);
    // Windows reports ICMP "port unreachable" from an earlier send as WSAECONNRESET on the next
    // recvfrom; switch that off or one closed peer stalls the receive loop.
    BOOL off = FALSE;
    DWORD ret = 0;
    WSAIoctl(sock, _WSAIOW(IOC_VENDOR, 12), &off, sizeof off, NULL, 0, &ret, NULL, NULL);
    struct sockaddr_in me = {0};
    me.sin_family = AF_INET;
    me.sin_addr.s_addr = INADDR_ANY;
    me.sin_port = htons((u_short)port);
    if (bind(sock, (struct sockaddr *)&me, sizeof me) != 0) {
        snprintf(status, sizeof status, "port %d busy", port);
        closesocket(sock);
        sock = INVALID_SOCKET;
        return -3;
    }
    find_local_addrs(port);
    if (peerstr[0]) {
        have_peer = resolve(peerstr, &peer);
        snprintf(status, sizeof status, have_peer ? "port %d -> %s" : "port %d, bad peer %s", port, peerstr);
    } else {
        snprintf(status, sizeof status, "port %d, waiting for peer", port);
    }
    return 1;
}

EXPORT net_set(double i, double v) {
    int k = (int)i;
    if (k >= 0 && k < NFIELDS) out.f[k] = v;
    return 0;
}

EXPORT net_send(void) {
    if (sock == INVALID_SOCKET || !have_peer) return 0;
    out.seq++;
    out.ack = rx_next - 1;
    unsigned int n = 0;
    for (unsigned int id = out_first; id < out_next && n < EV_PER_PACKET; id++, n++)
        out.ev[n] = outq[id % EV_QUEUE];
    out.nev = n;
    if (sendto(sock, (const char *)&out, sizeof out, 0, (struct sockaddr *)&peer, sizeof peer) != sizeof out) {
        n_err++;
        last_err = WSAGetLastError();
        return 0;
    }
    n_tx++;
    return 1;
}

static void take_events(const Packet *p) {
    // peer acknowledged our events up to p->ack
    while (out_first < out_next && (int)(p->ack - out_first) >= 0) out_first++;
    for (unsigned int k = 0; k < p->nev && k < EV_PER_PACKET; k++) {
        const Event *e = &p->ev[k];
        if (e->id != rx_next) continue;  // duplicate or out of order: it will be resent
        if (in_count < EV_QUEUE) {
            inq[(in_head + in_count) % EV_QUEUE] = *e;
            in_count++;
        }
        rx_next++;
        n_ev_rx++;
    }
}

// Drain the socket; keep the newest state, deliver events. Returns 1 if something new arrived.
EXPORT net_poll(void) {
    if (sock == INVALID_SOCKET) return 0;
    int got = 0;
    static union { Packet p; EPacket ep; char raw[2048]; } buf;
    for (;;) {
        Packet p;
        struct sockaddr_in from;
        int fl = sizeof from;
        int n = recvfrom(sock, buf.raw, sizeof buf.raw, 0, (struct sockaddr *)&from, &fl);
        if (n >= 16 && buf.ep.magic == EMAGIC) {
            unsigned int cnt = buf.ep.count;
            if (cnt <= ES_MAX && n == (int)(16 + cnt * sizeof(EState)) && buf.ep.session == peer_session &&
                (!es_have || (int)(buf.ep.seq - es_last_seq) > 0 || (int)(es_last_seq - buf.ep.seq) > 600)) {
                memcpy(&es_in, &buf.ep, n);
                es_last_seq = buf.ep.seq;
                es_rx_time = GetTickCount();
                es_have = 1;
            }
            continue;
        }
        if (n > (int)sizeof p) { n_bad++; continue; }
        if (n > 0) memcpy(&p, buf.raw, n);
        if (n < 0) {
            int e = WSAGetLastError();
            if (e == WSAEWOULDBLOCK) break;
            n_err++;
            last_err = e;
            if (e != WSAECONNRESET && e != WSAEMSGSIZE) break;
            continue;
        }
        if (n >= 8 && p.magic == MAGIC && p.modver != MOD_VERSION) { n_old++; last_old = GetTickCount(); peer_modver = (int)p.modver; continue; }
        if (n >= 8 && p.magic != MAGIC && (p.magic & 0xFFFFFF) == (MAGIC & 0xFFFFFF)) { n_old++; last_old = GetTickCount(); peer_modver = 0; continue; }
        if (n >= 4 && p.magic == 0x484D4350u) { n_old++; last_old = GetTickCount(); peer_modver = 0; continue; }  // v0.1 "HMCP"
        if (n != sizeof p || p.magic != MAGIC) { n_bad++; continue; }
        n_rx++;
        if (!have_peer) {  // the side without peer= learns the address from the first packet
            peer = from;
            have_peer = 1;
        }
        if (p.session != peer_session) {  // partner (re)started: both event streams begin again at id 1
            peer_session = p.session;
            rx_next = 1;
            out_first = out_next = 1;
            in_count = 0;
            have_in = 0;
            es_have = 0;
        }
        take_events(&p);  // events are processed even from late packets (ids dedupe them)
        if (have_in && (int)(p.seq - last_seq) <= 0 && (int)(last_seq - p.seq) < 600) continue;  // stale
        memcpy(&in, &p, sizeof in);
        last_seq = p.seq;
        have_in = 1;
        last_rx = GetTickCount();
        memcpy(peer_name, p.name, 16);
        peer_name[16] = 0;
        got = 1;
    }
    write_log();
    return got;
}

EXPORT net_get(double i) {
    int k = (int)i;
    return (have_in && k >= 0 && k < NFIELDS) ? in.f[k] : 0;
}

// Milliseconds since the last packet, or -1 if never.
EXPORT net_age(void) {
    return have_in ? (double)(GetTickCount() - last_rx) : -1;
}

// ---- reliable events
EXPORT net_event(double type, double a, double b, double c) {
    if (out_next - out_first >= EV_QUEUE - 1) return 0;  // queue full (peer gone for a long time)
    Event *e = &outq[out_next % EV_QUEUE];
    e->id = out_next++;
    e->type = (unsigned int)type;
    e->a[0] = a;
    e->a[1] = b;
    e->a[2] = c;
    e->a[3] = 0;
    n_ev_tx++;
    return 1;
}

// same with a fourth value
EXPORT net_event4(double type, double a, double b, double c, double d) {
    if (!net_event(type, a, b, c)) return 0;
    outq[(out_next - 1) % EV_QUEUE].a[3] = d;
    return 1;
}

EXPORT net_ev_count(void) { return in_count; }

// field 0 = type, 1..4 = a, b, c, d of the oldest unread event
EXPORT net_ev_get(double k) {
    if (!in_count) return 0;
    Event *e = &inq[in_head];
    int i = (int)k;
    return i == 0 ? (double)e->type : (i >= 1 && i <= 4) ? e->a[i - 1] : 0;
}

EXPORT net_ev_pop(void) {
    if (in_count) { in_head = (in_head + 1) % EV_QUEUE; in_count--; }
    return in_count;
}

// ---- enemy state channel
EXPORT net_es_begin(void) { es_out.count = 0; return 0; }

EXPORT net_es_add(double uid, double obj, double x, double y, double dir, double spr, double img, double alert) {
    if (es_out.count >= ES_MAX) return 0;
    EState *e = &es_out.e[es_out.count++];
    e->uid = (int)uid;
    e->obj = (short)obj;
    e->spr = (short)spr;
    e->x = (float)x;
    e->y = (float)y;
    e->dir = (float)dir;
    e->img = (float)img;
    e->alert = (int)alert;
    return 1;
}

EXPORT net_es_send(void) {
    if (sock == INVALID_SOCKET || !have_peer) return 0;
    es_out.magic = EMAGIC;
    es_out.session = out.session;
    es_out.seq++;
    int len = 16 + es_out.count * sizeof(EState);
    return sendto(sock, (const char *)&es_out, len, 0, (struct sockaddr *)&peer, sizeof peer) == len;
}

// field of the partner's latest state for enemy uid: 0 obj, 1 x, 2 y, 3 dir, 4 sprite, 5 frame, 6 alert.
// Returns -100000 when the partner does not currently simulate that enemy (or the data is stale).
EXPORT net_es_get(double uid, double field) {
    if (!es_have || GetTickCount() - es_rx_time > 1000) return -100000;
    int u = (int)uid;
    for (unsigned int i = 0; i < es_in.count; i++) {
        EState *e = &es_in.e[i];
        if (e->uid != u) continue;
        switch ((int)field) {
            case 0: return e->obj;
            case 1: return e->x;
            case 2: return e->y;
            case 3: return e->dir;
            case 4: return e->spr;
            case 5: return e->img;
            case 6: return e->alert;
        }
    }
    return -100000;
}

// Deterministic tie-break between the two players: 1 on exactly one side.
EXPORT net_rank(void) { return out.session < peer_session ? 1 : 0; }

// ---- misc
// Monotonic counter that survives game_load (which rewinds every GML variable).
EXPORT net_tick(void) { return ++tick; }

EXPORT net_skin_pref(void) { return skin_pref; }
EXPORT net_beard_chance(void) { return beard_chance; }

// 1 if the foreground window belongs to this game process. The runner reads the keyboard globally,
// so without this a background game would react to typing in other apps.
EXPORT net_focused(void) {
    DWORD pid = 0;
    HWND fg = GetForegroundWindow();
    if (!fg) {  // Windows sometimes leaves no foreground window after a click: trust the cursor
        POINT pt;
        GetCursorPos(&pt);
        fg = WindowFromPoint(pt);
    }
    GetWindowThreadProcessId(fg, &pid);
    return pid == GetCurrentProcessId();
}

__declspec(dllexport) const char *__cdecl net_status(void) {
    static char msg[160];
    if (!OLD_RECENT) return status;
    if (peer_modver)
        snprintf(msg, sizeof msg, "partner has mod v%d.%d, you have v%d.%d - install the same version", peer_modver / 100,
                 peer_modver % 100 / 10 + 0, MOD_VERSION / 100, MOD_VERSION % 100 / 10);
    else
        snprintf(msg, sizeof msg, "partner has an older mod version, you have v%d.%d - install the same version",
                 MOD_VERSION / 100, MOD_VERSION % 100 / 10);
    return msg;
}
// 1 while the partner's packets are rejected because of a different mod version
EXPORT net_version_mismatch(void) { return OLD_RECENT ? 1 : 0; }
// our local / VPN IPv4 addresses (Radmin shows up as 26.x.x.x)
__declspec(dllexport) const char *__cdecl net_local(void) { return local_addrs; }
// change the partner's address / our name while running (in-game connect menu)
EXPORT net_set_peer(const char *hostport) {
    struct sockaddr_in a;
    if (!hostport[0] || !resolve(hostport, &a)) return 0;
    peer = a;
    have_peer = 1;
    snprintf(status, sizeof status, "-> %s", hostport);
    return 1;
}
EXPORT net_set_name(const char *name) {
    strncpy(out.name, name, 15);
    out.name[15] = 0;
    return 1;
}
__declspec(dllexport) const char *__cdecl net_peer_name(void) { return peer_name; }

EXPORT net_stop(void) {
    if (sock != INVALID_SOCKET) closesocket(sock);
    sock = INVALID_SOCKET;
    WSACleanup();
    return 0;
}
