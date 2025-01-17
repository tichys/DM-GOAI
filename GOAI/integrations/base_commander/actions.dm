/* In this module:
===================

 - Action handling API

*/

/datum/goai/proc/AddAction(var/name, var/list/preconds, var/list/effects, var/handler, var/cost = null, var/charges = PLUS_INF, var/instant = FALSE, var/list/action_args = null, var/list/act_validators = null, var/cost_checker = null)
	if(charges < 1)
		return

	var/datum/goai_action/Action = null
	if(name in src.actionslist)
		Action = src.actionslist[name]

	if(isnull(Action) || (!istype(Action)))
		Action = new(preconds, effects, cost, name, charges, instant, action_args, act_validators, cost_checker)

	else
		// If an Action with the same key exists, we can update the existing object rather than reallocating!
		SET_IF_NOT_NULL(cost, Action.cost)
		SET_IF_NOT_NULL(preconds, Action.preconditions)
		SET_IF_NOT_NULL(effects, Action.effects)
		SET_IF_NOT_NULL(charges, Action.charges)
		SET_IF_NOT_NULL(instant, Action.instant)
		SET_IF_NOT_NULL(action_args, Action.arguments)
		SET_IF_NOT_NULL(act_validators, Action.validators)
		SET_IF_NOT_NULL(cost_checker, Action.cost_updater)

	src.actionslist = (isnull(src.actionslist) ? list() : src.actionslist)
	src.actionslist[name] = Action

	if(handler)
		actionlookup = (isnull(actionlookup) ? list() : actionlookup)
		actionlookup[name] = handler

	if(brain)
		brain.AddAction(name, preconds, effects, cost, charges, instant, FALSE, action_args, act_validators, cost_checker)

	return Action


/datum/goai/proc/HandleAction(var/datum/goai_action/action, var/datum/ActionTracker/tracker)
	MAYBE_LOG("Tracker: [tracker]")
	var/running = 1

	var/list/action_lookup = src.actionlookup // abstract maybe
	if(isnull(action_lookup))
		return

	while (tracker && running)
		// TODO: Interrupts
		running = tracker.IsRunning()

		MAYBE_LOG("[src]: Tracker: [tracker] running @ [running]")

		spawn(0)
			// task-specific logic goes here
			MAYBE_LOG("[src]: HandleAction action is: [action]")

			var/actionproc = action_lookup[action.name]

			var/list/action_args = list()
			action_args["tracker"] = tracker
			action_args += action.arguments

			if(isnull(actionproc))
				tracker.SetFailed()

			else
				call(src, actionproc)(arglist(action_args))

				if(action.instant)
					break

		var/safe_ai_delay = max(1, src.ai_tick_delay)
		sleep(safe_ai_delay)


/datum/goai/proc/HandleInstantAction(var/datum/goai_action/action, var/datum/ActionTracker/tracker)
	MAYBE_LOG("Tracker: [tracker]")

	var/list/action_lookup = actionlookup // abstract maybe
	if(isnull(action_lookup))
		return

	MAYBE_LOG("[src]: Tracker: [tracker] running @ [tracker?.IsRunning()]")
	MAYBE_LOG("[src]: HandleAction action is: [action]")

	var/actionproc = action_lookup[action.name]

	var/list/action_args = list()
	action_args["tracker"] = tracker
	action_args += action.arguments

	if(isnull(actionproc))
		tracker.SetFailed()

	else
		call(src, actionproc)(arglist(action_args))

	return



/datum/goai/proc/Idle()
	return



/datum/goai/proc/HandleIdling(var/datum/ActionTracker/tracker)
	Idle()

	if(tracker.IsOlderThan(20))
		tracker.SetDone()

	return
