/* Minimal provider-level zero state for rpmServer status:0 under PRoot. */

static void zero(void *target, unsigned count) {
    unsigned char *bytes = target;
    while (count--) *bytes++ = 0;
}

int wm_connect(const char *server, const char *local) {
    (void)server;
    (void)local;
    return 1;
}

int wm_disconnect(int handle) {
    (void)handle;
    return 0;
}

int wm_get_wlan_switch(int handle, void *value) {
    (void)handle;
    zero(value, 4);
    return 0;
}

int wm_get_wlan_config(int handle, void *value) {
    (void)handle;
    zero(value, 0x198);
    return 0;
}

int wm_get_wlan_sta_num(int handle, void *value) {
    (void)handle;
    zero(value, 4);
    return 0;
}

int send_monthlyflow_msg_to_flowstat(void *value) {
    zero(value, 8);
    return 0;
}

int send_dailyflow_msg_to_flowstat(void *value) {
    zero(value, 8);
    return 0;
}

int send_txspeed_msg_to_flowstat(void *value) {
    zero(value, 8);
    return 0;
}

int send_rxspeed_msg_to_flowstat(void *value) {
    zero(value, 8);
    return 0;
}
