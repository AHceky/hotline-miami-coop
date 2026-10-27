// steam_probe.exe - checks the Steam calls hmnet.dll makes against the game's steam_api.dll (2013 SDK):
// init, own SteamID, lobby create / data / search / members, P2P send to self.
// Run it from a game folder (steam_api.dll + steam_appid.txt) with Steam running.
//   zig cc -target x86-windows-gnu -O2 -o steam_probe.exe steam_probe.c
#include <windows.h>
#include <stdio.h>
#include <stdint.h>

#define TC __attribute__((thiscall))
typedef void **VT;  // interface: pointer to vtable
#define VF(obj, i) ((*(VT *)(obj))[i])

static void *net, *mm, *usr, *utl, *fr;

static uint64_t my_id(void) {
    uint64_t r = 0;
    ((uint64_t *(TC *)(void *, uint64_t *))VF(usr, 2))(usr, &r);
    return r;
}

static int wait_call(uint64_t call, void *res, int size, int cb) {
    for (int i = 0; i < 300; i++) {
        uint8_t failed = 0;
        if (((uint8_t(TC *)(void *, uint64_t, uint8_t *))VF(utl, 11))(utl, call, &failed)) {
            failed = 0;
            uint8_t ok = ((uint8_t(TC *)(void *, uint64_t, void *, int, int, uint8_t *))VF(utl, 13))(utl, call, res, size, cb, &failed);
            return ok && !failed;
        }
        Sleep(50);
    }
    return 0;
}

int main(void) {
    HMODULE h = LoadLibraryA("steam_api.dll");
    if (!h) { printf("no steam_api.dll\n"); return 1; }
    uint8_t (*Init)(void) = (void *)GetProcAddress(h, "SteamAPI_Init");
    int (*GetUser)(void) = (void *)GetProcAddress(h, "SteamAPI_GetHSteamUser");
    printf("HSteamUser before init: %d\n", GetUser());
    printf("SteamAPI_Init: %d\n", Init());
    printf("SteamAPI_Init again: %d  HSteamUser %d\n", Init(), GetUser());
    net = ((void *(*)(void))GetProcAddress(h, "SteamNetworking"))();
    mm = ((void *(*)(void))GetProcAddress(h, "SteamMatchmaking"))();
    usr = ((void *(*)(void))GetProcAddress(h, "SteamUser"))();
    utl = ((void *(*)(void))GetProcAddress(h, "SteamUtils"))();
    fr = ((void *(*)(void))GetProcAddress(h, "SteamFriends"))();
    printf("interfaces %p %p %p %p %p\n", net, mm, usr, utl, fr);
    printf("logged on %d  appid %u  name %s\n", ((uint8_t(TC *)(void *))VF(usr, 1))(usr),
           ((uint32_t(TC *)(void *))VF(utl, 9))(utl), ((const char *(TC *)(void *))VF(fr, 0))(fr));
    uint64_t me = my_id();
    printf("my id %llu\n", (unsigned long long)me);

    // create a friends-only lobby for 4
    uint64_t call = ((uint64_t(TC *)(void *, int, int))VF(mm, 13))(mm, 1, 4);
    struct { uint32_t res, pad; uint64_t lobby; } lc = {0};
    printf("CreateLobby call %llu -> %d result %u lobby %llu\n", (unsigned long long)call,
           wait_call(call, &lc, sizeof lc, 513), lc.res, (unsigned long long)lc.lobby);
    uint64_t lobby = lc.lobby;
    printf("SetLobbyData %d\n", ((uint8_t(TC *)(void *, uint64_t, const char *, const char *))VF(mm, 20))(mm, lobby, "hmprobe", "x1"));
    printf("GetLobbyData '%s'\n", ((const char *(TC *)(void *, uint64_t, const char *))VF(mm, 19))(mm, lobby, "hmprobe"));
    int n = ((int(TC *)(void *, uint64_t))VF(mm, 17))(mm, lobby);
    uint64_t m0 = 0;
    ((uint64_t *(TC *)(void *, uint64_t *, uint64_t, int))VF(mm, 18))(mm, &m0, lobby, 0);
    uint64_t own = 0;
    ((uint64_t *(TC *)(void *, uint64_t *, uint64_t))VF(mm, 35))(mm, &own, lobby);
    printf("members %d first %llu owner %llu limit %d\n", n, (unsigned long long)m0, (unsigned long long)own,
           ((int(TC *)(void *, uint64_t))VF(mm, 32))(mm, lobby));
    printf("SetLobbyType public %d\n", ((uint8_t(TC *)(void *, uint64_t, int))VF(mm, 33))(mm, lobby, 2));
    Sleep(1500);

    // search for it
    ((void(TC *)(void *, const char *, const char *, int))VF(mm, 5))(mm, "hmprobe", "x1", 0);
    ((void(TC *)(void *, int))VF(mm, 9))(mm, 3);
    call = ((uint64_t(TC *)(void *))VF(mm, 4))(mm);
    uint32_t found = 0;
    printf("RequestLobbyList -> %d found %u\n", wait_call(call, &found, sizeof found, 510), found);
    for (uint32_t i = 0; i < found; i++) {
        uint64_t l = 0;
        ((uint64_t *(TC *)(void *, uint64_t *, int))VF(mm, 12))(mm, &l, i);
        printf("  lobby %llu%s\n", (unsigned long long)l, l == lobby ? " (ours)" : "");
    }

    // P2P to ourselves
    const char msg[] = "hello";
    printf("SendP2PPacket self %d\n", ((uint8_t(TC *)(void *, uint64_t, const void *, uint32_t, int, int))VF(net, 0))(net, me, msg, sizeof msg, 0, 0));
    printf("AllowP2PPacketRelay %d\n", ((uint8_t(TC *)(void *, uint8_t))VF(net, 7))(net, 1));
    for (int i = 0; i < 20; i++) {
        uint32_t sz = 0;
        if (((uint8_t(TC *)(void *, uint32_t *, int))VF(net, 1))(net, &sz, 0)) {
            char b[64] = {0};
            uint64_t from = 0;
            ((uint8_t(TC *)(void *, void *, uint32_t, uint32_t *, uint64_t *, int))VF(net, 2))(net, b, sizeof b, &sz, &from, 0);
            printf("got %u bytes '%s' from %llu\n", sz, b, (unsigned long long)from);
            break;
        }
        Sleep(100);
    }
    ((void(TC *)(void *, uint64_t))VF(mm, 15))(mm, lobby);
    printf("left lobby, done\n");
    return 0;
}
