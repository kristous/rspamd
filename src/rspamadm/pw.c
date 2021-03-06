/*-
 * Copyright 2016 Vsevolod Stakhov
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#include "config.h"
#include "util.h"
#include "ottery.h"
#include "cryptobox.h"
#include "rspamd.h"
#include "rspamadm.h"
#include "unix-std.h"

static void rspamadm_pw (gint argc, gchar **argv);
static const char *rspamadm_pw_help (gboolean full_help);

static gboolean do_encrypt = FALSE;
static gboolean do_check = FALSE;
static gboolean quiet = FALSE;
static gchar *password = NULL;

struct rspamadm_command pw_command = {
	.name = "pw",
	.flags = 0,
	.help = rspamadm_pw_help,
	.run = rspamadm_pw
};

static GOptionEntry entries[] = {
		{"encrypt", 'e', 0, G_OPTION_ARG_NONE, &do_encrypt,
				"Encrypt password", NULL},
		{"check", 'c', 0, G_OPTION_ARG_NONE, &do_check,
				"Check password", NULL},
		{"quiet", 'q', 0, G_OPTION_ARG_NONE, &quiet,
				"Supress output", NULL},
		{"password", 'p', 0, G_OPTION_ARG_STRING, &password,
				"Input password", NULL},
		{NULL, 0, 0, G_OPTION_ARG_NONE, NULL, NULL, NULL}
};

static const char *
rspamadm_pw_help (gboolean full_help)
{
	const char *help_str;

	if (full_help) {
		help_str = "Manipulate with passwords in rspamd\n\n"
				"Usage: rspamadm pw [command]\n"
				"Where commands are:\n\n"
				"--encrypt: encrypt password (this is a default command)\n"
				"--check: check encrypted password using encrypted password\n"
				"--help: shows available options and commands";
	}
	else {
		help_str = "Manage rspamd passwords";
	}

	return help_str;
}

static void
rspamadm_pw_encrypt (void)
{
	const struct rspamd_controller_pbkdf *pbkdf;
	guchar *salt, *key;
	gchar *encoded_salt, *encoded_key;
	gsize plen;

	pbkdf = &pbkdf_list[0];
	g_assert (pbkdf != NULL);

	if (password == NULL) {
		plen = 8192;
		password = g_malloc0 (plen);
		plen = rspamd_read_passphrase (password, plen, 0, NULL);
	}
	else {
		plen = strlen (password);
	}

	if (plen == 0) {
		fprintf (stderr, "Invalid password\n");
		exit (EXIT_FAILURE);
	}

	salt = g_alloca (pbkdf->salt_len);
	key = g_alloca (pbkdf->key_len);
	ottery_rand_bytes (salt, pbkdf->salt_len);
	/* Derive key */
	rspamd_cryptobox_pbkdf (password, strlen (password),
			salt, pbkdf->salt_len, key, pbkdf->key_len, pbkdf->rounds);

	encoded_salt = rspamd_encode_base32 (salt, pbkdf->salt_len);
	encoded_key = rspamd_encode_base32 (key, pbkdf->key_len);

	rspamd_printf ("$%d$%s$%s\n", pbkdf->id, encoded_salt,
			encoded_key);

	g_free (encoded_salt);
	g_free (encoded_key);
	rspamd_explicit_memzero (password, plen);
	g_free (password);
}

static const gchar *
rspamd_encrypted_password_get_str (const gchar *password, gsize skip,
		gsize *length)
{
	const gchar *str, *start, *end;
	gsize size;

	start = password + skip;
	end = start;
	size = 0;

	while (*end != '\0' && g_ascii_isalnum (*end)) {
		size++;
		end++;
	}

	if (size) {
		str = start;
		*length = size;
	}
	else {
		str = NULL;
	}

	return str;
}

static void
rspamadm_pw_check (void)
{
	const struct rspamd_controller_pbkdf *pbkdf;
	GIOChannel *in;
	GString *encrypted_pwd;
	const gchar *salt, *hash;
	guchar *salt_decoded, *key_decoded, *local_key;
	gsize salt_len, key_len;
	gchar test_password[8192];
	gsize plen, term = 0;

	if (password == NULL) {
		encrypted_pwd = g_string_new ("");
		in = g_io_channel_unix_new (STDIN_FILENO);
		printf ("Enter encrypted password: ");
		fflush (stdout);
		g_io_channel_read_line_string (in, encrypted_pwd, &term, NULL);

		if (term != 0) {
			g_string_erase (encrypted_pwd, term, encrypted_pwd->len - term);
		}
		g_io_channel_unref (in);
	}
	else {
		encrypted_pwd = g_string_new (password);
	}

	pbkdf = &pbkdf_list[0];
	g_assert (pbkdf != NULL);

	if (encrypted_pwd->len < pbkdf->salt_len + pbkdf->key_len + 3) {
		msg_err ("incorrect salt: password length: %z, must be at least %z characters",
				encrypted_pwd->len, pbkdf->salt_len);
		exit (EXIT_FAILURE);
	}

	/* get salt */
	salt = rspamd_encrypted_password_get_str (encrypted_pwd->str, 3, &salt_len);
	/* get hash */
	hash = rspamd_encrypted_password_get_str (encrypted_pwd->str,
			3 + salt_len + 1,
			&key_len);
	if (salt != NULL && hash != NULL) {

		/* decode salt */
		salt_decoded = rspamd_decode_base32 (salt, salt_len, &salt_len);

		if (salt_decoded == NULL || salt_len != pbkdf->salt_len) {
			/* We have some unknown salt here */
			msg_err ("incorrect salt: %z, while %z expected",
					salt_len, pbkdf->salt_len);
			exit (EXIT_FAILURE);
		}

		key_decoded = rspamd_decode_base32 (hash, key_len, &key_len);

		if (key_decoded == NULL || key_len != pbkdf->key_len) {
			/* We have some unknown salt here */
			msg_err ("incorrect key: %z, while %z expected",
					key_len, pbkdf->key_len);
			exit (EXIT_FAILURE);
		}

		plen = rspamd_read_passphrase (test_password, sizeof (test_password),
				0, NULL);
		if (plen == 0) {
			fprintf (stderr, "Invalid password\n");
			exit (EXIT_FAILURE);
		}

		local_key = g_alloca (pbkdf->key_len);
		rspamd_cryptobox_pbkdf (test_password, plen,
				salt_decoded, salt_len,
				local_key, pbkdf->key_len, pbkdf->rounds);
		rspamd_explicit_memzero (test_password, plen);

		if (!rspamd_constant_memcmp (key_decoded, local_key, pbkdf->key_len)) {
			if (!quiet) {
				printf ("password incorrect\n");
			}
			exit (EXIT_FAILURE);
		}

		g_free (salt_decoded);
		g_free (key_decoded);
		g_string_free (encrypted_pwd, TRUE);
	}
	else {
		msg_err ("bad encrypted password format");
		exit (EXIT_FAILURE);
	}

	if (!quiet) {
		printf ("password correct\n");
	}
}

static void
rspamadm_pw (gint argc, gchar **argv)
{
	GOptionContext *context;
	GError *error = NULL;

	context = g_option_context_new ("pw [--encrypt | --check] - manage rspamd passwords");
	g_option_context_set_summary (context,
			"Summary:\n  Rspamd administration utility version "
					RVERSION
					"\n  Release id: "
					RID);
	g_option_context_add_main_entries (context, entries, NULL);

	if (!g_option_context_parse (context, &argc, &argv, &error)) {
		fprintf (stderr, "option parsing failed: %s\n", error->message);
		g_error_free (error);
		exit (1);
	}


	if (!do_encrypt && !do_check) {
		do_encrypt = TRUE;
	}

	if (do_encrypt) {
		rspamadm_pw_encrypt ();
	}
	else if (do_check) {
		rspamadm_pw_check ();
	}
}
