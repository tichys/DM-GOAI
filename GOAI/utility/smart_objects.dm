/*
// Smart Objects implementation.
//
// Gives all datums (and therefore all DM objects) the ability to return Utility ActionSets.
// This allows any game entity to be queried for Things Wot You Can Do Onnit by the AI.
//
// In turn, this means we don't have to write a handler for Everything The Agent Might Do.
// We can just let objects have various affordances for various requesters (e.g. OpenDoor
// is only available to agents whose Pawn has hands or equivalent).
//
// The API shall return an ActionSet, with a firm tacit encouragement to specify the TTL details
// as well (or we'll wind up storing a ton of unnecessary inactive Actions)
*/


/datum
	// To speed up queries, we'll cache the ActionSets for Smart Objects
	// If an object instance has custom actions, set its cache key to something
	// that will distinguish it from the generic instances of this object.
	var/smartobject_cache_key = null  // implementation-defined on null


/datum/proc/GetUtilityActions(var/requester, var/list/args = null) // (Any, assoc) -> [ActionSet]
	return null


/datum/proc/HasUtilityActions(var/requester, var/list/args = null) // (Any, assoc) -> bool
	/*
	// Like GetUtilityActions(), but returns a boolean that indicates
	// IF the SmartObject is in fact Smart, or is it just clutter
	// (i.e. environmental object with no attached AI logic).
	//
	// Note that this is *relative to the Requester* - some Requesters might have access to objects
	// other AIs would regard as purely decorative.
	//
	// This is a convenience method to avoid having to store the (potentially large) outputs of GetUtilityActions().
	//
	// As such, a critical invariant is that HasUtilityActions(rq, args)
	// should ALWAYS return True if GetUtilityActions(rq, args) would return a nonempty list
	// and should ALWAYS return False if GetUtilityActions(rq, args) would return a null.
	//
	// Don't lie to your API users.
	*/
	return FALSE


/datum/brain/utility
	var/list/smart_objects = null
	var/list/smartobject_last_fetched = null


/datum/brain/utility/proc/GetActionSetsFromSmartObject(var/datum/smartobj, var/list/args = null)
	if(isnull(smartobj))
		return null

	if(isnull(src.smart_objects))
		src.smart_objects = list()

	if(isnull(smartobject_cache))
		smartobject_cache = list()

	var/cache_key = (smartobj.smartobject_cache_key || smartobj.type)

	var/list/so_actions = null
	so_actions = smartobject_cache[cache_key]

	if(!isnull(so_actions))
		//for(var/so_actionset in so_actions)
		//	so_actions.Refresh()

		src.smart_objects[cache_key] = so_actions
		return so_actions

	so_actions = src.smart_objects[cache_key]

	if(so_actions)
		//so_actions.Refresh()
		return so_actions

	var/datum/action_set/subactions = smartobj.GetUtilityActions(src, args)

	so_actions = list(); so_actions[subactions.name] = subactions
	smartobject_cache[cache_key] = so_actions
	src.smart_objects[cache_key] = so_actions

	return so_actions
