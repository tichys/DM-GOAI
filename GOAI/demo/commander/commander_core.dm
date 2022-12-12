/*
// AI Commander - an abstract AI agent that can represent a faction or an L4D-style Director.
// May act via physical GOAI Agents, 'dumb' AIs, spawners, any combination of these, or more!
//
// DESIGN NOTE: While this is a more abstract entity, it should be more akin to Agents than to
//   Brains - it should have a Brain as a component, alongside Senses and Actions like a physical being.
//   This is so that we could, in principle, 'transplant' the components into an Agent to act as an avatar of sorts
//   or go the other way and port an Agent into a Commander to model distributed executors, e.g. tentacles of a Kraken
*/

var/global/list/global_goai_registry


/datum/goai_commander
	var/life = GOAI_AI_ENABLED
	var/name

	var/list/needs
	var/list/states
	var/list/actionslist
	var/list/actionlookup
	var/list/inventory
	var/list/senses

	var/list/last_need_update_times
	var/last_action_update_time

	var/planning_iter_cutoff = 30
	var/pathing_dist_cutoff = 60

	var/datum/brain/brain

	// Private-ish, generally only debug procs should touch these
	var/ai_tick_delay = COMMANDERAI_AI_TICK_DELAY

	// Optional - for map editor. Set this to force initial action. Must be valid (in available actions).
	var/initial_action = null


/datum/goai_commander/proc/RegisterAI()
	// Registry pattern, to facilitate querying all GOAI AIs in verbs
	if(!(global_goai_registry))
		global_goai_registry = list()

	global_goai_registry += src

	if(!(src.name))
		src.name = global_goai_registry.len

	return global_goai_registry


/datum/goai_commander/New()
	..()
	src.RegisterAI()

	src.actionlookup = src.InitActionLookup()  // order matters!
	src.actionslist = src.InitActionsList()

	src.Equip()
	src.brain = src.CreateBrain(actionslist)
	src.InitNeeds()
	src.InitStates()
	src.UpdateBrain()
	src.InitSenses()
	src.Life()


/datum/goai_commander/proc/Life()
	// Perception updates
	spawn(0)
		while(life)
			src.SensesSystem()
			sleep(COMBATAI_SENSE_TICK_DELAY)

	// AI
	spawn(0)
		while(life)
			// Fix the tickrate to prevent runaway loops in case something messes with it.
			// Doing it here is nice, because it saves us from sanitizing it all over the place.
			src.ai_tick_delay = max((src?.ai_tick_delay || 0), 1)

			// Run the Life update function.
			src.LifeTick()

			// Wait until the next update tick.
			sleep(src.ai_tick_delay)



/datum/goai_commander/proc/LifeTick()

	if(brain)
		brain.LifeTick()
		//world.log << "[src.name] brain LifeTick() running..."

		for(var/datum/ActionTracker/instant_action_tracker in brain.pending_instant_actions)
			var/tracked_instant_action = instant_action_tracker?.tracked_action
			if(tracked_instant_action)
				HandleInstantAction(tracked_instant_action, instant_action_tracker)

		if(brain.running_action_tracker)
			var/tracked_action = brain.running_action_tracker.tracked_action
			if(tracked_action)
				HandleAction(tracked_action, brain.running_action_tracker)

	return


/datum/goai_commander/proc/UpdateBrain()
	if(!brain)
		return

	brain.needs = needs.Copy()
	brain.states = states.Copy()

	return TRUE


/datum/goai_commander/proc/SetState(var/key, var/val)
	if(!key)
		return

	world.log << "[src]: setting state [key] => [val] on the mob!"
	states[key] = val

	if(brain)
		brain.SetState(key, val)

	return TRUE


/datum/goai_commander/proc/GetState(var/key, var/default = null)
	if(!key)
		world.log << "[src]: [key] is null!"
		return

	if(brain && (key in brain.states))
		//world.log << "[src]: getting state [key] from the brain!"
		return brain.GetState(key, default)

	if(key in states)
		//world.log << "[src]: getting state [key] from the mob!"
		return states[key]

	return default
