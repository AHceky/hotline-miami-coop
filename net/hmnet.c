// hmnet.dll - UDP link for the Hotline Miami co-op mod (up to 4 players: you + 3 peers).
// Called from GameMaker 7 GML via external_define(..., dll_cdecl, ...).
//
// Every player talks to every other player directly (full mesh). To each peer, one packet per step:
//  * state:  NFIELDS doubles, newest packet wins (sequence numbers drop late datagrams);
//  * events: reliable, ordered per peer (kills, floor transitions, pickups...). Each packet carries
//            the oldest events that peer has not acknowledged; the receiver acks the highest in-order
//            id it has delivered;
//  * unreliable events after them (bullets): sent once, a lost one is simply not seen.
// Packets only carry the events they have, so their length varies.
// Enemy state goes in separate packets (the enemies this player simulates, in pages of ES_PAGE). Every
// ~2 s each peer is told the addresses of the other peers we know, so a player only has to know one of
// the others. A slot that never answers is retried a few times a second only, and is given up (or
// reused for a new player) after a while.
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
//   room=word                       room code, the same for every player (empty = none): packets with
//                                   another code are ignored, so strangers on the network cannot join

#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <ctype.h>

#define EXPORT __declspec(dllexport) double __cdecl
#define NFIELDS 32
#define MAGIC 0x34434D48u  /* "HMC4": state + events (carries the mod version, kept from now on) */
#define EMAGIC 0x35454D48u /* "HME5": enemy state page */
#define PMAGIC 0x34504D48u /* "HMP4": addresses of the other peers we know */
#define MOD_VERSION 90     /* v0.9: compared with the peers', a difference is reported */
#define MAXP 3             /* peers (players besides us) */
#define ES_PAGE 48         /* enemies per enemy-state packet */
#define ES_PAGES 4         /* -> up to 192 enemies sent */
#define ES_MAX (ES_PAGE * ES_PAGES)
#define EV_REL 16          /* reliable events per packet */
#define EV_UNREL 8         /* unreliable events per packet */
#define EV_PER_PACKET (EV_REL + EV_UNREL)
#define EV_QUEUE 1024
#define UQ_MAX 128         /* unreliable events waiting for the next packets */
#define PROBE_EVERY 15     /* steps between packets to a peer that does not answer */
#define GIVEUP_SILENT 15000  /* ms: a learned address that never answered is forgotten */
#define GIVEUP_GONE 60000    /* ms: a learned peer silent this long is forgotten */
#define REUSE_AFTER 10000    /* ms: a silent slot may be taken by a new player when all are used */
#define REL_PER_POLL 64      /* reliable events taken from one peer per net_poll (the rest come again) */
#define UNREL_PER_POLL 32    /* unreliable events taken from one peer per net_poll (the rest are dropped) */

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
    unsigned int room;     // hash of the room code (0 = none): other codes are ignored
    unsigned int ack_session;  // our session as the sender knows it: "ack" is about that stream only
    char name[16];
    double f[NFIELDS];
    unsigned int ack;    // highest in-order event id we have delivered from this peer
    unsigned short nev;  // reliable events (ids from the sender's stream to us)
    unsigned short nuev; // unreliable events after them
    Event ev[EV_PER_PACKET];
} Packet;
#define PK_HEAD ((int)offsetof(Packet, ev))

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
    unsigned int room;
    unsigned int seq;
    unsigned int count;
    unsigned short page, npages;
    EState e[ES_PAGE];
} EPacket;
#define EP_HEAD ((int)offsetof(EPacket, e))

typedef struct {
    unsigned int magic;
    unsigned int session;
    unsigned int room;
    unsigned int count;
    struct { unsigned int ip; unsigned short port; } a[MAXP];
} PPacket;
#pragma pack(pop)

typedef struct {
    int used;                 // slot holds an address (configured or learned)
    int configured;           // typed by the player (hmcoop.txt / menu), not learned
    DWORD added;              // when the slot was taken
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
    unsigned long n_overflow; // events that did not fit in outq (link too slow / peer gone)
    // enemy state from this peer, by page; a page counts while it is from one of the newest seqs
    EState es_pg[ES_PAGES][ES_PAGE];
    unsigned int es_pg_cnt[ES_PAGES], es_pg_seq[ES_PAGES];
    unsigned int es_npages;
    unsigned int es_last_seq;
    DWORD es_rx_time;
    int es_have;
    unsigned long n_rx;
    int poll_rel, poll_unrel;  // events taken in the current net_poll
} Peer;

// a different mod version / room code heard recently (a slot is not given to such a sender)
static struct { struct sockaddr_in addr; int modver; DWORD t; unsigned long n; } mism, wrongroom;
static unsigned int room_hash = 0;  // our room code, hashed (0 = none)

typedef struct {
    Event e;
    int slot;
    unsigned int session;
} InEvent;

static SOCKET sock = INVALID_SOCKET;
static Peer peers[MAXP];
static int sel = 0;
static Packet out;
static EState es_all[ES_MAX];
static unsigned int es_count = 0, es_seq = 0;
static Event uq[UQ_MAX];
static int uq_n = 0;
static InEvent inq[EV_QUEUE];
static int in_head = 0, in_count = 0;
static char status[256] = "not started";
static unsigned long n_tx = 0, n_err = 0, n_bad = 0, n_ev_tx = 0, n_ev_rx = 0, n_udrop = 0, n_send = 0;
static int overflow_seen = 0;
static int last_err = 0, my_port = 7777;
static DWORD last_log = 0, last_gossip = 0;
static char logpath[300] = "hmnet_log.txt";
static double skin_pref = 0, beard_chance = 50;
static double tick = 0;
static char local_addrs[200] = "";
static unsigned int local_ip[16];
static int n_local_ip = 0;

// Test aid: HMNET_LOSS=<percent> in the environment drops that share of outgoing datagrams.
static int loss_pct = 0;
static int xsend(const void *buf, int len, const struct sockaddr *to, int tolen) {
    if (loss_pct > 0 && rand() % 100 < loss_pct) return len;
    return sendto(sock, (const char *)buf, len, 0, to, tolen);
}

static int mism_recent(void) { return mism.n && GetTickCount() - mism.t < 3000; }
static int wrongroom_recent(void) { return wrongroom.n && GetTickCount() - wrongroom.t < 3000; }

// room code -> 32-bit FNV-1a of the trimmed, lower-case text; 0 for no code
static unsigned int room_of(const char *code) {
    unsigned int h = 2166136261u;
    int any = 0;
    for (const unsigned char *c = (const unsigned char *)code; *c; c++) {
        if (*c <= ' ') continue;
        h = (h ^ (unsigned char)tolower(*c)) * 16777619u;
        any = 1;
    }
    return any ? (h ? h : 1) : 0;
}

static int alive(const Peer *p) { return p->used && p->have_in && GetTickCount() - p->last_rx < 3000; }

// "0.8", "0.61"
static void ver_str(char *s, size_t n, int v) {
    if (v % 10) snprintf(s, n, "%d.%02d", v / 100, v % 100);
    else snprintf(s, n, "%d.%d", v / 100, v % 100 / 10);
}

static void write_log(void) {
    DWORD now = GetTickCount();
    if (now - last_log < 2000) return;
    last_log = now;
    FILE *f = fopen(logpath, "w");
    if (!f) return;
    fprintf(f, "status: %s\n", status);
    fprintf(f, "sent: %lu  bad packets: %lu  socket errors: %lu (last %d)  events sent: %lu received: %lu"
               "  unreliable dropped: %lu\n", n_tx, n_bad, n_err, last_err, n_ev_tx, n_ev_rx, n_udrop);
    for (int i = 0; i < MAXP; i++) {
        Peer *p = &peers[i];
        if (!p->used) continue;
        fprintf(f, "peer %d: %s:%d%s  name %s  received %lu  last packet %ld ms ago  unacked events %u%s\n", i,
                inet_ntoa(p->addr.sin_addr), ntohs(p->addr.sin_port), p->configured ? "" : " (learned)",
                p->name[0] ? p->name : "-", p->n_rx, p->have_in ? (long)(now - p->last_rx) : -1L,
                p->out_next - p->out_first, p->n_overflow ? "  WARNING: event queue overflowed" : "");
    }
    if (mism.n) {
        char v[16];
        ver_str(v, sizeof v, mism.modver);
        fprintf(f, "WARNING: %s:%d has mod v%s (%lu packets ignored) - install the same version on every PC\n",
                inet_ntoa(mism.addr.sin_addr), ntohs(mism.addr.sin_port), mism.modver ? v : "<0.6", mism.n);
    }
    if (wrongroom.n)
        fprintf(f, "WARNING: %s:%d uses another room code (%lu packets ignored) - set the same room= on every PC\n",
                inet_ntoa(wrongroom.addr.sin_addr), ntohs(wrongroom.addr.sin_port), wrongroom.n);
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
    if (c) {
        *c = 0;
        port = atoi(c + 1);
        if (port <= 0 || port > 65535) return 0;
    }
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
    p->es_npages = 0;
    p->es_last_seq = 0;
    memset(p->es_pg_seq, 0, sizeof p->es_pg_seq);
    memset(p->es_pg_cnt, 0, sizeof p->es_pg_cnt);
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

static void free_slot(Peer *p) {
    reset_streams(p);
    p->used = 0;
}

// a slot nobody is talking through: may be given to a new player when all are used
static int reusable(const Peer *p, DWORD now) {
    if (alive(p)) return 0;
    return p->have_in ? now - p->last_rx > REUSE_AFTER : now - p->added > REUSE_AFTER;
}

// slot for this address: existing, or a free one (learned peer); -1 if full / it is us.
// add: 0 = existing only, 1 = may also reuse a dead slot, 2 = free slots only
static int slot_for(const struct sockaddr_in *a, int add) {
    for (int i = 0; i < MAXP; i++)
        if (peers[i].used && same_addr(&peers[i].addr, a)) return i;
    if (!add || is_self(a)) return -1;
    DWORD now = GetTickCount();
    int s = -1;
    for (int i = 0; i < MAXP && s < 0; i++)
        if (!peers[i].used) s = i;
    // all used: take a dead one, learned addresses first
    for (int i = 0; i < MAXP && s < 0 && add == 1; i++)
        if (!peers[i].configured && reusable(&peers[i], now)) s = i;
    for (int i = 0; i < MAXP && s < 0 && add == 1; i++)
        if (reusable(&peers[i], now)) s = i;
    if (s < 0) return -1;
    if (peers[s].used) free_slot(&peers[s]);
    memset(&peers[s], 0, sizeof peers[s]);
    peers[s].used = 1;
    peers[s].added = now;
    peers[s].addr = *a;
    reset_streams(&peers[s]);
    return s;
}

static void set_peers(const char *list) {
    char buf[400], *s, *ctx = NULL;
    strncpy(buf, list, sizeof buf - 1);
    buf[sizeof buf - 1] = 0;
    for (s = strtok_s(buf, ",;", &ctx); s; s = strtok_s(NULL, ",;", &ctx)) {
        struct sockaddr_in a;
        if (!resolve(s, &a)) continue;
        int k = slot_for(&a, 1);
        if (k >= 0) {
            peers[k].configured = 1;
            peers[k].added = GetTickCount();
        }
    }
}

// learned addresses that never answered / peers gone for good: free the slot
static void expire_slots(void) {
    DWORD now = GetTickCount();
    for (int i = 0; i < MAXP; i++) {
        Peer *p = &peers[i];
        if (!p->used || p->configured) continue;
        if (!p->have_in ? now - p->added > GIVEUP_SILENT : now - p->last_rx > GIVEUP_GONE) free_slot(p);
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
    LARGE_INTEGER qpc;
    QueryPerformanceCounter(&qpc);
    out.session = GetTickCount() ^ (GetCurrentProcessId() << 16) ^ 0x9E3779B9u ^ qpc.LowPart ^ (unsigned int)(size_t)&out;
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
            else if (!strncmp(line, "room=", 5)) room_hash = room_of(line + 5);
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
    out.room = room_hash;
    const char *lp = getenv("HMNET_LOSS");
    if (lp) { loss_pct = atoi(lp); srand(GetTickCount() ^ GetCurrentProcessId()); }
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
        pp.room = room_hash;
        for (int i = 0; i < MAXP; i++) {
            if (i == t || !alive(&peers[i])) continue;
            pp.a[pp.count].ip = peers[i].addr.sin_addr.s_addr;
            pp.a[pp.count].port = peers[i].addr.sin_port;
            pp.count++;
        }
        if (pp.count) xsend(&pp, sizeof pp, (struct sockaddr *)&peers[t].addr, sizeof peers[t].addr);
    }
}

EXPORT net_send(void) {
    if (sock == INVALID_SOCKET) return 0;
    int sent = 0;
    unsigned int nu = uq_n < EV_UNREL ? uq_n : EV_UNREL;
    out.seq++;
    n_send++;
    expire_slots();
    for (int i = 0; i < MAXP; i++) {
        Peer *p = &peers[i];
        if (!p->used) continue;
        // nobody answers there (yet): knock a few times a second only
        if (!alive(p) && (n_send + i) % PROBE_EVERY) continue;
        out.ack = p->rx_next - 1;
        out.ack_session = p->session;
        unsigned int n = 0;
        for (unsigned int id = p->out_first; id < p->out_next && n < EV_REL; id++, n++)
            out.ev[n] = p->outq[id % EV_QUEUE];
        out.nev = (unsigned short)n;
        out.nuev = alive(p) ? (unsigned short)nu : 0;
        memcpy(&out.ev[n], uq, out.nuev * sizeof(Event));
        int len = PK_HEAD + (n + out.nuev) * (int)sizeof(Event);
        if (xsend(&out, len, (struct sockaddr *)&p->addr, sizeof p->addr) != len) {
            n_err++;
            last_err = WSAGetLastError();
        } else sent = 1;
    }
    // unreliable events that went out (or had nobody to go to) are done; the rest wait for the next step
    memmove(uq, uq + nu, (uq_n - nu) * sizeof(Event));
    uq_n -= nu;
    if (sent) n_tx++;
    if (GetTickCount() - last_gossip > 2000) { last_gossip = GetTickCount(); send_gossip(); }
    return sent;
}

static void deliver(int slot, const Event *e, unsigned int session) {
    InEvent *q = &inq[(in_head + in_count) % EV_QUEUE];
    q->e = *e;
    q->slot = slot;
    q->session = session;
    in_count++;
}

// acks and reliable events: from any packet of this session, late ones too (ids dedupe them)
static void take_events(Peer *p, int slot, const Packet *pk) {
    // peer acknowledged our events up to pk->ack (an ack about an earlier session of ours means nothing)
    if (pk->ack_session == out.session)
        while (p->out_first < p->out_next && (int)(pk->ack - p->out_first) >= 0) p->out_first++;
    for (unsigned int k = 0; k < pk->nev; k++) {
        const Event *e = &pk->ev[k];
        if (e->id != p->rx_next) continue;  // duplicate or out of order: it will be resent
        // GML is not reading, or this peer floods us: not acked, so it comes again later
        if (in_count >= EV_QUEUE || p->poll_rel >= REL_PER_POLL) break;
        deliver(slot, e, p->session);
        p->rx_next++;
        p->poll_rel++;
        n_ev_rx++;
    }
}

// unreliable events: only from a packet newer than any before (a late or doubled datagram would
// replay its bullets)
static void take_unreliable(Peer *p, int slot, const Packet *pk) {
    for (unsigned int k = pk->nev; k < (unsigned int)pk->nev + pk->nuev; k++) {
        if (in_count >= EV_QUEUE || p->poll_unrel >= UNREL_PER_POLL) { n_udrop++; continue; }
        deliver(slot, &pk->ev[k], p->session);
        p->poll_unrel++;
    }
}

// Drain the socket; keep each peer's newest state, deliver events. Returns 1 if something new arrived.
EXPORT net_poll(void) {
    if (sock == INVALID_SOCKET) return 0;
    int got = 0;
    static union { Packet p; EPacket ep; PPacket pp; char raw[2048]; } buf;
    for (int i = 0; i < MAXP; i++) peers[i].poll_rel = peers[i].poll_unrel = 0;
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
            if (s < 0 || !peers[s].have_in || buf.pp.session != peers[s].session || buf.pp.room != room_hash) continue;
            for (unsigned int i = 0; i < buf.pp.count && i < MAXP; i++) {
                struct sockaddr_in a = {0};
                a.sin_family = AF_INET;
                a.sin_addr.s_addr = buf.pp.a[i].ip;
                a.sin_port = buf.pp.a[i].port;
                slot_for(&a, 2);
            }
            continue;
        }
        if (magic == EMAGIC && n >= EP_HEAD) {
            int s = slot_for(&from, 0);
            if (s < 0) continue;
            Peer *p = &peers[s];
            unsigned int cnt = buf.ep.count, pg = buf.ep.page, np = buf.ep.npages;
            if (cnt > ES_PAGE || n != EP_HEAD + (int)(cnt * sizeof(EState)) || pg >= ES_PAGES || np > ES_PAGES ||
                pg >= np || !p->have_in || buf.ep.session != p->session || buf.ep.room != room_hash) { n_bad++; continue; }
            int newer = !p->es_have || (int)(buf.ep.seq - p->es_last_seq) > 0 || (int)(p->es_last_seq - buf.ep.seq) > 600;
            if (newer || (int)(buf.ep.seq - p->es_pg_seq[pg]) > 0) {
                memcpy(p->es_pg[pg], buf.ep.e, cnt * sizeof(EState));
                p->es_pg_cnt[pg] = cnt;
                p->es_pg_seq[pg] = buf.ep.seq;
            }
            if (newer) {
                p->es_last_seq = buf.ep.seq;
                p->es_npages = np;
                p->es_rx_time = GetTickCount();
                p->es_have = 1;
            }
            continue;
        }
        // other mod versions: tell the player (no slot for them)
        if ((magic & 0xFFFFFF) == (MAGIC & 0xFFFFFF) || magic == 0x484D4350u) {
            if (magic != MAGIC || buf.p.modver != MOD_VERSION) {
                if (!is_self(&from)) {
                    mism.addr = from;
                    mism.modver = (magic == MAGIC) ? (int)buf.p.modver : 0;
                    mism.t = GetTickCount();
                    mism.n++;
                }
                continue;
            }
        }
        if (magic != MAGIC || n < PK_HEAD || buf.p.nev > EV_REL || buf.p.nuev > EV_UNREL ||
            n != PK_HEAD + (int)((buf.p.nev + buf.p.nuev) * sizeof(Event))) { n_bad++; continue; }
        if (buf.p.session == out.session) continue;  // our own packet (we are listed as a peer)
        if (buf.p.room != room_hash) {  // another room code: not one of our players
            if (!is_self(&from)) {
                wrongroom.addr = from;
                wrongroom.t = GetTickCount();
                wrongroom.n++;
            }
            continue;
        }
        int s = slot_for(&from, 1);
        if (s < 0) continue;  // all slots taken
        Peer *p = &peers[s];
        // the same player known under another address: while it still talks from there, this is a
        // second route (gossip) and is dropped; if it went quiet there, the player moved (VPN relay,
        // NAT): the old slot takes the new address and keeps its streams
        for (int i = 0; i < MAXP; i++) {
            if (i == s || !peers[i].used || !peers[i].have_in || peers[i].session != buf.p.session) continue;
            if (GetTickCount() - peers[i].last_rx < 1500) { free_slot(p); p = NULL; break; }
            free_slot(p);
            peers[i].addr = from;
            s = i;
            p = &peers[i];
            break;
        }
        if (!p) continue;
        if (buf.p.session != p->session) {  // peer (re)started: both event streams begin again at id 1
            p->session = buf.p.session;
            reset_streams(p);
        }
        p->n_rx++;
        take_events(p, s, &buf.p);
        if (p->have_in && (int)(buf.p.seq - p->last_seq) <= 0 && (int)(p->last_seq - buf.p.seq) < 600) continue;  // stale
        take_unreliable(p, s, &buf.p);
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
// Events go only to peers we have heard: the first packet of a peer restarts both streams anyway.
static int enqueue(Peer *p, double type, double a, double b, double c, double d) {
    if (!p->have_in) return 0;
    if (p->out_next - p->out_first >= EV_QUEUE - 1) {  // queue full: link far too slow, or peer gone
        p->n_overflow++;
        overflow_seen = 1;
        return 0;
    }
    Event *e = &p->outq[p->out_next % EV_QUEUE];
    e->id = p->out_next++;
    e->type = (unsigned int)type;
    e->a[0] = a;
    e->a[1] = b;
    e->a[2] = c;
    e->a[3] = d;
    return 1;
}
// to every peer; 0 if some connected peer's queue was full
EXPORT net_event(double type, double a, double b, double c) {
    int ok = 1;
    for (int i = 0; i < MAXP; i++)
        if (peers[i].used && !enqueue(&peers[i], type, a, b, c, 0) && alive(&peers[i])) ok = 0;
    n_ev_tx++;
    return ok;
}
EXPORT net_event4(double type, double a, double b, double c, double d) {
    int ok = 1;
    for (int i = 0; i < MAXP; i++)
        if (peers[i].used && !enqueue(&peers[i], type, a, b, c, d) && alive(&peers[i])) ok = 0;
    n_ev_tx++;
    return ok;
}
// to every connected peer, once, no resend (bullets: one lost is just not drawn)
EXPORT net_uevent4(double type, double a, double b, double c, double d) {
    if (uq_n >= UQ_MAX) { n_udrop++; return 0; }
    Event *e = &uq[uq_n++];
    e->id = 0;
    e->type = (unsigned int)type;
    e->a[0] = a;
    e->a[1] = b;
    e->a[2] = c;
    e->a[3] = d;
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
EXPORT net_es_begin(void) { es_count = 0; return 0; }

EXPORT net_es_add(double uid, double obj, double x, double y, double dir, double spr, double img, double alert) {
    if (es_count >= ES_MAX) return 0;
    EState *e = &es_all[es_count++];
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
    static EPacket ep;
    unsigned int np = es_count ? (es_count + ES_PAGE - 1) / ES_PAGE : 1;
    int ok = 0;
    ep.magic = EMAGIC;
    ep.session = out.session;
    ep.room = room_hash;
    ep.seq = ++es_seq;
    ep.npages = (unsigned short)np;
    for (unsigned int pg = 0; pg < np; pg++) {
        unsigned int first = pg * ES_PAGE, cnt = es_count - first < ES_PAGE ? es_count - first : ES_PAGE;
        if (es_count == 0) cnt = 0;
        ep.page = (unsigned short)pg;
        ep.count = cnt;
        memcpy(ep.e, es_all + first, cnt * sizeof(EState));
        int len = EP_HEAD + (int)(cnt * sizeof(EState));
        for (int i = 0; i < MAXP; i++)
            if (alive(&peers[i]) && xsend(&ep, len, (struct sockaddr *)&peers[i].addr, sizeof peers[i].addr) == len) ok = 1;
    }
    return ok;
}

// the state peer p currently sends for enemy uid, or NULL (a page counts if it is at most 4 sends old,
// so one lost page does not make its enemies look abandoned)
static EState *es_find(Peer *p, int u) {
    if (!p->used || !p->es_have || GetTickCount() - p->es_rx_time > 1000) return NULL;
    for (unsigned int pg = 0; pg < p->es_npages && pg < ES_PAGES; pg++) {
        if ((int)(p->es_last_seq - p->es_pg_seq[pg]) > 4) continue;
        for (unsigned int i = 0; i < p->es_pg_cnt[pg]; i++)
            if (p->es_pg[pg][i].uid == u) return &p->es_pg[pg][i];
    }
    return NULL;
}

// field of the latest state some peer sends for enemy uid: 0 obj, 1 x, 2 y, 3 dir, 4 sprite, 5 frame,
// 6 alert, 7 the sending peer's slot. -100000 when no peer currently simulates it (or the data is stale).
EXPORT net_es_get(double uid, double field) {
    int u = (int)uid;
    for (int s = 0; s < MAXP; s++) {
        EState *e = es_find(&peers[s], u);
        if (!e) continue;
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
    return -100000;
}
// 1 if peer slot currently sends enemy uid (more than one peer may, until they sort it out)
EXPORT net_es_by(double uid, double slot) {
    int s = (int)slot;
    return (s >= 0 && s < MAXP && es_find(&peers[s], (int)uid)) ? 1 : 0;
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

__declspec(dllexport) const char *__cdecl net_status(void) {
    static char msg[160];
    char mine[16], theirs[16];
    ver_str(mine, sizeof mine, MOD_VERSION);
    if (mism_recent()) {
        ver_str(theirs, sizeof theirs, mism.modver);
        if (mism.modver)
            snprintf(msg, sizeof msg, "a player has mod v%s, you have v%s - install the same version", theirs, mine);
        else
            snprintf(msg, sizeof msg, "a player has an older mod version, you have v%s - install the same version", mine);
        return msg;
    }
    if (wrongroom_recent()) {
        snprintf(msg, sizeof msg, "a player uses another room code - set the same code on every PC");
        return msg;
    }
    if (overflow_seen) {
        snprintf(msg, sizeof msg, "connection too slow: game events were lost (see hmnet_log.txt)");
        return msg;
    }
    return status;
}
// 1 while some peer's packets are rejected because of a different mod version or room code
EXPORT net_version_mismatch(void) { return mism_recent() || wrongroom_recent() ? 1 : 0; }
// 1 once events could not be queued for a connected peer (the games may differ from then on)
EXPORT net_overflow(void) { return overflow_seen; }
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
// room code changed in the in-game menu (players with the old code drop out after a few seconds)
EXPORT net_set_room(const char *code) {
    room_hash = room_of(code);
    out.room = room_hash;
    return room_hash != 0;
}
EXPORT net_set_name(const char *name) {
    strncpy(out.name, name, 15);
    out.name[15] = 0;
    return 1;
}
