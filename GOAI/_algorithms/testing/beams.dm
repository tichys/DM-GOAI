


/obj/vectorbeam
	name = "Beam"
	icon = 'icons/effects/beam.dmi'
	icon_state = "r_beam"

	var/atom/source = null
	var/scale = 1
	var/dist = 1
	var/angle = 0


/obj/vectorbeam/proc/UpdateVector(var/atom/new_source = null, var/new_scale = null, var/new_dist = null, var/new_angle = null)
	source = (isnull(new_source) ? source : new_source)
	scale = (isnull(new_scale) ? scale : new_scale)
	dist = (isnull(new_dist) ? dist : new_dist)
	angle = (isnull(new_angle) ? angle : new_angle)

	var/matrix/beam_transform = new()
	var/turn_angle = -angle // normal Turn() is clockwise (y->x), we want (x->y).
	var/x_translate = dist * cos(angle)
	var/y_translate = dist * sin(angle)

	if((angle > 135 || angle <= -45))
		// some stupid nonsense with how matrix.Turn() works requires this
		turn_angle = 180 - angle

	world.log << "SpinAngle [angle], YTrans: [y_translate]"

	beam_transform.Scale(1, scale)

	beam_transform.Turn(90) // the icon is vertical, so we reorient it to x-axis alignment
	beam_transform.Turn(turn_angle)

	beam_transform.Translate(0.5 * x_translate * world.icon_size, 0.5 * y_translate * world.icon_size)

	src.x = source.x
	src.y = source.y
	src.transform = beam_transform


/obj/vectorbeam/proc/PostNewHook()
	return


/obj/vectorbeam/New(var/atom/new_source = null, var/new_scale = null, var/new_dist = null, var/new_angle = null)
	..()

	source = (isnull(new_source) ? loc : new_source)
	src.UpdateVector(new_source, new_scale, new_dist, new_angle)
	name = "Beam @ [source]"

	src.PostNewHook()


/obj/vectorbeam/verb/Delete()
	set src in view()
	del(src)


/mob/verb/DeleteBeams()
	for(var/obj/vectorbeam/VB in view())
		del(VB)


/obj/vectorbeam/vanishing/PostNewHook()
	. = ..()

	spawn(20)
		del(src)


/atom/proc/pDrawVectorbeam(var/atom/start)
	var/dist = EuclidDistance(start, src)

	var/dx = (src.x - start.x)
	var/dy = (src.y - start.y)
	var/angle = arctan(dx, dy)

	var/Vector2d/vec_length = dist

	var/obj/vectorbeam/vanishing/new_beam = new(get_turf(start), vec_length, vec_length, angle)
	return new_beam


/atom/verb/DrawVectorbeam()
	set src in view()
	var/obj/vectorbeam/vanishing/new_beam = src.pDrawVectorbeam(usr)
	usr << "Spawned new beam [new_beam]"
