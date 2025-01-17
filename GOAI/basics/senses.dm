/* Contains basic definitions of the senses system.
//
// General design principles here:
//
// - Senses process some 'sensory' data on a tick-by-tick basis
// - Senses communicate with the AI by setting/updating Memories
// - Senses are invoked by the SenseSystem for scheduling, ECS-style
//   (SenseSystems reside in agent AI procs; not part of this spec)
*/

/sense
	// to keep typepaths compact...
	parent_type = /datum

	var/processing = FALSE // to avoid calling stuff multiple times per tick
	var/enabled = TRUE


/sense/proc/ProcessTick(var/owner)
	// overall logic goes here;
	// gather some data & set memories.
	return


/sense/proc/Enable()
	// switches itself on
	if(!(src.enabled))
		src.processing = FALSE
		src.enabled = TRUE

	return src.enabled


/sense/proc/Disable()
	// switches itself off
	src.enabled = FALSE
	src.processing = FALSE
	return src.enabled


/sense/proc/Toggle()
	// switches itself between on and off states

	if(src.enabled)
		src.Disable()

	else
		src.Enable()

	return src.enabled


/sense/proc/GetOwnerAiTickrate(var/owner)
	/* convenience method; single-dispatch-ifies different owners to figure
	out what tick rate to use; uses a constant as a fallback option. */
	var/tickrate = AI_TICK_DELAY

	# ifdef GOAI_AGENTS_INCLUDED

	var/mob/goai/combatant/combatmob = owner

	if(combatmob)
		tickrate = combatmob.ai_tick_delay
		return tickrate

	#endif

	var/datum/goai/commander = owner

	if(commander)
		tickrate = commander.ai_tick_delay
		return tickrate

	var/datum/utility_ai/utility_commander = owner

	if(utility_commander)
		tickrate = utility_commander.ai_tick_delay
		return tickrate

	return tickrate


