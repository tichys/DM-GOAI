
# ifdef DIRBLOCKER_DEBUG_LOGGING
# define DIRBLOCKER_DEBUG_LOG(X) to_world_log(X)
# else
# define DIRBLOCKER_DEBUG_LOG(X)
# endif

/datum/directional_blocker
	/* A component that indicates that whatever object its attached to
	behaves like a directional blocker (e.g. SS13 'small' windows or flipped tables).
	*/
	var/blocks_entry = null
	var/blocks_exit = null
	var/block_all = FALSE
	var/is_active = TRUE

	var/attached_to = null  // REMOVE ME!


/datum/directional_blocker/New(var/block_dirs_entry, var/block_dirs_exit = null, var/block_all_dirs = FALSE, var/active = TRUE)
	SET_IF_NOT_NULL(block_dirs_entry, src.blocks_entry)
	SET_IF_NOT_NULL(block_dirs_exit, src.blocks_exit)

	block_all = (isnull(block_all_dirs) ? block_all : block_all_dirs)
	is_active = (isnull(active) ? is_active : active)


/datum/directional_blocker/proc/BlocksEntry(var/dir, var/query_user = null)
	if(isnull(dir))
		DIRBLOCKER_DEBUG_LOG("[src]  @ [src.attached_to || "<detached>"] BlocksEntry is null!")
		return FALSE

	if(!(src.is_active))
		DIRBLOCKER_DEBUG_LOG("[src] @ [src.attached_to || "<detached>"] is inactive...")
		return FALSE

	var/atom/movable/atom_user = query_user

	if(istype(atom_user))
		if(src == atom_user.directional_blocker)
			// no self-collisions!
			return FALSE

	var/datum/goai/mob_commander/commander_user = query_user

	if(commander_user && istype(commander_user))
		var/atom/commander_pawn = commander_user.GetPawn()

		if(commander_pawn && src == commander_pawn.directional_blocker)
			// no self-collisions!
			return FALSE

	if(block_all)
		DIRBLOCKER_DEBUG_LOG("[src] blocks all - TRUE!")
		return TRUE

	var/result = blocks_entry & dir
	DIRBLOCKER_DEBUG_LOG("[src] blocks_entry & dir - [result]")
	return result


/datum/directional_blocker/proc/BlocksExit(var/dir, var/query_user = null)
	if(isnull(dir))
		DIRBLOCKER_DEBUG_LOG("[src] @ [src.attached_to || "<detached>"] BlocksExit is null!")
		return FALSE

	if(!(src.is_active))
		DIRBLOCKER_DEBUG_LOG("[src] @ [src.attached_to || "<detached>"] is inactive...")
		return FALSE

	/*
	var/atom/movable/atom_user = query_user

	if(istype(atom_user))
		if(src == atom_user.directional_blocker)
			// no self-collisions!
			return FALSE

	var/datum/goai/mob_commander/commander_user = query_user

	if(commander_user && istype(commander_user))
		var/atom/commander_pawn = commander_user.GetPawn()

		if(commander_pawn && src == commander_pawn.directional_blocker)
			// no self-collisions!
			return FALSE
	*/

	if(block_all)
		DIRBLOCKER_DEBUG_LOG("[src] blocks all - TRUE!")
		return TRUE

	var/result = blocks_exit & dir
	DIRBLOCKER_DEBUG_LOG("[src] blocks_exit & dir - [result]")
	return result


/datum/directional_blocker/proc/AttachTo(var/atom/blockerable)
	if(!blockerable)
		return FALSE

	blockerable.directional_blocker = src
	return TRUE


/atom/proc/GenerateBlocker()
	// by default
	return null


/atom/proc/ShouldHaveBlocker()
	// by default
	return FALSE


/atom/proc/GetBlockerData(var/generate_if_missing = FALSE, var/log_on_missing = FALSE)
	var/datum/directional_blocker/myblocker = src.directional_blocker

	if(!myblocker)
		if(src.blocker_gen_enabled)
			if(generate_if_missing)
				spawn(0)
					myblocker = src.GenerateCover()
					src.directional_blocker = myblocker

			if(log_on_missing)
				to_world_log("Failed to get blocker for [src] - no blocker data!")

	return src.directional_blocker
