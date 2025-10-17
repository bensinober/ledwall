//
//   test server for simple GATT characteristics remote control
//   ONE write characteristic only
//   some ideas from https://github.com/rstatz/ble_gateway as it was the only decent
//   found that uses bluez sources without the entire shebang stack


#define _GNU_SOURCE
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <time.h>
#include <stdlib.h>
#include <getopt.h>
#include <unistd.h>
#include <errno.h>

#include "lib/bluetooth.h"
#include "lib/hci.h"
#include "lib/hci_lib.h"
#include "lib/l2cap.h"
#include "lib/uuid.h"

#include "src/shared/mainloop.h"
#include "src/shared/util.h"
#include "src/shared/att.h"
#include "src/shared/queue.h"
#include "src/shared/timeout.h"
#include "src/shared/gatt-db.h"
#include "src/shared/gatt-server.h"

#define UUID_GAP			    0x1800
#define UUID_GATT               0x1801
#define UUID_MESSAGE            0x180e
#define UUID_MESSAGE_TEXT       0x1133

#define UUID_CUSTOM_SERVICE "3eb50001-a886-11f0-8ab1-a3bea93ac534"
#define UUID_CUSTOM_CHAR "3eb50002-a886-11f0-8ab1-a3bea93ac534"

#define MAX_MSG_LENGTH 140
#define MAX_MSG_LOG 300

#define ATT_CID 4

#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif

#define COLOR_OFF	"\x1B[0m"
#define COLOR_RED	"\x1B[0;91m"
#define COLOR_GREEN	"\x1B[0;92m"
#define COLOR_YELLOW	"\x1B[0;93m"
#define COLOR_BLUE	"\x1B[0;94m"
#define COLOR_MAGENTA	"\x1B[0;95m"
#define COLOR_BOLDGRAY	"\x1B[1;30m"
#define COLOR_BOLDWHITE	"\x1B[1;37m"

static const char test_device_name[] = "LedWallFol";
static bool verbose = false;
static bool running = true;

// FOR ZIG CALLBACK ON WRITE
extern void on_characteristic_write(const uint8_t *data, size_t length);
// END ZIG CALLBACK

struct server {
	int fd;
	struct bt_att *att;
	struct gatt_db *db;
	struct bt_gatt_server *gatt;

	uint8_t *device_name;
	size_t name_len;

	uint16_t gatt_svc_chngd_handle;
	bool svc_chngd_enabled;

	// Custom message handle
    uint16_t custom_handle;
    uint16_t msg_txt_char_handle;
    uint16_t msg_txt_handle;

    bool custom_visible;
    bool custom_enabled;

    unsigned int msg_timeout_id;
};

static void att_disconnect_cb(int err, void *user_data) {
	printf("Device disconnected: %s\n", strerror(err));
	mainloop_quit();
	// TODO: handle db cleanup here?
}

static void att_debug_cb(const char *str, void *user_data) {
	const char *prefix = user_data;
	printf(COLOR_BOLDGRAY "%s" COLOR_BOLDWHITE "%s\n" COLOR_OFF, prefix, str);
}

static void gatt_debug_cb(const char *str, void *user_data) {
	const char *prefix = user_data;
	printf(COLOR_GREEN "%s%s\n" COLOR_OFF, prefix, str);
}

static void gap_device_name_read_cb(struct gatt_db_attribute *attrib,
					unsigned int id, uint16_t offset,
					uint8_t opcode, struct bt_att *att,
					void *user_data) {
	struct server *server = user_data;
	uint8_t error = 0;
	size_t len = 0;
	const uint8_t *value = NULL;

	printf("GAP Device Name Read called\n");

	len = server->name_len;

	if (offset > len) {
		error = BT_ATT_ERROR_INVALID_OFFSET;
		goto done;
	}

	len -= offset;
	value = len ? &server->device_name[offset] : NULL;

    done:
	    gatt_db_attribute_read_result(attrib, id, error, value, len);
}

static void gap_device_name_write_cb(struct gatt_db_attribute *attrib,
					unsigned int id, uint16_t offset,
					const uint8_t *value, size_t len,
					uint8_t opcode, struct bt_att *att,
					void *user_data) {
	struct server *server = user_data;
	uint8_t error = 0;

	printf("GAP Device Name Write called\n");

	/* If the value is being completely truncated, clean up and return */
	if (!(offset + len)) {
		free(server->device_name);
		server->device_name = NULL;
		server->name_len = 0;
		goto done;
	}

	/* Implement this as a variable length attribute value. */
	if (offset > server->name_len) {
		error = BT_ATT_ERROR_INVALID_OFFSET;
		goto done;
	}

	if (offset + len != server->name_len) {
		uint8_t *name;

		name = realloc(server->device_name, offset + len);
		if (!name) {
			error = BT_ATT_ERROR_INSUFFICIENT_RESOURCES;
			goto done;
		}

		server->device_name = name;
		server->name_len = offset + len;
	}

	if (value){
		memcpy(server->device_name + offset, value, len);
    }
    done:
	    gatt_db_attribute_write_result(attrib, id, error);
}

static void gap_device_name_ext_prop_read_cb(struct gatt_db_attribute *attrib, unsigned int id, uint16_t offset, uint8_t opcode,
    struct bt_att *att, void *user_data)
{
	uint8_t value[2];

	printf("Device Name Extended Properties Read called\n");
    printf("ID: %d\n",  id);
	value[0] = BT_GATT_CHRC_EXT_PROP_RELIABLE_WRITE;
	value[1] = 0;

	gatt_db_attribute_read_result(attrib, id, 0, value, sizeof(value));
}

// Write characteristic handler
static void msg_text_write(struct gatt_db_attribute *attrib,
                           unsigned int id, uint16_t offset,
                           const uint8_t *value, size_t len,
                           uint8_t opcode, struct bt_att *att,
                           void *user_data) {
    uint8_t ecode = 0;

    if (!value || len > MAX_MSG_LENGTH) {
        ecode = BT_ATT_ERROR_INVALID_ATTRIBUTE_VALUE_LEN;
        goto done;
    }

    if (offset) {
        ecode = BT_ATT_ERROR_INVALID_OFFSET;
        goto done;
    }

    char msg[MAX_MSG_LENGTH + 1];

    for (int i = 0; i < len; i++) {
    	msg[i] = value[i];
    }
    msg[len] = '\0';


    printf("MSG RCVD: %s\n", msg);

	// HERE: forward to zig handler
	on_characteristic_write(msg, len);

    done:
    gatt_db_attribute_write_result(attrib, id, ecode);
}

static void confirm_write(struct gatt_db_attribute *attr, int err, void *user_data) {
	if (!err) {
		return;
	}
	fprintf(stderr, "Error caching attribute %p - err: %d\n", attr, err);
	exit(1);
}

static void populate_gap_service(struct server *server) {
	bt_uuid_t uuid;
	struct gatt_db_attribute *service, *tmp;
	uint16_t appearance;

	/* Add the GAP service */
	bt_uuid16_create(&uuid, UUID_GAP);
	service = gatt_db_add_service(server->db, &uuid, true, 6);

	/*
	 * Device Name characteristic. Make the value dynamically read and
	 * written via callbacks.
	 */
	bt_uuid16_create(&uuid, GATT_CHARAC_DEVICE_NAME);
	gatt_db_service_add_characteristic(service, &uuid,
					BT_ATT_PERM_READ | BT_ATT_PERM_WRITE,
					BT_GATT_CHRC_PROP_READ |
					BT_GATT_CHRC_PROP_EXT_PROP,
					gap_device_name_read_cb,
					gap_device_name_write_cb,
					server);

	bt_uuid16_create(&uuid, GATT_CHARAC_EXT_PROPER_UUID);
	gatt_db_service_add_descriptor(service, &uuid, BT_ATT_PERM_READ,
					gap_device_name_ext_prop_read_cb,
					NULL, server);

	/*
	 * Appearance characteristic. Reads and writes should obtain the value
	 * from the database.
	 */
	bt_uuid16_create(&uuid, GATT_CHARAC_APPEARANCE);
	tmp = gatt_db_service_add_characteristic(service, &uuid,
							BT_ATT_PERM_READ,
							BT_GATT_CHRC_PROP_READ,
							NULL, NULL, server);

	/*
	 * Write the appearance value to the database, since we're not using a
	 * callback.
	 */
	put_le16(128, &appearance);
	gatt_db_attribute_write(tmp, 0, (void *) &appearance,
							sizeof(appearance),
							BT_ATT_OP_WRITE_REQ,
							NULL, confirm_write,
							NULL);

	gatt_db_service_set_active(service, true);
}

/*
static void populate_gatt_service(struct server *server) {
	bt_uuid_t uuid;
	struct gatt_db_attribute *service, *svc_chngd;

	// Add the GATT service
	bt_uuid16_create(&uuid, UUID_GATT);
	service = gatt_db_add_service(server->db, &uuid, true, 4);

	bt_uuid16_create(&uuid, GATT_CHARAC_SERVICE_CHANGED);
	svc_chngd = gatt_db_service_add_characteristic(service, &uuid,
			BT_ATT_PERM_WRITE | BT_ATT_PERM_READ,
			BT_GATT_CHRC_PROP_WRITE | BT_GATT_CHRC_PROP_READ | BT_GATT_CHRC_PROP_INDICATE,
			gatt_service_changed_cb,
			NULL, server);
	server->gatt_svc_chngd_handle = gatt_db_attribute_get_handle(svc_chngd);

	bt_uuid16_create(&uuid, GATT_CLIENT_CHARAC_CFG_UUID);
	gatt_db_service_add_descriptor(service, &uuid,
				BT_ATT_PERM_WRITE | BT_ATT_PERM_READ,
				gatt_svc_chngd_ccc_read_cb,
				gatt_svc_chngd_ccc_write_cb, server);

	gatt_db_service_set_active(service, true);
}
*/

// custom service with write characteristic
static void populate_custom_service(struct server *server) {
    bt_uuid_t uuid;
    //struct gatt_db_attribute *service, *msg_txt_char, *msg_txt;
    struct gatt_db_attribute *service, *msg_txt_char;

    /* Add Custom remote control Service */
    //bt_uuid16_create(&uuid, UUID_CUSTOM_SERVICE);
    bt_string_to_uuid(&uuid, UUID_CUSTOM_SERVICE);
    //printf("Custom service UUID: %s\n", uuid);
    service = gatt_db_add_service(server->db, &uuid, true, 8);
    server->custom_handle = gatt_db_attribute_get_handle(service);

    /* Custom Remote control Characteristic */
    bt_string_to_uuid(&uuid, UUID_CUSTOM_CHAR);
    printf("Custom characteristics UUID: %s\n", UUID_CUSTOM_CHAR);

    msg_txt_char = gatt_db_service_add_characteristic(service, &uuid, BT_ATT_PERM_READ | BT_ATT_PERM_WRITE,
        BT_GATT_CHRC_PROP_WRITE | BT_GATT_CHRC_PROP_READ, NULL, msg_text_write, NULL);
    server->msg_txt_char_handle = gatt_db_attribute_get_handle(msg_txt_char);

    // TODO: Do we need this?
    // bt_uuid16_create(&uuid, GATT_CLIENT_CHARAC_CFG_UUID);
    // printf("MSG desc UID: %s\n", &uuid);
    // msg_txt = gatt_db_service_add_descriptor(service, &uuid, BT_ATT_PERM_WRITE, NULL, msg_text_write, server);

    // server->msg_txt_handle = gatt_db_attribute_get_handle(msg_txt);
    // printf("server msg text handle = %x\n", server->msg_txt_handle);

    gatt_db_service_set_active(service, true);
}


static void populate_db(struct server *server) {
    printf("Populating BLE DB...\n");
	populate_gap_service(server);
	//populate_gatt_service(server);
	populate_custom_service(server);
}

static struct server *server_create(int fd, uint16_t mtu, bool custom_visible) {
	struct server *server;
	size_t name_len = strlen(test_device_name);

	server = new0(struct server, 1);
	if (!server) {
		fprintf(stderr, "Failed to allocate memory for server\n");
		return NULL;
	}

	server->att = bt_att_new(fd, false);
	if (!server->att) {
		fprintf(stderr, "Failed to initialze ATT transport layer\n");
		goto fail;
	}

	if (!bt_att_set_close_on_unref(server->att, true)) {
		fprintf(stderr, "Failed to set up ATT transport layer\n");
		goto fail;
	}

	if (!bt_att_register_disconnect(server->att, att_disconnect_cb, NULL, NULL)) {
		fprintf(stderr, "Failed to set ATT disconnect handler\n");
		goto fail;
	}

	server->name_len = name_len + 1;
	server->device_name = malloc(name_len + 1);
	if (!server->device_name) {
		fprintf(stderr, "Failed to allocate memory for device name\n");
		goto fail;
	}

	memcpy(server->device_name, test_device_name, name_len);
	server->device_name[name_len] = '\0';

	server->fd = fd;
	server->db = gatt_db_new();
	if (!server->db) {
		fprintf(stderr, "Failed to create GATT database\n");
		goto fail;
	}

	server->gatt = bt_gatt_server_new(server->db, server->att, mtu, 0);
	if (!server->gatt) {
		fprintf(stderr, "Failed to create GATT server\n");
		goto fail;
	}

	server->custom_visible = custom_visible;

	if (verbose) {
		bt_att_set_debug(server->att, BT_ATT_DEBUG_VERBOSE,	att_debug_cb, "att: ", NULL);
		bt_gatt_server_set_debug(server->gatt, gatt_debug_cb, "server: ", NULL);
	}

	/* Random seed for generating fake Heart Rate measurements */
	srand(time(NULL));

	/* bt_gatt_server already holds a reference */
	populate_db(server);

	return server;

fail:
	gatt_db_unref(server->db);
	free(server->device_name);
	bt_att_unref(server->att);
	free(server);

	return NULL;
}

static void server_destroy(struct server *server) {
	timeout_remove(server->msg_timeout_id);
	bt_gatt_server_unref(server->gatt);
	gatt_db_unref(server->db);
}


static int l2cap_le_att_listen_and_accept(bdaddr_t *src, int sec, uint8_t src_type) {
	int sk, nsk;
	struct sockaddr_l2 srcaddr, addr;
	socklen_t optlen;
	struct bt_security btsec;
	char ba[18];

	sk = socket(PF_BLUETOOTH, SOCK_SEQPACKET, BTPROTO_L2CAP);
	if (sk < 0) {
		perror("Failed to create L2CAP socket");
		return -1;
	}

	/* Set up source address */
	memset(&srcaddr, 0, sizeof(srcaddr));
	srcaddr.l2_family = AF_BLUETOOTH;
	srcaddr.l2_cid = htobs(ATT_CID);
	srcaddr.l2_bdaddr_type = src_type;
	bacpy(&srcaddr.l2_bdaddr, src);

	if (bind(sk, (struct sockaddr *) &srcaddr, sizeof(srcaddr)) < 0) {
		perror("Failed to bind L2CAP socket");
		goto fail;
	}

	/* Set the security level */
	memset(&btsec, 0, sizeof(btsec));
	btsec.level = sec;
	if (setsockopt(sk, SOL_BLUETOOTH, BT_SECURITY, &btsec,
							sizeof(btsec)) != 0) {
		fprintf(stderr, "Failed to set L2CAP security level\n");
		goto fail;
	}

	if (listen(sk, 10) < 0) {
		perror("Listening on socket failed");
		goto fail;
	}

	printf("Started listening on ATT channel. Waiting for connections\n");

	memset(&addr, 0, sizeof(addr));
	optlen = sizeof(addr);

	nsk = accept(sk, (struct sockaddr *) &addr, &optlen);
	if (nsk < 0) {
		perror("Accept failed");
		goto fail;
	}

	ba2str(&addr.l2_bdaddr, ba);
	printf("Connect from %s\n", ba);
	close(sk);

	return nsk;

fail:
	close(sk);
	return -1;
}

// quitting signal callback
static void signal_cb(int signum, void *user_data) {
	switch (signum) {
	case SIGINT:
	case SIGTERM:
		mainloop_quit();
		running = false;
		break;
	default:
		break;
	}
}

int main_loop_run() {
	bdaddr_t src_addr;
	int fd;
	int sec = BT_SECURITY_LOW; //BT_SECURITY_MEDIUM | BT_SECURITY_HIGH
	uint8_t src_type = BDADDR_LE_PUBLIC; // BDADDR_LE_RANDOM
	uint16_t mtu = 0;
	bool custom_visible = true;
	//verbose = true;
	struct server *server;
	bacpy(&src_addr, BDADDR_ANY); // choose any avail device
	while (running == true) {
		fd = l2cap_le_att_listen_and_accept(&src_addr, sec, src_type);
		if (fd < 0) {
			fprintf(stderr, "Failed to accept L2CAP ATT connection\n");
			return EXIT_FAILURE;
		}

		mainloop_init();

		server = server_create(fd, mtu, custom_visible);
		if (!server) {
			close(fd);
			return EXIT_FAILURE;
		}

		printf("Running GATT server\n");
		mainloop_run_with_signal(signal_cb, NULL);
	}

	printf("\n\nShutting down...\n");

	server_destroy(server);

	return EXIT_SUCCESS;
}
