/**
 *  @file
 *  Implementation of the interface for searching and iterating over specific 
 *  policy components.
 *
 *  @author Kevin Carr kcarr@tresys.com
 *  @author Jeremy A. Mowery jmowery@tresys.com
 *  @author Jason Tang jtang@tresys.com
 *
 *  Copyright (C) 2006-2007 Tresys Technology, LLC
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include <stddef.h>
#include <stdint.h>
#include <qpol/policy.h>
#include <qpol/iterator.h>
#include <sepol/policydb/policydb.h>
#include <sepol/policydb/expand.h>
#include "iterator_internal.h"
#include <qpol/policy_query.h>
#include "qpol_internal.h"

/* generic information about policydb*/
static int qpol_policy_is_mls_enabled(qpol_policy_t * policy)
{
	policydb_t *db = NULL;

	if (policy == NULL) {
		ERR(policy, "%s", strerror(EINVAL));
		errno = EINVAL;
		return STATUS_ERR;
	}

	db = &policy->p->p;

	if (db->mls != 0)
		return 1;
	else
		return 0;
}

int qpol_policy_get_policy_version(qpol_policy_t * policy, unsigned int *version)
{
	policydb_t *db;

	if (version != NULL)
		*version = 0;

	if (policy == NULL || version == NULL) {
		ERR(policy, "%s", strerror(EINVAL));
		errno = EINVAL;
		return STATUS_ERR;
	}

	db = &policy->p->p;

	*version = db->policyvers;

	return STATUS_SUCCESS;
}

int qpol_policy_get_type(qpol_policy_t * policy, int *type)
{
	if (!policy || !type) {
		ERR(policy, "%s", strerror(EINVAL));
		errno = EINVAL;
		return STATUS_ERR;
	}

	*type = policy->type;

	return STATUS_SUCCESS;
}

int qpol_policy_has_capability(qpol_policy_t * policy, qpol_capability_e cap)
{
	unsigned int version = 0;

	if (!policy) {
		ERR(policy, "%s", strerror(EINVAL));
		errno = EINVAL;
		return 0;
	}

	qpol_policy_get_policy_version(policy, &version);

	switch (cap) {
	case QPOL_CAP_ATTRIB_NAMES:
		{
			if (policy->type == QPOL_POLICY_KERNEL_SOURCE || policy->type == QPOL_POLICY_MODULE_BINARY)
				return 1;
			break;
		}
	case QPOL_CAP_SYN_RULES:
		{
			if (policy->type == QPOL_POLICY_KERNEL_SOURCE || policy->type == QPOL_POLICY_MODULE_BINARY)
				return 1;
			break;
		}
	case QPOL_CAP_LINE_NOS:
		{
			if (policy->type == QPOL_POLICY_KERNEL_SOURCE)
				return 1;
			break;
		}
	case QPOL_CAP_CONDITIONALS:
		{
			if (version >= 16 || policy->type == QPOL_POLICY_MODULE_BINARY)
				return 1;
			break;
		}
	case QPOL_CAP_MLS:
		{
			return qpol_policy_is_mls_enabled(policy);
		}
	case QPOL_CAP_MODULES:
		{
			if (policy->type == QPOL_POLICY_MODULE_BINARY)
				return 1;
			break;
		}
	case QPOL_CAP_RULES_LOADED:
		{
			if (policy->rules_loaded)
				return 1;
			break;
		}
	default:
		{
			ERR(policy, "%s", "Unknown capability");
			errno = EDOM;
			break;
		}
	}
	return 0;
}
