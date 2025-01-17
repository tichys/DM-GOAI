/*
// A Consideration is a Utility scorer that takes in Inputs and produces Activations.
//
// The API is very simple - an Input is a plain-old proc. It takes in an assoc list (or null) and optionally any type representing the logical 'owner' of the decision
// and outputs a float representing the value to use for scoring.
// The float will be normalized downstream by the Consideration's parameters, so you don't need to worry about that.
//
// Most of the logic here was extracted to the consideration_inputs/<FOO>.dm files as their number grew.
// This file is currently just provides top-level shared bits, it MAY get deleted later on.
*/

//# define DEBUG_UTILITY_INPUT_FETCHERS 1

# ifdef DEBUG_UTILITY_INPUT_FETCHERS
# define DEBUGLOG_UTILITY_INPUT_FETCHERS(X) to_world_log(X)
# define DEBUGLOG_UTILITY_INPUT_CATCH(X) catch(X)
# else
# define DEBUGLOG_UTILITY_INPUT_FETCHERS(X)
# define DEBUGLOG_UTILITY_INPUT_CATCH(X) catch()
# endif



// Macro-ized callsig to make it easy/mandatory to use the proper API conventions
// For those less familiar with macros, pretend this is a normal proc definition with context/requester/consideration_args as params.
# define CONSIDERATION_CALL_SIGNATURE(procpath) ##procpath(var/list/context = null, var/requester = null, var/list/consideration_args = null)


/proc/_cihelper_get_requester_brain(var/requester, var/caller = null)
	var/datum/utility_ai/mob_commander/controller = requester

	if(isnull(controller))
		DEBUGLOG_UTILITY_INPUT_FETCHERS("[caller] Controller is null ([controller || "null"]) @ L[__LINE__] in [__FILE__]")
		return null

	var/datum/brain/requesting_brain = controller.brain

	return requesting_brain
