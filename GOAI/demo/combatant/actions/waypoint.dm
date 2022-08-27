
/mob/goai/combatant/proc/SpotObstacles(var/mob/goai/combatant/owner, var/atom/target = null, default_to_waypoint=TRUE)
	if(!owner)
		// No mob - no point.
		return

	var/datum/brain/owner_brain = owner?.brain
	if(isnull(owner_brain))
		// No point processing this if there's no memories to use
		// Might not be a precondition later.
		return

	var/atom/goal = target

	if(isnull(goal) && default_to_waypoint)
		var/atom/waypoint = owner.brain.GetMemoryValue(MEM_WAYPOINT_IDENTITY, null, FALSE, TRUE)
		goal = waypoint

	if(isnull(goal))
		// Nothing to spot.
		return

	var/list/path = null
	var/turf/target_turf = get_turf(goal)

	if(isnull(target_turf))
		target_turf = get_turf(goal.loc)

	var/turf/startpos = get_turf(owner)
	var/init_dist = 30
	// NOTE: somehow, this once runtimed with the distance seemingly being -1, wtf?
	//       the max() was added as a measure to ensure sane input
	var/sqrt_dist = (max(0, get_dist(startpos, target)) ** 0.5) * 0.5

	if(init_dist < 40)
		world.log << "[owner] entering ASTARS STAGE"
		path = AStar(owner, target_turf, /turf/proc/CardinalTurfs, /turf/proc/Distance, null, init_dist, min_target_dist = sqrt_dist, exclude = null)
		world.log << "[owner] found ASTAR 1 path from [startpos] to [target_turf]: [path] ([path?.len])"

		if(path && path.len)
			world.log << "[owner] entering HAPPYPATH"
			return

		// No unobstructed path to target!
		// Let's try to get a direct path and check for obstacles.
		path = AStar(owner, target_turf, /turf/proc/CardinalTurfsNoblocks, /turf/proc/Distance, null, init_dist, min_target_dist = sqrt_dist, exclude = null)
		world.log << "[src] found ASTAR 2 path from [startpos] to [target_turf]: [path] ([path?.len])"

		if(!path)
			return

		var/path_pos = 0

		world.log << "[owner] entering OBSTACLE HUNT STAGE"
		for(var/turf/pathitem in path)
			path_pos++
			//world.log << "[owner]: [pathitem]"

			if(isnull(pathitem))
				continue

			if(path_pos <= 1)
				continue

			var/turf/previous = path[path_pos-1]

			if(isnull(previous))
				continue

			var/last_link_blocked = LinkBlocked(previous, pathitem)

			if(last_link_blocked)
				world.log << "[owner]: LINK BETWEEN [previous] & [pathitem] OBSTRUCTED"
				// find the obstacle
				var/atom/obstruction = null

				if(!obstruction)
					for(var/atom/potential_obstruction_curr in pathitem.contents)
						var/datum/directional_blocker/blocker = potential_obstruction_curr?.directional_blocker
						if(!blocker)
							continue

						var/dirDelta = get_dir(previous, potential_obstruction_curr)
						var/blocks = blocker.Blocks(dirDelta)

						if(blocks)
							obstruction = potential_obstruction_curr
							break

				if(!obstruction && path_pos > 2) // check earlier steps
					for(var/atom/potential_obstruction_prev in previous.contents)
						var/datum/directional_blocker/blocker = potential_obstruction_prev?.directional_blocker
						if(!blocker)
							continue

						var/dirDeltaPrev = get_dir(path[path_pos-2], potential_obstruction_prev)
						var/blocksPrev = blocker.Blocks(dirDeltaPrev)

						if(blocksPrev)
							obstruction = potential_obstruction_prev
							break

				world.log << "[owner]: LINK OBSTRUCTION => [obstruction] @ [obstruction?.loc]"
				owner.brain.SetMemory(MEM_OBSTRUCTION, obstruction, MEM_TIME_LONGTERM)
				break

	return


/mob/goai/combatant/proc/HandleWaypointObstruction(var/atom/obstruction, var/atom/waypoint, var/list/shared_preconds = null, var/list/target_preconds = null, var/move_action_name = "MoveTowards")
	if(!obstruction || !waypoint || !move_action_name)
		world.log << "HandleWaypointObstruction failed! <[obstruction], [waypoint], [move_action_name]>"
		return FALSE

	var/list/common_preconds = shared_preconds?.Copy() || list()
	var/list/goto_preconds = target_preconds?.Copy() || list()

	var/obj/cover/door/D = obstruction

	if(D && istype(D) && !(D.open))
		var/obs_need_key = NEED_OBSTACLE_OPEN(obstruction)
		//SetState(obs_need_key, FALSE)
		SetState("DoorOpen", FALSE)

		var/list/open_door_preconds = common_preconds.Copy()
		//open_door_preconds[obs_need_key] = FALSE
		open_door_preconds["DoorOpen"] = FALSE

		AddAction(
			"Open [obstruction]",
			open_door_preconds,
			list(
				//obs_need_key = TRUE,
				"DoorOpen" = TRUE,
			),
			/mob/goai/combatant/proc/HandleOpenDoor,
			5,
			1
		)

		goto_preconds["DoorOpen"] = TRUE
		//goto_preconds[obs_need_key] = TRUE


	var/obj/cover/autodoor/AD = obstruction

	if(AD && istype(AD) && !(AD.open))
		var/obs_need_key = NEED_OBSTACLE_OPEN(obstruction)
		SetState(obs_need_key, FALSE)

		var/list/open_autodoor_preconds = common_preconds.Copy()
		//open_autodoor_preconds[obs_need_key] = FALSE
		open_autodoor_preconds["DoorOpen"] = FALSE

		AddAction(
			"Open [obstruction]",
			open_autodoor_preconds,
			list(
				//obs_need_key = TRUE,
				"DoorOpen" = TRUE,
			),
			/mob/goai/combatant/proc/HandleOpenAutodoor,
			5,
			1
		)

		goto_preconds["DoorOpen"] = TRUE
		//goto_preconds[obs_need_key] = TRUE


	AddAction(
		"[move_action_name] [waypoint]",
		goto_preconds,
		list(
			NEED_COVER = NEED_SATISFIED,
			NEED_OBEDIENCE = NEED_SATISFIED,
			STATE_INCOVER = 1,
			//STATE_DISORIENTED = 1,
		),
		/mob/goai/combatant/proc/HandleDirectionalCoverLeapfrog,
		1,
		//1, /* It would MAKE SENSE to limit charges on this (so a new PathPlan readds a new charge)
		//      except for the fact that for some reason IT DOESN'T WORK ARGH (yet, probably - TODO) */
		PLUS_INF
	)

	return TRUE


/mob/goai/combatant/proc/HandleWaypoint(var/datum/ActionTracker/tracker)
	// Locate waypoint
	// Capture any obstacles
	// Add Action Goto<Goal> with clearing obstacles as a precond

	if(!src || !(src?.brain))
		tracker?.SetFailed()
		return

	var/atom/waypoint = brain.GetMemoryValue(MEM_WAYPOINT_IDENTITY, null, FALSE, TRUE)
	if(isnull(waypoint))
		tracker?.SetFailed() // b/c we shouldn't have triggered this in the first place if it's null
		return

	// Astar checking for obstacles
	src.SpotObstacles(src, waypoint, FALSE)

	var/list/goto_preconds = list(
		//STATE_HASWAYPOINT = TRUE,
		STATE_PANIC = -TRUE,
		//STATE_DISORIENTED = -TRUE,
	)

	var/list/common_preconds = list(
		STATE_PANIC = -TRUE,
		//STATE_DISORIENTED = -TRUE,
	)

	var/atom/obstruction = brain.GetMemoryValue(MEM_OBSTRUCTION)

	HandleWaypointObstruction(obstruction, waypoint, common_preconds, goto_preconds)

	SetState(STATE_DISORIENTED, FALSE)

	tracker.SetDone()
	return

