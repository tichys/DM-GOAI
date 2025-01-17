
CTXFETCHER_CALL_SIGNATURE(/proc/ctxfetcher_null)
	// A simple, demo/placeholder Fetcher, always returns null
	return null


CTXFETCHER_CALL_SIGNATURE(/proc/ctxfetcher_read_origin_var)
	// Retrieves an arbitrary variable from the origin object.

	if(isnull(requester))
		UTILITYBRAIN_DEBUG_LOG("WARNING: requester for ctxfetcher_read_origin_var is null @ L[__LINE__] in [__FILE__]!")
		return null

	var/datum/utility_ai/mob_commander/requester_ai = requester

	if(isnull(requester_ai))
		UTILITYBRAIN_DEBUG_LOG("WARNING: requester for ctxfetcher_read_origin_var is not an AI @ L[__LINE__] in [__FILE__]!")
		return null

	var/var_key = context_args["variable"]

	if(isnull(var_key))
		UTILITYBRAIN_DEBUG_LOG("ctxfetcher_read_origin_var VarKey is null @ L[__LINE__] in [__FILE__]")
		return null

	var/candidate = parent.origin

	var/datum/action_set/parent_actionset = candidate

	if(istype(parent_actionset))
		candidate = parent_actionset.origin

	if(isnull(candidate))
		UTILITYBRAIN_DEBUG_LOG("ActionTemplate [parent] has no parent (direct or ActionSet). Cannot infer origin! @ L[__LINE__] in [__FILE__]")
		return null

	var/raw_result = candidate:vars[var_key]
	if(isnull(raw_result))
		return null

	var/result = raw_result

	var/optional_list_idx = context_args["list_idx"]

	if(!isnull(optional_list_idx))
		// if someone passed list_idx, assume raw_result is meant to be a list
		// (assoc or array) and the value is behind an index in it
		var/list/listey_raw_result = raw_result
		ASSERT(islist(listey_raw_result))

		// Check if index is numeric, casting from string if needed
		var/numidx = (isnum(optional_list_idx) ? optional_list_idx : text2num(optional_list_idx))

		if(isnull(numidx))
			// Assoc list (string couldn't be converted to num -> it's a alphanumeric string)
			if(optional_list_idx in listey_raw_result)
				result = listey_raw_result[optional_list_idx]
			else
				UTILITYBRAIN_DEBUG_LOG("WARNING: key [optional_list_idx] not in candidate list [listey_raw_result], returning null @ L[__LINE__] in [__FILE__]")
				return null

		else
			// Array list
			if(listey_raw_result.len >= numidx)
				result = listey_raw_result[numidx]
			else
				UTILITYBRAIN_DEBUG_LOG("WARNING: index [optional_list_idx] not in candidate list [listey_raw_result], returning null @ L[__LINE__] in [__FILE__]")
				return null

	var/should_pop = context_args["list_pop"]

	if(!isnull(should_pop))
		// if someone passed should_pop, assume raw_result is meant to be an array list
		var/list/listey_raw_result = raw_result
		ASSERT(islist(listey_raw_result))

		if(listey_raw_result.len)
			result = listey_raw_result[listey_raw_result.len]
			listey_raw_result.len--
		else
			UTILITYBRAIN_DEBUG_LOG("WARNING: index [optional_list_idx] not in candidate list [listey_raw_result], returning null @ L[__LINE__] in [__FILE__]")
			return null

	UTILITYBRAIN_DEBUG_LOG("Value for var [var_key] in [candidate] is [result] @ L[__LINE__] in [__FILE__]")

	var/list/contexts = list()
	var/context_key = context_args["output_context_key"] || "origin_val"
	var/origin_key = context_args["origin_context_key"]

	var/list/ctx = list()
	ctx[context_key] = result

	if(!isnull(origin_key))
		ctx[origin_key] = candidate

	contexts[++(contexts.len)] = ctx

	return contexts
