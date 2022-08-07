/atom
	var/datum/cover/cover = null
	var/datum/directional_blocker/directional_blocker = null


/atom/proc/Hit(var/hit_angle, var/atom/shotby = null)
	/* hit angle - clockwise from positive Y axis if positive,
	counterclockwise if negative.

	Can use the IMPACT_ANGLE(x) macro to calculate.

	shotby - a reference to who shot us (atom - to incl. turret objects etc.)
	*/

	return


/atom/proc/CurrentPositionAsTuple()
	var/datum/Tuple/pos_tuple = new(src.x, src.y)
	return pos_tuple


/atom/proc/CurrentPositionAsTriple()
	var/datum/Triple/pos_triple = new(src.x, src.y, src.z)
	return pos_triple


/atom/proc/IsCover(var/transitive = FALSE, var/for_dir = null, var/default_for_null_dir = FALSE)
	if(src.density)
		return TRUE

	if(istype(cover) && cover?.CoversInDir(for_dir, default_for_null_dir))
		return TRUE

	if(transitive && src.HasCover(for_dir, default_for_null_dir))
		return TRUE

	return FALSE



/atom/proc/HasCover(var/for_dir = null, var/default_for_null_dir = FALSE)
	for(var/atom/local_obj in src.contents)
		if(local_obj.IsCover(FALSE, for_dir))
			return local_obj

	return null


/atom/Enter(var/atom/movable/O, var/atom/oldloc)
	. = ..()

	var/turf/oldloc_turf = oldloc
	var/turf/newloc_turf = src

	if(istype(oldloc_turf) && istype(newloc_turf))
		var/link_is_blocked = LinkBlocked(oldloc_turf, newloc_turf)

		if(link_is_blocked)
			return FALSE

	return .