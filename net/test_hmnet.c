// Protocol test for hmnet.dll: four copies of the DLL in one process (each copy has its own state)
// play four players on 127.0.0.1, with HMNET_LOSS percent of datagrams dropped.
//
//   zig cc -target x86-windows-gnu -O2 -o test_hmnet.exe test_hmnet.c -lws2_32
//   test_hmnet.exe <folder with hmnet.dll> [loss percent, default 20]
//
// Checks: the mesh forms from one known address each; reliable events arrive once, in order, none lost;
// unreliable events arrive at most once; 150 enemies (4 pages) are all readable on the other side;
// a packet of another mod version is reported and takes no slot; a dead configured slot is reused.
#include <winsock2.h>
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef double(__cdecl *F0)(void);
typedef double(__cdecl *F1)(double);
typedef double(__cdecl *F2)(double, double);
typedef double(__cdecl *F4)(double, double, double, double);
typedef double(__cdecl *F5)(double, double, double, double, double);
typedef double(__cdecl *F8)(double, double, double, double, double, double, double, double);
typedef double(__cdecl *FS)(const char *);

typedef struct {
    HMODULE h;
    FS start;
    F0 send, poll, ev_count, ev_pop, age, es_begin, es_send, mismatch, overflow;
    F1 sel, ev_get, get;
    F2 set, es_get, es_by;
    F5 event4, uevent4;
    F8 es_add;
} Net;

static int fails = 0;
#define CHECK(c, ...) do { if (c) printf("  ok    "); else { printf("  FAIL  "); fails++; } printf(__VA_ARGS__); printf("\n"); } while (0)

static void load(Net *n, const char *dir, int k) {
    char src[MAX_PATH], dst[MAX_PATH];
    snprintf(src, sizeof src, "%s\\hmnet.dll", dir);
    snprintf(dst, sizeof dst, "%s\\hmnet_test%d.dll", getenv("TEMP"), k);
    if (!CopyFileA(src, dst, FALSE)) { printf("cannot copy %s\n", src); exit(2); }
    n->h = LoadLibraryA(dst);
    if (!n->h) { printf("cannot load %s\n", dst); exit(2); }
#define G(f, name) n->f = (void *)GetProcAddress(n->h, name)
    G(start, "net_start"); G(send, "net_send"); G(poll, "net_poll"); G(ev_count, "net_ev_count");
    G(ev_pop, "net_ev_pop"); G(age, "net_age"); G(es_begin, "net_es_begin"); G(es_send, "net_es_send");
    G(mismatch, "net_version_mismatch"); G(overflow, "net_overflow"); G(sel, "net_sel"); G(ev_get, "net_ev_get");
    G(get, "net_get"); G(set, "net_set"); G(es_get, "net_es_get"); G(es_by, "net_es_by"); G(event4, "net_event4");
    G(uevent4, "net_uevent4"); G(es_add, "net_es_add");
}

static void cfg(Net *n, int k, const char *peers) {
    char path[MAX_PATH];
    snprintf(path, sizeof path, "%s\\hmnet_test%d.txt", getenv("TEMP"), k);
    FILE *f = fopen(path, "w");
    fprintf(f, "port=%d\npeer=%s\nname=P%d\n", 17001 + k, peers, k);
    fclose(f);
    n->start(path);
}

static Net net[4];
// per receiver: next expected reliable value from each sender, unreliable seen
static int next_rel[4][4], urel_seen[4][4][2000], urel_dup = 0, rel_bad = 0;

static void step(int nn) {
    for (int i = 0; i < nn; i++) {
        Net *n = &net[i];
        n->poll();
        while (n->ev_count() > 0) {
            int type = (int)n->ev_get(0), a = (int)n->ev_get(1), from = (int)n->ev_get(5);
            if (type == 1) {
                if (a != next_rel[i][from]) rel_bad++;
                next_rel[i][from] = a + 1;
            } else if (type == 12 && a >= 0 && a < 2000) {
                if (urel_seen[i][from][a]) urel_dup++;
                urel_seen[i][from][a] = 1;
            }
            n->ev_pop();
        }
        n->set(0, 1);
        n->set(2, 100 + i);
        n->send();
    }
    Sleep(4);
}

static int connected(Net *n, int np) {
    int c = 0;
    for (int s = 0; s < np; s++) {
        n->sel(s);
        double a = n->age();
        if (a >= 0 && a < 3000) c++;
    }
    return c;
}

int main(int argc, char **argv) {
    const char *dir = argc > 1 ? argv[1] : ".";
    int loss = argc > 2 ? atoi(argv[2]) : 20;
    char lv[16];
    snprintf(lv, sizeof lv, "%d", loss);
    SetEnvironmentVariableA("HMNET_LOSS", lv);
    _putenv_s("HMNET_LOSS", lv);
    printf("hmnet protocol test, %d%% loss\n", loss);
    for (int k = 0; k < 4; k++) load(&net[k], dir, k);
    // each player knows one other address; player 0 also has a typo'd address (nobody there)
    cfg(&net[0], 0, "127.0.0.1:17002,127.0.0.1:17999");
    cfg(&net[1], 1, "");
    cfg(&net[2], 2, "127.0.0.1:17002");
    cfg(&net[3], 3, "127.0.0.1:17003");

    // the fourth player can only get a slot at player 0 once the dead typo slot may be reused (10 s)
    int t, all = 0;
    for (t = 0; t < 6000 && !all; t++) {
        step(4);
        all = 1;
        for (int k = 0; k < 4; k++) if (connected(&net[k], 3) != 3) all = 0;
    }
    CHECK(all, "mesh of 4 formed (typo slot reused) after %d steps", t);
    if (!all) for (int k = 0; k < 4; k++) printf("        player %d sees %d\n", k, connected(&net[k], 3));

    // the sender's slot number differs on each receiver: count per slot
    memset(next_rel, 0, sizeof next_rel);
    // reliable: 1500 events from player 0, 10 a step; unreliable: 1500 from player 1
    int sent = 0, usent = 0;
    for (t = 0; t < 3000; t++) {
        for (int j = 0; j < 10 && sent < 1500; j++, sent++) net[0].event4(1, sent, 0, 0, 0);
        for (int j = 0; j < 4 && usent < 1500; j++, usent++) net[1].uevent4(12, usent, 0, 0, 0);
        step(4);
        int done = 1;
        for (int k = 1; k < 4; k++) {
            int got = 0;
            for (int s = 0; s < 3; s++) if (next_rel[k][s] > got) got = next_rel[k][s];
            if (got < 1500) done = 0;
        }
        if (done && sent == 1500 && usent == 1500) break;
    }
    int minrel = 1500;
    for (int k = 1; k < 4; k++) {
        int got = 0;
        for (int s = 0; s < 3; s++) if (next_rel[k][s] > got) got = next_rel[k][s];
        if (got < minrel) minrel = got;
    }
    CHECK(minrel == 1500 && rel_bad == 0, "1500 reliable events: all delivered in order (min %d, out of order %d, %d steps)",
          minrel, rel_bad, t);
    for (int k = 0; k < 4; k++) {
        if (k == 1) continue;
        int got = 0;
        for (int s = 0; s < 3; s++) for (int a = 0; a < 2000; a++) got += urel_seen[k][s][a];
        CHECK(got > 1500 * (100 - loss) / 100 * 8 / 10 && got <= 1500, "unreliable: player %d got %d of 1500", k, got);
    }
    CHECK(urel_dup == 0, "unreliable: no duplicates (%d)", urel_dup);
    CHECK(net[0].overflow() == 0, "no event queue overflow");

    // enemies: player 2 simulates 150
    int found = 0, by = 0;
    for (t = 0; t < 200; t++) {
        net[2].es_begin();
        for (int e = 0; e < 150; e++) net[2].es_add(1000 + e, 5, e * 3, 7, 90, 1, 0, 0);
        net[2].es_send();
        step(4);
    }
    for (int e = 0; e < 150; e++) if (net[0].es_get(1000 + e, 1) == e * 3) found++;
    for (int s = 0; s < 3; s++) by += (int)net[0].es_by(1000, s);
    CHECK(found == 150, "150 enemies in 4 pages: %d readable", found);
    CHECK(by == 1, "exactly one slot sends enemy 1000 (%d)", by);
    // stop sending them: after a second they are nobody's
    for (t = 0; t < 300; t++) { net[2].es_begin(); net[2].es_send(); step(4); }
    CHECK(net[0].es_get(1000, 1) == -100000, "enemies no longer sent are nobody's");

    // a v0.7 packet (616 bytes, modver 70) from a fifth address: reported, no slot taken
    SOCKET s = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    struct sockaddr_in me = {0}, to = {0};
    me.sin_family = AF_INET;
    me.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    me.sin_port = htons(17050);
    bind(s, (struct sockaddr *)&me, sizeof me);
    to = me;
    to.sin_port = htons(17001);
    unsigned char pk[616] = {0};
    memcpy(pk, "HMC4", 4);
    pk[4] = 70;
    for (t = 0; t < 20; t++) { sendto(s, (const char *)pk, sizeof pk, 0, (struct sockaddr *)&to, sizeof to); step(4); }
    CHECK(net[0].mismatch() == 1, "other mod version reported");
    CHECK(connected(&net[0], 3) == 3, "...and it took no slot (still 3 connected)");
    closesocket(s);

    printf(fails ? "%d FAILED\n" : "all passed\n", fails);
    return fails ? 1 : 0;
}
