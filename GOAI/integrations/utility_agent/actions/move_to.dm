/datum/utility_ai/mob_commander/proc/StepTo(var/datum/ActionTracker/tracker, var/atom/position)
	/*
	// Simple movement Action; just does a single step to a target position.
	*/
	if(isnull(tracker))
		RUN_ACTION_DEBUG_LOG("Tracker position is null | <@[src]> | [__FILE__] -> L[__LINE__]")
		return

	if(tracker.IsStopped())
		return

	if(isnull(position))
		RUN_ACTION_DEBUG_LOG("Target position is null | <@[src]> | [__FILE__] -> L[__LINE__]")
		tracker.SetFailed()
		return

	var/atom/pawn = src.GetPawn()

	if(isnull(pawn))
		RUN_ACTION_DEBUG_LOG("Pawn is null | <@[src]> | [__FILE__] -> L[__LINE__]")
		return

	var/succeeded = MovePawn(position)

	if(pawn.x == position.x && pawn.y == position.y && pawn.z == position.z)
		tracker.SetDone()

	if(tracker.IsStopped())
		return

	if(!succeeded)
		var/bb_failures = tracker.BBSetDefault("failed_steps", 0)
		tracker.BBSet("failed_steps", ++bb_failures)

		if(bb_failures > 3)
			src.brain?.SetMemory("UnreachableTile", position)
			tracker.SetFailed()

	return


/datum/utility_ai/mob_commander/proc/RunTo(var/datum/ActionTracker/tracker, var/atom/position, var/timeout = null)
	/*
	// Fancier movement; will *keep* walking to the target. Also a fair bit faster, for Reasons (TM).
	//
	// Note that this will NOT terminate until the pawn has reached the target pos (or we time out),
	// so the Action slot will be locked down for the duration of the move
	// and the AI won't replan until we stop.
	//
	// For single-action Brains, this means this is effectively a blind charge, good for e.g. diving to cover,
	// but not suitable if we potentially want to switch to doing *literally anything else*.
	*/
	if(isnull(tracker))
		RUN_ACTION_DEBUG_LOG("Tracker position is null | <@[src]> | [__FILE__] -> L[__LINE__]")
		return

	if(tracker.IsStopped())
		return

	if(isnull(position))
		RUN_ACTION_DEBUG_LOG("Target position is null | <@[src]> | [__FILE__] -> L[__LINE__]")
		tracker.SetFailed()
		return

	var/atom/pawn = src.GetPawn()

	if(isnull(pawn))
		RUN_ACTION_DEBUG_LOG("Pawn is null | <@[src]> | [__FILE__] -> L[__LINE__]")
		return

	if(pawn.x == position.x && pawn.y == position.y && pawn.z == position.z)
		tracker.SetDone()
		return

	var/min_dist = 0

	if((!src.active_path || src.active_path.target != position))
		var/stored_path = StartNavigateTo(position, min_dist, null)
		if(isnull(stored_path))
			tracker.SetFailed()
			src.brain?.SetMemory("UnreachableRunMovePath", position, 500)
			return

	var/pathing_timeout = DEFAULT_IF_NULL(timeout, 100)
	var/timedelta = (world.time - tracker.creation_time)

	if(timedelta > pathing_timeout)
		tracker.SetFailed()
		return

	return
