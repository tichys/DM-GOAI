/* Concrete implementation of the Brain logic using IAUS-style Utility
//
//
// The underscore in the filename is just to trick DM into sorting this correctly.
*/


/datum/brain/utility
	// NOTE: we'll reuse actionslist from the parent for ActionSets; this is not ideal
	//       but I don't want to refactor the parent into a GOAPy subclass.
	var/list/file_actionsets = null


/datum/brain/utility/GetAiController()
	var/__commander_backref = src.attachments.Get(ATTACHMENT_CONTROLLER_BACKREF)
	world.log << "Backref is [__commander_backref] @ L[__LINE__] in [__FILE__]"
	var/datum/commander = null

	if(IS_REGISTERED_AI(__commander_backref))
		commander = GOAI_LIBBED_GLOB_ATTR(global_goai_registry[__commander_backref])

	ASSERT(commander)
	return commander


/datum/brain/utility/CleanDelete()
	deregister_ai_brain(src.registry_index)
	qdel(src)
	return TRUE



/datum/brain/utility/proc/ShouldCleanup()
	. = FALSE

	if(src.cleanup_detached_threshold < 0)
		return FALSE

	if(src._ticks_since_detached > src.cleanup_detached_threshold)
		return TRUE

	return


/datum/brain/utility/proc/CheckForCleanup()
	. = ..()

	if(.)
		return .

	var/should_clean = src.ShouldCleanup()
	if(should_clean)
		src.CleanDelete()
		qdel(src)
		return TRUE

	if(!(src.attachments && istype(src.attachments)))
		return FALSE

	var/ai_index = src.attachments[ATTACHMENT_CONTROLLER_BACKREF]
	var/orphaned = (IS_REGISTERED_AIBRAIN(ai_index))

	if(orphaned)
		src._ticks_since_detached++
	else
		src._ticks_since_detached = 0

	return


/datum/brain/utility/Life()
	while(life)
		CheckForCleanup()
		LifeTick()
		sleep(AI_TICK_DELAY)
	return


/datum/brain/utility/proc/OnBeginLifeTick()
	return


/datum/brain/utility/proc/OnInvalidAction(var/action_key) // str -> bool
	/* If the Action is invalid, what do we do?
	//
	// Returns a bool, indicating whether to try planning again in the same tick.
	*/

	// By default, abandon ship.
	RUN_ACTION_DEBUG_LOG("INVALID ACTION: [action_key] | <@[src]> | [__FILE__] -> L[__LINE__]")
	src.AbortPlan()
	return TRUE


/datum/brain/utility/proc/GetRequester() // () -> Any
	var/datum/utility_ai/mob_commander/controller = src.GetAiController()
	var/pawn = controller?.GetPawn()
	return pawn


/datum/brain/utility/proc/ScoreActions(var/list/actionsets)
	var/PriorityQueue/utility_ranking = new /PriorityQueue(/datum/Triple/proc/FirstTwoCompare)
	var/requester = src.GetRequester()

	for(var/datum/action_set/actionset in actionsets)
		if(!(actionset?.active))
			continue

		var/list/actions = actionset?.actions
		if(!actions)
			continue

		for(var/datum/utility_action_template/action_template in actions)
			var/list/contexts = action_template.GetCandidateContexts(requester)

			if(contexts)
				world.log << "Found contexts ([contexts.len])"
				var/ctxidx = 0

				for(var/ctx in contexts)
					// Yes, this is a triple-nested for-loop, and that's fine since we're looping
					// over different categories. In particular, the first two loops are effectively
					// one loop with a top-level optimization (skip all disabled actions in a set).
					//
					// That said, the amount of evaluated Contexts should be kept tightly constrained.
					// Only fetch contexts that are likely to be a) relevant & b) executed.
					var/utility = action_template.ScoreAction(ctx, requester)
					world.log << "Utility for [action_template?.name] ctx #[ctxidx++]: [utility]"
					var/datum/Triple/scored_action = new(utility, action_template, ctx)
					utility_ranking.Enqueue(scored_action)

			else
				// Some actions could have a 'null' context (i.e. they don't care about the world-state)
				// We should support this to avoid alloc-ing empty lists for efficiency, at the cost of smol code duplication
				var/utility = action_template.ScoreAction(null, requester) // null/default context
				var/datum/Triple/scored_action = new(utility, action_template, null) // ...and here, as a triple!
				utility_ranking.Enqueue(scored_action)

	return utility_ranking


/datum/brain/utility/GetAvailableActions()
	var/list/actionsets = list()
	var/filename = "mock_actionset.json"

	if(isnull(src.file_actionsets))
		src.file_actionsets = list()

	var/cached_as = src.file_actionsets[filename]

	var/datum/action_set/file_actionset = cached_as

	if(isnull(file_actionset))
		file_actionset = ActionSetFromJsonFile(filename)
		src.file_actionsets[filename] = file_actionset

	actionsets.Add(file_actionset)
	return actionsets


/datum/brain/utility/proc/HandlePlanningState()
	/* Main selection logic.
	// Runs through all available actions,
	// scores them by utility,
	// selects a high-utility action.
	*/

	// selection left intentionally vague; will probably do deterministic as PoC and weighted sampling later

	if(!is_planning)
		var/list/actionsets = GetAvailableActions()

		var/PriorityQueue/utility_ranking = src.ScoreActions(actionsets)
		var/best_act_res = utility_ranking.Dequeue()
		var/datum/Triple/best_act_tup = best_act_res

		if(!best_act_tup)
			RUN_ACTION_DEBUG_LOG("ERROR: Best action tuple is null! [best_act_res] | <@[src]> | [__FILE__] -> L[__LINE__]")
			return

		var/datum/utility_action_template/best_action_template = best_act_tup.middle
		var/list/best_action_ctx = best_act_tup.right
		var/datum/utility_action/best_action = best_action_template.ToAction(best_action_ctx)

		if(best_action)
			PUT_EMPTY_LIST_IN(src.active_plan)
			src.active_plan.Add(best_action)

		else
			RUN_ACTION_DEBUG_LOG("ERROR: Best action is null! | <@[src]> | [__FILE__] -> L[__LINE__]")

	else //satisfied, can be lazy
		Idle()

	return


/datum/brain/IsActionValid(var/action_key)
	/* Brain-side Action validation.
	//
	// An Action is considered invalid if it doesn't make sense to run it.
	// For instance, if the target of the Action has been deleted, we might
	// as well not even start it.
	//
	// Preconditions violation at run-time DOES NOT *ALWAYS* make the Action
	// invalid - Preconds are primarily constraints for _planning_ and can be
	// fudged sometimes to generate specific behaviours.
	//
	// For that matter, INVALID =/= FAILED!
	// INVALID *roughly* maps to 'failed before we even started' or 'not in a runnable state'
	// Failed Actions have started, but for whatever reason we're cancelling them before completion.
	*/
	return TRUE


/datum/brain/utility/LifeTick()
	var/run_count = 0
	var/target_run_count = 1
	var/do_plan = FALSE

	OnBeginLifeTick() // hook

	while(run_count++ < target_run_count)
		/* STATE: Running */
		if(running_action_tracker) // processing action
			RUN_ACTION_DEBUG_LOG("ACTIVE ACTION: [running_action_tracker.tracked_action] @ [running_action_tracker.IsRunning()] | <@[src]>")

			if(running_action_tracker.replan)
				do_plan = TRUE
				target_run_count++
				src.AbortPlan(FALSE)

			else if(running_action_tracker.is_done)
				src.NextPlanStep()
				target_run_count++

			else if(running_action_tracker.is_failed)
				src.AbortPlan(FALSE)


		/* STATE: Ready */
		else if(selected_action) // ready to go
			RUN_ACTION_DEBUG_LOG("SELECTED ACTION: [selected_action] | <@[src]>")

			var/is_valid = src.IsActionValid(selected_action)

			RUN_ACTION_DEBUG_LOG("SELECTED ACTION [selected_action]([selected_action?:arguments && json_encode(selected_action:arguments)]) VALID: [is_valid ? "TRUE" : "FALSE"]")

			if(is_valid)
				running_action_tracker = src.DoAction(selected_action)
				target_run_count++

			else
				var/should_rerun = src.OnInvalidAction(selected_action)
				if(should_rerun)
					target_run_count++

			selected_action = null


		/* STATE: Pending next stage */
		else if(active_plan && active_plan.len)
			//step done, move on to the next
			RUN_ACTION_DEBUG_LOG("ACTIVE PLAN: [active_plan] ([active_plan.len]) | <@[src]>")
			DEBUG_LOG_LIST_ARRAY(active_plan, RUN_ACTION_DEBUG_LOG)

			while(active_plan.len && isnull(selected_action))
				// do instants in one tick
				selected_action = lpop(active_plan)

				var/datum/utility_action/action = selected_action
				world.log << "Selected action: [action?.name || "NONE"]"

				if(action?.instant)
					RUN_ACTION_DEBUG_LOG("Instant ACTION: [selected_action] | <@[src]>")
					DoInstantAction(selected_action)
					selected_action = null

				else
					RUN_ACTION_DEBUG_LOG("Regular ACTION: [selected_action] | <@[src]>")


		else //no plan & need to make one
			do_plan = TRUE


		/* STATE: Planning */
		if(do_plan)
			var/prev_plan = src.active_plan

			var/should_retry = HandlePlanningState()

			if(should_retry)
				target_run_count++

			if(isnull(prev_plan) && src.active_plan)
				// If we created a new plan, execute straight away
				target_run_count++

	return

/datum/brain/utility/proc/Idle()
	return


/datum/brain/utility/proc/NextPlanStep()
	src.running_action_tracker = null
	return TRUE


/datum/brain/utility/AbortPlan(var/mark_failed = TRUE)
	if(mark_failed)
		// Mark the plan as failed
		src.last_plan_successful = FALSE
		src.running_action_tracker?.SetFailed()

	// Cancel current tracker, if any is running
	src.running_action_tracker = null

	// Cancel all instant and regular Actions
	PUT_EMPTY_LIST_IN(src.pending_instant_actions)
	src.active_plan = null
	src.selected_action = null

	return TRUE


/* Motives */
/datum/brain/utility/proc/GetMotive(var/motive_key)
	if(isnull(motive_key))
		return

	if(!(motive_key in needs))
		return

	var/curr_value = needs[motive_key]
	return curr_value


/datum/brain/utility/proc/ChangeMotive(var/motive_key, var/value)
	if(isnull(motive_key))
		return

	var/fixed_value = min(NEED_MAXIMUM, max(NEED_MINIMUM, (value)))
	needs[motive_key] = fixed_value
	last_need_update_times[motive_key] = world.time
	MOTIVES_DEBUG_LOG("Curr [motive_key] = [needs[motive_key]] <@[src]>")


/datum/brain/utility/proc/AddMotive(var/motive_key, var/amt)
	if(isnull(motive_key))
		return

	var/curr_val = needs[motive_key]
	ChangeMotive(motive_key, curr_val + amt)
