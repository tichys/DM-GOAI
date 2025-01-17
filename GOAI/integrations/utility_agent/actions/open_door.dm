/datum/utility_ai/mob_commander/proc/OpenDoor(var/datum/ActionTracker/tracker, var/turf/position, var/location)
	if(isnull(tracker))
		RUN_ACTION_DEBUG_LOG("Tracker position is null | <@[src]> | [__FILE__] -> L[__LINE__]")
		return

	if(tracker.IsStopped())
		return

	if(isnull(position))
		RUN_ACTION_DEBUG_LOG("Target position is null | <@[src]> | [__FILE__] -> L[__LINE__]")


	# ifdef GOAI_SS13_SUPPORT
	var/obj/machinery/door/D = location
	var/obj/machinery/door/AD = location // just to have it defined consistently
	# endif

	# ifdef GOAI_LIBRARY_FEATURES
	var/obj/cover/door/D = location
	var/obj/cover/autodoor/AD = location
	# endif

	var/list/available_doors = tracker.BBGet("available_doors")

	if(isnull(available_doors))
		var/list/doors_to_store = list()

		if(!isnull(D))
			doors_to_store.Add(D)

		# ifdef GOAI_LIBRARY_FEATURES
		// in SS13, we don't make a distinction here so it'd duplicate
		if(!isnull(AD))
			doors_to_store.Add(AD)
		# endif

		tracker.BBSet("available_doors", doors_to_store)
		available_doors = doors_to_store

	if(!(available_doors?.len))
		tracker.SetFailed()

	var/success = FALSE

	# ifdef GOAI_SS13_SUPPORT
	for(var/obj/machinery/door/DtoOpen in available_doors)
		success = success || DtoOpen.open() // fixme in SS13 codebase
	# endif

	# ifdef GOAI_LIBRARY_FEATURES

	for(var/abstract_door in available_doors)
		var/obj/cover/door/DtoOpen = abstract_door
		var/obj/cover/autodoor/ADtoOpen = abstract_door

		success = success || DtoOpen?.pOpen()
		success = success || ADtoOpen?.pOpen()
	# endif

	if(success)
		tracker.SetDone()

	if(!success)
		var/bb_failures = tracker.BBSetDefault("failed_steps", 0)
		tracker.BBSet("failed_steps", ++bb_failures)

		if(bb_failures > 3)
			tracker.SetFailed()

	return
