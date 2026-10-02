// hmnet.dll - UDP link for the Hotline Miami co-op mod (up to 4 players: you + 3 peers).
// Called from GameMaker 7 GML via external_define(..., dll_cdecl, ...).
//
// Every player talks to every other player directly (full mesh). To each peer, one packet per step:
//  * state:  NFIELDS doubles, newest packet wins (sequence numbers drop late datagrams);
//  * events: reliable, ordered per peer (kills, floor transitions, pickups...). Each packet carries
//            the oldest events that peer has not acknowledged; the receiver acks the highest in-order
//            id it has delivered.
// Enemy state goes in separate packets (the enemies this player simulates). Every ~2 s each peer is
// told the addresses of the other peers we know, so a player only has to know one of the others.
//
// GML picks the peer it reads with net_sel(slot); net_get / net_age / net_peer_name / net_rank then
// refer to that peer. Events carry the sender's slot (net_ev_get(5)).
//
// Config: hmcoop.txt next to the exe (read by net_start):
//   port=7777                       local UDP port
//   peer=26.1.2.3:7777,26.4.5.6     peers' addresses (comma separated; one is enough, the rest are
//                                   learned); empty = wait for others to talk first
//   name=P1                         shown above your ghost on the other screens
//   skin=jacket                     jacket | beard | richter | corey | jake | son | writer | pardo | henchman | random
//   beard_chance=50                 percent, for skin=random

#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define EXPORT __declspec(dllexport) double __cdecl
#define NFIELDS 32
#define MAGIC 0x34434D48u  /* "HMC4": state + events (carries the mod version, kept from now on) */
#define EMAGIC 0x34454D48u /* "HME4": enemy state packet */
#define PMAGIC 0x34504D48u /* "HMP4": addresses of the other peers we know */
#define MOD_VERSION 70     /* v0.7: compared with the peers', a difference is reported */
#define MAXP 3             /* peers (players besides us) */
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
    unsigned int session;  // random per game launch: a restarted peer resets its event streams
    unsigned int seq;
    char name[16];
    double f[NFIELDS];
    unsigned int ack;  // highest in-order event id we have delivered from this peer
    unsigned int nev;
    Event ev[EV_PER_PACKET];
} Packet;

// Enemy state: the enemies the sender simulates ("owns"), sent ~30 times a second.
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

typedef struct {
    unsigned int magic;
    unsigned int session;
    unsigned int count;
    struct { unsigned int ip; unsigned short port; } a[MAXP];
} PPacket;
#pragma pack(pop)

typedef struct {
    int used;                 // slot holds an address (configured or learned)
    struct sockaddr_in addr;
    unsigned int session;     // peer's session, 0 = not heard yet
    Packet in;
    unsigned int last_seq;
    int have_in;
    DWORD last_rx;
    char name[17];
    // our events to this peer
    Event outq[EV_QUEUE];
    unsigned int out_first, out_next;
    unsigned int rx_next;     // next event id expected from this peer
    // enemy state from this peer
    EPacket es_in;
    unsigned int es_last_seq;
    DWORD es_rx_time;
    int es_have;
    int modver;               // a different mod version seen from this address (0 = older than v0.6)
    DWORD last_old;
    unsigned long n_rx, n_old;
} Peer;

typedef struct {
    Event e;
    int slot;
    unsigned int session;
} InEvent;

static SOCKET sock = INVALID_SOCKET;
static Peer peers[MAXP];
static int sel = 0;
static Packet out;
static EPacket es_out;
static InEvent inq[EV_QUEUE];
static int in_head = 0, in_count = 0;
static char status[256] = "not started";
static unsigned long n_tx = 0, n_err = 0, n_bad = 0, n_ev_tx = 0, n_ev_rx = 0;
static int last_err = 0, my_port = 7777;
static DWORD last_log = 0, last_gossip = 0;
static char logpath[300] = "hmnet_log.txt";
static double skin_pref = 0, beard_chance = 50;
static double tick = 0;
static char local_addrs[200] = "";
static unsigned int local_ip[16];
static int n_local_ip = 0;

#define OLD_RECENT(p) ((p)->n_old && GetTickCount() - (p)->last_old < 3000)

static int alive(const Peer *p) { return p->used && p->have_in && GetTickCount() - p->last_rx < 3000; }

static void write_log(void) {
    DWORD now = GetTickCount();
    if (now - last_log < 2000) return;
    last_log = now;
    FILE *f = fopen(logpath, "w");
    if (!f) return;
    fprintf(f, "status: %s\n", status);
    fprintf(f, "sent: %lu  bad packets: %lu  socket errors: %lu (last %d)  events sent: %lu received: %lu\n",
            n_tx, n_bad, n_err, last_err, n_ev_tx, n_ev_rx);
    for (int i = 0; i < MAXP; i++) {
        Peer *p = &peers[i];
        if (!p->used) continue;
        fprintf(f, "peer %d: %s:%d  name %s  received %lu  last packet %ld ms ago  unacked events %u%s\n", i,
                inet_ntoa(p->addr.sin_addr), ntohs(p->addr.sin_port), p->name[0] ? p->name : "-", p->n_rx,
                p->have_in ? (long)(now - p->last_rx) : -1L, p->out_next - p->out_first,
                p->n_old ? "  WARNING: different mod version - install the same version on every PC" : "");
    }
    fclose(f);
}

static void trim(char *s) {
    size_t n = strlen(s);
    while (n && (s[n - 1] == '\r' || s[n - 1] == '\n' || s[n - 1] == ' ')) s[--n] = 0;
    while (s[0] == ' ') memmove(s, s + 1, strlen(s));
}

static int resolve(const char *hostport, struct sockaddr_in *sa) {
    char host[200];
    int port = 7777;
    strncpy(host, hostport, sizeof host - 1);
    host[sizeof host - 1] = 0;
    trim(host);
    if (!host[0]) return 0;
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

static void find_local_addrs(void) {
    char host[256];
    struct addrinfo hints = {0}, *res = NULL, *r;
    local_addrs[0] = 0;
    n_local_ip = 0;
    local_ip[n_local_ip++] = htonl(INADDR_LOOPBACK);
    if (gethostname(host, sizeof host) != 0) return;
    hints.ai_family = AF_INET;
    if (getaddrinfo(host, NULL, &hints, &res) != 0) return;
    for (r = res; r; r = r->ai_next) {
        struct in_addr ia = ((struct sockaddr_in *)r->ai_addr)->sin_addr;
        unsigned char *b = (unsigned char *)&ia;
        const char *a = inet_ntoa(ia);
        if (n_local_ip < 16) local_ip[n_local_ip++] = ia.s_addr;
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
}

static int is_self(const struct sockaddr_in *a) {
    if (ntohs(a->sin_port) != my_port) return 0;
    for (int i = 0; i < n_local_ip; i++)
        if (local_ip[i] == a->sin_addr.s_addr) return 1;
    return 0;
}

static int same_addr(const struct sockaddr_in *a, const struct sockaddr_in *b) {
    return a->sin_addr.s_addr == b->sin_addr.s_addr && a->sin_port == b->sin_port;
}

static void reset_streams(Peer *p) {
    p->out_first = p->out_next = 1;
    p->rx_next = 1;
    p->have_in = 0;
    p->es_have = 0;
    // drop undelivered events from this peer's previous session
    int k = 0;
    for (int i = 0; i < in_count; i++) {
        InEvent *e = &inq[(in_head + i) % EV_QUEUE];
        if (e->slot == (int)(p - peers)) continue;
        inq[(in_head + k) % EV_QUEUE] = *e;
        k++;
    }
    in_count = k;
}

// slot for this address: existing, or a free one (learned peer); -1 if full / it is us
static int slot_for(const struct sockaddr_in *a, int add) {
    for (int i = 0; i < MAXP; i++)
        if (peers[i].used && same_addr(&peers[i].addr, a)) return i;
    if (!add || is_self(a)) return -1;
    for (int i = 0; i < MAXP; i++)
        if (!peers[i].used) {
            memset(&peers[i], 0, sizeof peers[i]);
            peers[i].used = 1;
            peers[i].addr = *a;
            reset_streams(&peers[i]);
            return i;
        }
    return -1;
}

static void set_peers(const char *list) {
    char buf[400], *s, *ctx = NULL;
    strncpy(buf, list, sizeof buf - 1);
    buf[sizeof buf - 1] = 0;
    for (s = strtok_s(buf, ",;", &ctx); s; s = strtok_s(NULL, ",;", &ctx)) {
        struct sockaddr_in a;
        if (resolve(s, &a)) slot_for(&a, 1);
    }
}

EXPORT net_start(const char *cfgpath) {
    WSADATA w;
    char line[512], peerstr[400] = "";
    if (sock != INVALID_SOCKET) return 1;  // game_restart / game_load re-run the init script
    memset(&out, 0, sizeof out);
    memset(peers, 0, sizeof peers);
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
            if (!strncmp(line, "port=", 5)) my_port = atoi(line + 5);
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
    me.sin_port = htons((u_short)my_port);
    if (bind(sock, (struct sockaddr *)&me, sizeof me) != 0) {
        snprintf(status, sizeof status, "port %d busy", my_port);
        closesocket(sock);
        sock = INVALID_SOCKET;
        return -3;
    }
    find_local_addrs();
    set_peers(peerstr);
    snprintf(status, sizeof status, peerstr[0] ? "port %d -> %s" : "port %d, waiting for players", my_port, peerstr);
    return 1;
}

EXPORT net_set(double i, double v) {
    int k = (int)i;
    if (k >= 0 && k < NFIELDS) out.f[k] = v;
    return 0;
}

static void send_gossip(void) {
    PPacket pp;
    for (int t = 0; t < MAXP; t++) {
        if (!alive(&peers[t])) continue;
        memset(&pp, 0, sizeof pp);
        pp.magic = PMAGIC;
        pp.session = out.session;
        for (int i = 0; i < MAXP; i++) {
            if (i == t || !alive(&peers[i])) continue;
            pp.a[pp.count].ip = peers[i].addr.sin_addr.s_addr;
            pp.a[pp.count].port = peers[i].addr.sin_port;
            pp.count++;
        }
        if (pp.count) sendto(sock, (const char *)&pp, sizeof pp, 0, (struct sockaddr *)&peers[t].addr, sizeof peers[t].addr);
    }
}

EXPORT net_send(void) {
    if (sock == INVALID_SOCKET) return 0;
    int sent = 0;
    out.seq++;
    for (int i = 0; i < MAXP; i++) {
        Peer *p = &peers[i];
        if (!p->used) continue;
        out.ack = p->rx_next - 1;
        unsigned int n = 0;
        for (unsigned int id = p->out_first; id < p->out_next && n < EV_PER_PACKET; id++, n++)
            out.ev[n] = p->outq[id % EV_QUEUE];
        out.nev = n;
        if (sendto(sock, (const char *)&out, sizeof out, 0, (struct sockaddr *)&p->addr, sizeof p->addr) != sizeof out) {
            n_err++;
            last_err = WSAGetLastError();
        } else sent = 1;
    }
    if (sent) n_tx++;
    if (GetTickCount() - last_gossip > 2000) { last_gossip = GetTickCount(); send_gossip(); }
    return sent;
}

static void take_events(Peer *p, int slot, const Packet *pk) {
    // peer acknowledged our events up to pk->ack
    while (p->out_first < p->out_next && (int)(pk->ack - p->out_first) >= 0) p->out_first++;
    for (unsigned int k = 0; k < pk->nev && k < EV_PER_PACKET; k++) {
        const Event *e = &pk->ev[k];
        if (e->id != p->rx_next) continue;  // duplicate or out of order: it will be resent
        if (in_count < EV_QUEUE) {
            InEvent *q = &inq[(in_head + in_count) % EV_QUEUE];
            q->e = *e;
            q->slot = slot;
            q->session = p->session;
            in_count++;
        }
        p->rx_next++;
        n_ev_rx++;
    }
}

// Drain the socket; keep each peer's newest state, deliver events. Returns 1 if something new arrived.
EXPORT net_poll(void) {
    if (sock == INVALID_SOCKET) return 0;
    int got = 0;
    static union { Packet p; EPacket ep; PPacket pp; char raw[2048]; } buf;
    for (;;) {
        struct sockaddr_in from;
        int fl = sizeof from;
        int n = recvfrom(sock, buf.raw, sizeof buf.raw, 0, (struct sockaddr *)&from, &fl);
        if (n < 0) {
            int e = WSAGetLastError();
            if (e == WSAEWOULDBLOCK) break;
            n_err++;
            last_err = e;
            if (e != WSAECONNRESET && e != WSAEMSGSIZE) break;
            continue;
        }
        if (n < 8) { n_bad++; continue; }
        unsigned int magic = buf.p.magic;
        if (magic == PMAGIC && n == (int)sizeof(PPacket)) {  // addresses of players our peer knows
            int s = slot_for(&from, 0);
            if (s < 0 || !peers[s].have_in || buf.pp.session != peers[s].session) continue;
            for (unsigned int i = 0; i < buf.pp.count && i < MAXP; i++) {
                struct sockaddr_in a = {0};
                a.sin_family = AF_INET;
                a.sin_addr.s_addr = buf.pp.a[i].ip;
                a.sin_port = buf.pp.a[i].port;
                slot_for(&a, 1);
            }
            continue;
        }
        if (magic == EMAGIC && n >= 16) {
            int s = slot_for(&from, 0);
            if (s < 0) continue;
            Peer *p = &peers[s];
            unsigned int cnt = buf.ep.count;
            if (cnt <= ES_MAX && n == (int)(16 + cnt * sizeof(EState)) && p->have_in && buf.ep.session == p->session &&
                (!p->es_have || (int)(buf.ep.seq - p->es_last_seq) > 0 || (int)(p->es_last_seq - buf.ep.seq) > 600)) {
                memcpy(&p->es_in, &buf.ep, n);
                p->es_last_seq = buf.ep.seq;
                p->es_rx_time = GetTickCount();
                p->es_have = 1;
            }
            continue;
        }
        // other mod versions: remember to tell the player
        if ((magic & 0xFFFFFF) == (MAGIC & 0xFFFFFF) || magic == 0x484D4350u) {
            int bad = magic != MAGIC || n != (int)sizeof(Packet) || buf.p.modver != MOD_VERSION;
            if (bad) {
                int s = slot_for(&from, 1);
                if (s >= 0) {
                    peers[s].n_old++;
                    peers[s].last_old = GetTickCount();
                    peers[s].modver = (magic == MAGIC) ? (int)buf.p.modver : 0;
                }
                continue;
            }
        }
        if (n != (int)sizeof(Packet) || magic != MAGIC) { n_bad++; continue; }
        if (buf.p.session == out.session) continue;  // our own packet (we are listed as a peer)
        int s = slot_for(&from, 1);
        if (s < 0) continue;  // all slots taken
        Peer *p = &peers[s];
        // the same player known under two addresses (e.g. gossip): keep the first slot
        int dup = 0;
        for (int i = 0; i < MAXP; i++)
            if (i != s && peers[i].used && peers[i].have_in && peers[i].session == buf.p.session) dup = 1;
        if (dup) { p->used = 0; continue; }
        if (buf.p.session != p->session) {  // peer (re)started: both event streams begin again at id 1
            p->session = buf.p.session;
            reset_streams(p);
        }
        p->n_rx++;
        take_events(p, s, &buf.p);  // events are processed even from late packets (ids dedupe them)
        if (p->have_in && (int)(buf.p.seq - p->last_seq) <= 0 && (int)(p->last_seq - buf.p.seq) < 600) continue;  // stale
        memcpy(&p->in, &buf.p, sizeof p->in);
        p->last_seq = buf.p.seq;
        p->have_in = 1;
        p->last_rx = GetTickCount();
        memcpy(p->name, buf.p.name, 16);
        p->name[16] = 0;
        got = 1;
    }
    write_log();
    return got;
}

// ---- peers
EXPORT net_peers(void) { return MAXP; }
EXPORT net_sel(double slot) {
    int s = (int)slot;
    sel = (s >= 0 && s < MAXP) ? s : 0;
    return sel;
}
// field of the selected peer's latest state (0 when nothing heard)
EXPORT net_get(double i) {
    int k = (int)i;
    Peer *p = &peers[sel];
    return (p->used && p->have_in && k >= 0 && k < NFIELDS) ? p->in.f[k] : 0;
}
// milliseconds since the selected peer's last packet, or -1 if never
EXPORT net_age(void) {
    Peer *p = &peers[sel];
    return p->used && p->have_in ? (double)(GetTickCount() - p->last_rx) : -1;
}
// deterministic tie-break with the selected peer: 1 on exactly one side
EXPORT net_rank(void) { return out.session < peers[sel].session ? 1 : 0; }
// the selected peer's session (stable id for this game launch), 0 if unknown
EXPORT net_psession(void) { return peers[sel].have_in ? peers[sel].session : 0; }
__declspec(dllexport) const char *__cdecl net_peer_name(void) { return peers[sel].name; }

// ---- reliable events
static int enqueue(Peer *p, double type, double a, double b, double c, double d) {
    if (p->out_next - p->out_first >= EV_QUEUE - 1) return 0;  // queue full (peer gone for a long time)
    Event *e = &p->outq[p->out_next % EV_QUEUE];
    e->id = p->out_next++;
    e->type = (unsigned int)type;
    e->a[0] = a;
    e->a[1] = b;
    e->a[2] = c;
    e->a[3] = d;
    return 1;
}
// to every peer
EXPORT net_event(double type, double a, double b, double c) {
    for (int i = 0; i < MAXP; i++)
        if (peers[i].used) enqueue(&peers[i], type, a, b, c, 0);
    n_ev_tx++;
    return 1;
}
EXPORT net_event4(double type, double a, double b, double c, double d) {
    for (int i = 0; i < MAXP; i++)
        if (peers[i].used) enqueue(&peers[i], type, a, b, c, d);
    n_ev_tx++;
    return 1;
}
// to one peer (enemy handoff, revive)
EXPORT net_event4_to(double slot, double type, double a, double b, double c, double d) {
    int s = (int)slot;
    if (s < 0 || s >= MAXP || !peers[s].used) return 0;
    n_ev_tx++;
    return enqueue(&peers[s], type, a, b, c, d);
}

EXPORT net_ev_count(void) { return in_count; }

// field 0 = type, 1..4 = a, b, c, d, 5 = sender's slot of the oldest unread event
EXPORT net_ev_get(double k) {
    if (!in_count) return 0;
    InEvent *e = &inq[in_head];
    int i = (int)k;
    return i == 0 ? (double)e->e.type : (i >= 1 && i <= 4) ? e->e.a[i - 1] : i == 5 ? e->slot : 0;
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
    if (sock == INVALID_SOCKET) return 0;
    es_out.magic = EMAGIC;
    es_out.session = out.session;
    es_out.seq++;
    int len = 16 + es_out.count * sizeof(EState), ok = 0;
    for (int i = 0; i < MAXP; i++)
        if (alive(&peers[i]) && sendto(sock, (const char *)&es_out, len, 0, (struct sockaddr *)&peers[i].addr, sizeof peers[i].addr) == len) ok = 1;
    return ok;
}

// field of the latest state some peer sends for enemy uid: 0 obj, 1 x, 2 y, 3 dir, 4 sprite, 5 frame,
// 6 alert, 7 the sending peer's slot. -100000 when no peer currently simulates it (or the data is stale).
EXPORT net_es_get(double uid, double field) {
    int u = (int)uid;
    for (int s = 0; s < MAXP; s++) {
        Peer *p = &peers[s];
        if (!p->used || !p->es_have || GetTickCount() - p->es_rx_time > 1000) continue;
        for (unsigned int i = 0; i < p->es_in.count; i++) {
            EState *e = &p->es_in.e[i];
            if (e->uid != u) continue;
            switch ((int)field) {
                case 0: return e->obj;
                case 1: return e->x;
                case 2: return e->y;
                case 3: return e->dir;
                case 4: return e->spr;
                case 5: return e->img;
                case 6: return e->alert;
                case 7: return s;
            }
            return 0;
        }
    }
    return -100000;
}

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

static Peer *old_peer(void) {
    for (int i = 0; i < MAXP; i++)
        if (peers[i].used && OLD_RECENT(&peers[i])) return &peers[i];
    return NULL;
}

__declspec(dllexport) const char *__cdecl net_status(void) {
    static char msg[160];
    Peer *p = old_peer();
    if (!p) return status;
    if (p->modver)
        snprintf(msg, sizeof msg, "a player has mod v%d.%d, you have v%d.%d - install the same version",
                 p->modver / 100, p->modver % 100 / 10, MOD_VERSION / 100, MOD_VERSION % 100 / 10);
    else
        snprintf(msg, sizeof msg, "a player has an older mod version, you have v%d.%d - install the same version",
                 MOD_VERSION / 100, MOD_VERSION % 100 / 10);
    return msg;
}
// 1 while some peer's packets are rejected because of a different mod version
EXPORT net_version_mismatch(void) { return old_peer() ? 1 : 0; }
// our local / VPN IPv4 addresses (Radmin shows up as 26.x.x.x)
__declspec(dllexport) const char *__cdecl net_local(void) { return local_addrs; }
// peers' addresses (comma separated) added while running (in-game menu); known ones stay
EXPORT net_set_peer(const char *list) {
    int before = 0, after = 0;
    for (int i = 0; i < MAXP; i++) before += peers[i].used;
    set_peers(list);
    for (int i = 0; i < MAXP; i++) after += peers[i].used;
    snprintf(status, sizeof status, "port %d -> %s", my_port, list);
    return after > before || after > 0;
}
EXPORT net_set_name(const char *name) {
    strncpy(out.name, name, 15);
    out.name[15] = 0;
    return 1;
}
