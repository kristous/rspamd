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
#include "hash.h"
#include "util.h"

/**
 * LRU hashing
 */

struct rspamd_lru_hash_s {
	gint maxsize;
	gint maxage;
	GDestroyNotify value_destroy;
	GDestroyNotify key_destroy;

	GHashTable *tbl;
	GQueue *exp; /* Elements are inserted to the tail and removed from the front */
};

static void
rspamd_lru_destroy_node (gpointer value)
{
	rspamd_lru_element_t *elt = (rspamd_lru_element_t *)value;

	if (elt) {
		if (elt->hash && elt->hash->key_destroy) {
			elt->hash->key_destroy (elt->key);
		}
		if (elt->hash && elt->hash->value_destroy) {
			elt->hash->value_destroy (elt->data);
		}
		if (elt->hash && elt->link) {
			g_queue_delete_link (elt->hash->exp, elt->link);
		}

		g_slice_free1 (sizeof (*elt), elt);
	}
}

static rspamd_lru_element_t *
rspamd_lru_create_node (rspamd_lru_hash_t *hash,
	gpointer key,
	gpointer value,
	time_t now,
	guint ttl)
{
	rspamd_lru_element_t *node;

	node = g_slice_alloc (sizeof (rspamd_lru_element_t));
	node->data = value;
	node->key = key;
	node->store_time = now;
	node->ttl = ttl;
	node->hash = hash;

	return node;
}

rspamd_lru_hash_t *
rspamd_lru_hash_new_full (
	gint maxsize,
	gint maxage,
	GDestroyNotify key_destroy,
	GDestroyNotify value_destroy,
	GHashFunc hf,
	GEqualFunc cmpf)
{
	rspamd_lru_hash_t *new;

	new = g_slice_alloc (sizeof (rspamd_lru_hash_t));
	new->tbl = g_hash_table_new_full (hf, cmpf, NULL, rspamd_lru_destroy_node);
	new->exp = g_queue_new ();
	new->maxage = maxage;
	new->maxsize = maxsize;
	new->value_destroy = value_destroy;
	new->key_destroy = key_destroy;

	return new;
}

rspamd_lru_hash_t *
rspamd_lru_hash_new (
	gint maxsize,
	gint maxage,
	GDestroyNotify key_destroy,
	GDestroyNotify value_destroy)
{
	return rspamd_lru_hash_new_full (maxsize, maxage,
			key_destroy, value_destroy,
			rspamd_strcase_hash, rspamd_strcase_equal);
}

gpointer
rspamd_lru_hash_lookup (rspamd_lru_hash_t *hash, gconstpointer key, time_t now)
{
	rspamd_lru_element_t *res;
	GList *cur, *tmp;

	res = g_hash_table_lookup (hash->tbl, key);
	if (res != NULL) {
		if (res->ttl != 0) {
			if (now - res->store_time > res->ttl) {
				g_hash_table_remove (hash->tbl, key);
				return NULL;
			}
		}
		if (hash->maxage > 0) {
			if (now - res->store_time > hash->maxage) {
				/* Expire elements from queue head */
				cur = hash->exp->head;
				while (cur) {
					tmp = cur->next;
					res = (rspamd_lru_element_t *)cur->data;

					if (now - res->store_time > hash->maxage) {
						/* That would also remove element from the queue */
						g_hash_table_remove (hash->tbl, res->key);
					}
					else {
						break;
					}

					cur = tmp;
				}

				return NULL;
			}
		}
		else {
			res->store_time = now;
			/* Reinsert element to the tail */
			g_queue_unlink (hash->exp, res->link);
			g_queue_push_tail_link (hash->exp, res->link);
		}

		return res->data;
	}

	return NULL;
}

void
rspamd_lru_hash_insert (rspamd_lru_hash_t *hash, gpointer key, gpointer value,
	time_t now, guint ttl)
{
	rspamd_lru_element_t *res;
	gint removed = 0;
	GList *cur, *tmp;

	res = g_hash_table_lookup (hash->tbl, key);
	if (res != NULL) {
		g_hash_table_remove (hash->tbl, key);
	}
	else {
		if (hash->maxsize > 0 &&
			(gint)g_hash_table_size (hash->tbl) >= hash->maxsize) {
			/* Expire some elements */
			if (hash->maxage > 0) {
				cur = hash->exp->head;
				while (cur) {
					tmp = cur->next;
					res = (rspamd_lru_element_t *)cur->data;

					if (now - res->store_time > hash->maxage) {
						/* That would also remove element from the queue */
						g_hash_table_remove (hash->tbl, res->key);
						removed ++;
					}
					else {
						break;
					}

					cur = tmp;
				}
			}
			if (removed == 0) {
				/* Just unlink the element at the head */
				res = (rspamd_lru_element_t *)hash->exp->head->data;
				g_hash_table_remove (hash->tbl, res->key);
			}
		}
	}

	res = rspamd_lru_create_node (hash, key, value, now, ttl);
	g_hash_table_insert (hash->tbl, key, res);
	g_queue_push_tail (hash->exp, res);
	res->link = hash->exp->tail;
}

void
rspamd_lru_hash_destroy (rspamd_lru_hash_t *hash)
{
	g_hash_table_unref (hash->tbl);
	g_queue_free (hash->exp);
	g_slice_free1 (sizeof (rspamd_lru_hash_t), hash);
}


GHashTable *
rspamd_lru_hash_get_htable (rspamd_lru_hash_t *hash)
{
	return hash->tbl;
}

GQueue *
rspamd_lru_hash_get_queue (rspamd_lru_hash_t *hash)
{
	return hash->exp;
}

/*
 * vi:ts=4
 */
