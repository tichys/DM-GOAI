
/* The most fundamental pathfinding proc here;
// the rest are higher-level abstractions and
// integrations w/ other subsystems (e.g. memory)
*/
/mob/goai/combatant/proc/ChoosePanicRunLandmark(var/atom/primary_threat = null, var/list/threats = null, min_safe_dist = null)
	// Pathfinding/search
	var/turf/best_local_pos = brain?.GetMemoryValue(MEM_BESTPOS_PANIC, null)
	if(best_local_pos)
		return best_local_pos

	var/list/_threats = (threats || list())
	var/_min_safe_dist = (isnull(min_safe_dist) ? 0 : min_safe_dist)

	var/list/processed = list()
	var/PriorityQueue/cover_queue = new /PriorityQueue(/datum/Quadruple/proc/TriCompare)

	var/list/curr_view = brain?.perceptions?.Get(SENSE_SIGHT) || list()

	var/turf/last_loc = brain?.GetMemoryValue("Location-1", null)
	if(last_loc)
		curr_view.Add(last_loc)

	var/turf/prev_to_last_loc = brain?.GetMemoryValue("Location-2", null)
	if(prev_to_last_loc)
		curr_view.Add(prev_to_last_loc)

	var/turf/safespace_loc = brain?.GetMemoryValue(MEM_SAFESPACE, null)
	if(safespace_loc)
		curr_view.Add(safespace_loc)

	var/turf/unreachable = brain?.GetMemoryValue("UnreachableTile", null)
	var/datum/chunkserver/chunkserver = GetOrSetChunkserver()

	for(var/turf/cand in curr_view)
		// NOTE: This is DIFFERENT to cover moves! We're not doing a double-loop here!
		if(unreachable && cand == unreachable)
			continue

		if(!(cand?.Enter(src, src.loc)))
			continue

		if(cand in processed)
			continue

		if(!(cand in curr_view))
			continue

		var/penalty = 0
		var/threat_dist = 0
		var/heat = 0

		var/datum/chunk/candchunk = chunkserver.ChunkForAtom(cand)

		for(var/dict/threat_ghost in _threats)

			if(threat_ghost)

				threat_dist = GetThreatDistance(cand, threat_ghost)
				var/datum/chunk/threatchunk = GetThreatChunk(threat_ghost)

				if(threat_dist < _min_safe_dist)
					heat++

				else if(threatchunk == candchunk)
					heat++

		if(heat == 1)
			penalty += MAGICNUM_DISCOURAGE_SOFT

		if(heat >= 2)
			continue

		//var/datum/Tuple/curr_pos_tup = cand.CurrentPositionAsTuple()

		/*if (curr_pos_tup ~= shot_at_where)
			to_world_log("[src]: Curr pos tup [curr_pos_tup] ([curr_pos_tup?.left], [curr_pos_tup?.right]) equals shot_at_where")
			continue*/

		var/cand_dist = ManhattanDistance(cand, src)
		//var/targ_dist = (waypoint ? ManhattanDistance(cand, waypoint) : 0)
		var/targ_dist = 0 // ignore waypoint, just leg it!
		var/total_dist = (cand_dist + targ_dist)

		if(threat_dist < min_safe_dist)
			//processed.Add(cand)
			continue

		penalty += -threat_dist  // the further from a threat, the better

		var/datum/Quadruple/cover_quad = new(threat_dist**2, -penalty, -total_dist, cand)
		cover_queue.Enqueue(cover_quad)
		processed.Add(cand)

	best_local_pos = ValidateWaypoint(cover_queue, TRUE)

	if(best_local_pos)
		SpotObstacles(src, best_local_pos, FALSE)

		// Obstacles:
		var/atom/obstruction = brain.GetMemoryValue(MEM_OBSTRUCTION)
		var/handled = isnull(obstruction) // if obs is null, counts as handled

		if(obstruction)
			var/list/shared_preconds = list(

			)

			var/list/movement_preconds = list(
				STATE_PANIC = TRUE,
			)

			handled = HandleWaypointObstruction(
				obstruction = obstruction,
				waypoint = best_local_pos,
				shared_preconds = shared_preconds,
				target_preconds = movement_preconds,
				move_action_name = "PanicRun",
				move_handler = /mob/goai/combatant/proc/HandlePanickedRun,
				unique = FALSE,
				allow_failed = TRUE
			)

		if(!handled)
			to_world_log("PanicRun target [best_local_pos] is unreachable!")
			//brain?.SetMemory("UnreachableTile", best_local_pos)

	if(best_local_pos)
		brain?.SetMemory(MEM_BESTPOS_PANIC, best_local_pos, PANIC_SENSE_THROTTLE*30)

	return best_local_pos


/* Wrapper over ChoosePanicRunLandmark();
//
// Adds integrations w/ Threat system and ActionTracker data, but is otherwise
// generally stateless (not *fully*, b/c we call some potentially impure methods)
*/
/mob/goai/combatant/proc/pureHandleChoosePanicRunLandmark(var/mob/goai/combatant/owner = null, var/atom/bestpos = null, var/min_safe_dist = 2, var/list/cached_threats = null)
	// Abstracted ownership, but defaults to src for convenience.
	var/mob/goai/combatant/true_owner = (owner || src)

	var/turf/best_local_pos = null
	best_local_pos = (best_local_pos || bestpos)

	if(best_local_pos)
		return

	var/list/threats = (cached_threats ? cached_threats.Copy() : list())
	var/primary_threat = threats?[1]

	// Run pathfind
	best_local_pos = true_owner.ChoosePanicRunLandmark(primary_threat, threats, min_safe_dist)

	return best_local_pos


/* Wrapper over pureHandleChoosePanicRunLandmark();
//
// Adds a full integration w/ ActionTracker and thus can run
// as a GOAI Action. Also provides defaults, caching, etc.
*/
/mob/goai/combatant/proc/HandleChoosePanicRunLandmark(var/datum/ActionTracker/tracker)
	to_world_log("Running HandleChoosePanicRunLandmark")

	var/turf/best_local_pos = brain?.GetMemoryValue(MEM_BESTPOS_PANIC, null)
	best_local_pos = best_local_pos || tracker?.BBGet(MEM_BESTPOS_PANIC, null)

	if(best_local_pos)
		return

	var/list/threats = list()
	var/min_safe_dist = (brain?.GetPersonalityTrait(KEY_PERS_MINSAFEDIST, null) || 2)

	// Main threat:
	var/dict/primary_threat_ghost = GetActiveThreatDict()
	var/datum/Tuple/primary_threat_pos_tuple = GetThreatPosTuple(primary_threat_ghost)
	var/atom/primary_threat = null
	if(!(isnull(primary_threat_pos_tuple?.left) || isnull(primary_threat_pos_tuple?.right)))
		primary_threat = locate(primary_threat_pos_tuple.left, primary_threat_pos_tuple.right, src.z)

	if(primary_threat_ghost)
		threats[primary_threat_ghost] = primary_threat

	// Secondary threat:
	var/dict/secondary_threat_ghost = GetActiveSecondaryThreatDict()
	var/datum/Tuple/secondary_threat_pos_tuple = GetThreatPosTuple(secondary_threat_ghost)
	var/atom/secondary_threat = null
	if(!(isnull(secondary_threat_pos_tuple?.left) || isnull(secondary_threat_pos_tuple?.right)))
		secondary_threat = locate(secondary_threat_pos_tuple.left, secondary_threat_pos_tuple.right, src.z)

	if(secondary_threat_ghost)
		threats[secondary_threat_ghost] = secondary_threat

	// Run pathfind
	best_local_pos = pureHandleChoosePanicRunLandmark(
		src,
		best_local_pos,
		primary_threat,
		min_safe_dist,
		threats
	)

	if(best_local_pos)
		tracker?.BBSet(MEM_BESTPOS_PANIC, best_local_pos)
		tracker?.SetDone()

		brain?.SetMemory(MEM_BESTPOS_PANIC, best_local_pos)

	else if(active_path && tracker?.IsOlderThan(COMBATAI_MOVE_TICK_DELAY * 5))
		tracker?.SetFailed()

	return best_local_pos


/* And now for something completely different...
//
// This is the *actual* logic for Running The Hell Away.
//
*/

/mob/goai/combatant/proc/fPanicRunDistance(var/S, var/T)
	if(!S || !T)
		return

	var/turf/s = get_turf(S)
	var/turf/t = get_turf(T)

	if(!s || !t)
		return

	var/base_dist = fObstaclePenaltyDistance(S, T)
	var/threat_penalty = 0

	var/dict/primary_threat_ghost = GetActiveThreatDict()
	var/datum/Tuple/primary_threat_pos_tuple = GetThreatPosTuple(primary_threat_ghost)
	var/atom/primary_threat = null
	if(!(isnull(primary_threat_pos_tuple?.left) || isnull(primary_threat_pos_tuple?.right)))
		primary_threat = locate(primary_threat_pos_tuple.left, primary_threat_pos_tuple.right, src.z)

	var/turf/threat_turf = null
	if(primary_threat)
		threat_turf = get_turf(primary_threat)

		// IDEA: Gradient of cost. We want to move from more threatened turf to a <= threatened one.
		// e.g. in Start is 2 tiles from threat and T is 3, we good. T=2 & S=3, avoid T if possible.
		var/s_dist = ManhattanDistance(s, threat_turf)
		var/t_dist = ManhattanDistance(t, threat_turf)

		var/delta_threat = max(0, (s_dist - t_dist))
		// Multipliers etc. Might change the formula later.
		threat_penalty += delta_threat * 5

	var/total_dist = base_dist + threat_penalty
	return total_dist



/mob/goai/combatant/proc/HandlePanickedRun(var/datum/ActionTracker/tracker)
	var/tracker_frustration = tracker?.BBSetDefault("frustration", 0)

	var/turf/best_local_pos = null
	best_local_pos = best_local_pos || tracker?.BBGet(MEM_BESTPOS_PANIC, null)

	if(isnull(best_local_pos))
		best_local_pos = brain?.GetMemoryValue(MEM_BESTPOS_PANIC, null)

	var/min_safe_dist = (brain?.GetPersonalityTrait(KEY_PERS_MINSAFEDIST) || 2)
	var/frustration_repath_maxthresh = brain.GetPersonalityTrait(KEY_PERS_FRUSTRATION_THRESH, null) || 3

	var/list/threats = new()

	// Main threat:
	var/dict/primary_threat_ghost = GetActiveThreatDict()
	var/datum/Tuple/primary_threat_pos_tuple = GetThreatPosTuple(primary_threat_ghost)
	var/atom/primary_threat = null
	if(!(isnull(primary_threat_pos_tuple?.left) || isnull(primary_threat_pos_tuple?.right)))
		primary_threat = locate(primary_threat_pos_tuple.left, primary_threat_pos_tuple.right, src.z)

	if(primary_threat_ghost)
		threats[primary_threat_ghost] = primary_threat

	//to_world_log("[src]: Threat for [src]: [threat || "NONE"]")

	// Secondary threat:
	var/dict/secondary_threat_ghost = GetActiveSecondaryThreatDict()
	var/datum/Tuple/secondary_threat_pos_tuple = GetThreatPosTuple(secondary_threat_ghost)
	var/atom/secondary_threat = null
	if(!(isnull(secondary_threat_pos_tuple?.left) || isnull(secondary_threat_pos_tuple?.right)))
		secondary_threat = locate(secondary_threat_pos_tuple.left, secondary_threat_pos_tuple.right, src.z)

	if(secondary_threat_ghost)
		threats[secondary_threat_ghost] = secondary_threat

	// Shot-at logic (avoid known currently unsafe positions):
	/*
	var/datum/memory/shot_at_mem = brain?.GetMemory(MEM_SHOTAT, null, FALSE)
	var/dict/shot_at_memdata = shot_at_mem?.val
	var/datum/Tuple/shot_at_where = shot_at_memdata?.Get(KEY_GHOST_POS_TUPLE, null)
	*/

	// Reuse cached solution if it's good enough
	if(isnull(best_local_pos) && active_path && (!(active_path.IsDone())) && active_path.target && active_path.frustration < 2)
		best_local_pos = active_path.target

	// Required for the following logic: next location on the path
	var/atom/next_step = ((active_path && active_path.path && active_path.path.len) ? active_path.path[1] : null)

	// Bookkeeping around threats
	for(var/dict/threat_ghost in threats)
		if(isnull(threat_ghost))
			continue

		var/atom/curr_threat = threats[threat_ghost]
		var/next_step_threat_distance = (next_step ? GetThreatDistance(next_step, threat_ghost, PLUS_INF) : PLUS_INF)
		var/curr_threat_distance = GetThreatDistance(src, threat_ghost, PLUS_INF)
		var/bestpos_threat_distance = GetThreatDistance(best_local_pos, threat_ghost, PLUS_INF)

		var/atom/bestpos_threat_neighbor = (curr_threat ? get_step_towards(best_local_pos, curr_threat) : null)

		// Reevaluating plans as new threats pop up
		var/bestpos_is_unsafe = (bestpos_threat_distance < min_safe_dist && !(bestpos_threat_neighbor?.IsCover(TRUE, get_dir(bestpos_threat_neighbor, curr_threat), FALSE)))
		var/currpos_is_unsafe = (
			(tracker_frustration < frustration_repath_maxthresh) && (curr_threat_distance <= min_safe_dist) && (next_step_threat_distance < curr_threat_distance)
		)

		if(bestpos_is_unsafe || currpos_is_unsafe)
			if(tracker_frustration <= 3)
				tracker.BBSet("frustration", tracker_frustration+1)
				to_world_log("[src]: Dropping PanicRun bestpos - unsafe!")

				CancelNavigate()
				best_local_pos = null
				tracker.BBSet(MEM_BESTPOS_PANIC, null)
				brain?.DropMemory(MEM_BESTPOS_PANIC)
				break

			else
				to_world_log("[src]: PanicRun bestpos unsafe, but too frustrated to care.")


	if(isnull(best_local_pos))
		best_local_pos = ChoosePanicRunLandmark(primary_threat, threats, min_safe_dist)
		to_world_log("[src]: Found run away waypoint [best_local_pos]")
		tracker.BBSet(MEM_BESTPOS_PANIC, best_local_pos)
		brain?.SetMemory(MEM_BESTPOS_PANIC, best_local_pos, PANIC_SENSE_THROTTLE*3)
		to_world_log((isnull(best_local_pos) ? "[src]: Best local pos: null" : "[src]: Best local pos [best_local_pos]"))

	if(best_local_pos && (!active_path || active_path.target != best_local_pos))
		// CORE MOVEMENT TRIGGER - FOUND POSITION, START PATHING TO IT
		to_world_log("[src]: Navigating to [best_local_pos]")
		StartNavigateTo(best_local_pos, 0, primary_threat?.loc, 0, /mob/goai/combatant/proc/fPanicRunDistance)

	if(best_local_pos)
		var/dist_to_pos = ManhattanDistance(src.loc, best_local_pos)
		if(dist_to_pos < 1)
			tracker.SetTriggered()

	var/is_triggered = tracker.IsTriggered()
	var/datum/brain/concrete/needybrain = brain

	if(is_triggered)
		if(tracker.TriggeredMoreThan(src.ai_tick_delay))
			tracker.SetDone()

			if(needybrain)
				needybrain.ChangeMotive(NEED_COMPOSURE, NEED_SAFELEVEL)

	else if(active_path && tracker.IsOlderThan(COMBATAI_MOVE_TICK_DELAY * 20))
		brain?.SetMemory("UnreachableTile", active_path.target, MEM_TIME_LONGTERM)
		if(prob(10))
			step_away(src, primary_threat || secondary_threat || src)
		tracker.SetFailed()


	else if(tracker.IsOlderThan(COMBATAI_MOVE_TICK_DELAY * 10))
		if(prob(10))
			step_away(src, primary_threat || secondary_threat || src)

		tracker.SetFailed()

	return
