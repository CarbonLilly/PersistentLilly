SUBSYSTEM_DEF(character_setup)
	name = "Character Setup"
	init_order = SS_INIT_CHAR_SETUP
	priority = SS_PRIORITY_CHAR_SETUP
	flags = SS_BACKGROUND
	wait = 1 SECOND
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT

	var/list/prefs_awaiting_setup = list()
	var/list/preferences_datums = list()
	var/list/newplayers_requiring_init = list()

	var/list/save_queue = list()

/datum/controller/subsystem/character_setup/Initialize()
	while(prefs_awaiting_setup.len)
		var/datum/preferences/prefs = prefs_awaiting_setup[prefs_awaiting_setup.len]
		prefs_awaiting_setup.len--
		prefs.setup()
	while(newplayers_requiring_init.len)
		var/mob/new_player/new_player = newplayers_requiring_init[newplayers_requiring_init.len]
		newplayers_requiring_init.len--
		new_player.deferred_login()
	. = ..()

/datum/controller/subsystem/character_setup/fire(resumed = FALSE)
	while(save_queue.len)
		var/datum/preferences/prefs = save_queue[save_queue.len]
		save_queue.len--

		if(!QDELETED(prefs))
			prefs.save_preferences()

		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/character_setup/proc/queue_preferences_save(var/datum/preferences/prefs)
	save_queue |= prefs

/datum/controller/subsystem/character_setup/proc/save_character(var/ind, var/ckey, var/mob/living/carbon/human/H)
	if(!istype(H))
		return
	var/savefile/S = CHAR_SAVE_FILE(ind, ckey)
	H.before_save()
	to_file(S["name"], H.real_name)
	to_file(S["mob"], H)
	H.after_save()

/datum/controller/subsystem/character_setup/proc/delete_character(var/ind, var/ckey)
	fdel(CHAR_SAVE_FILE_PATH(ind, ckey))

/datum/controller/subsystem/character_setup/proc/load_character(var/ind, var/ckey)
	if(!fexists(CHAR_SAVE_FILE_PATH(ind, ckey)))
		return
	var/savefile/F = CHAR_SAVE_FILE(ind, ckey)
	var/mob/M
	from_file(F["mob"], M)
	M.after_spawn() //Runs after_load
	return M

/datum/controller/subsystem/character_setup/proc/load_import_character(var/ind, var/ckey)
	if(!fexists(beta_path(ckey, "[ind].sav")))
		return
	var/savefile/F =  new (beta_path(ckey, "[ind].sav"))
	var/mob/M
	from_file(F["mob"], M)
	M.after_spawn() //Runs after_load
	return M


/datum/controller/subsystem/character_setup/proc/peek_import_name(var/ind, var/ckey)
	if(!fexists(beta_path(ckey, "[ind].sav")))
		return
	else
		message_admins("import found!")
	var/savefile/F =  new (beta_path(ckey, "[ind].sav"))
	var/name
	from_file(F["name"], name)
	return name

/datum/controller/subsystem/character_setup/proc/peek_import_icon(var/ind, var/ckey)
	var/mob/M = src.load_import_character(ind, ckey)
	if(!M)
		return
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		H.force_update_limbs()
		H.update_eyes()
	character.dna.ready_dna(character)
	character.sync_organ_dna()
	M.regenerate_icons()
	M.update_icon()
	character.regenerate_icons()
	var/icon/I = get_preview_icon(M)
	QDEL_IN(M, 1 SECONDS)
	return I


/datum/controller/subsystem/character_setup/proc/peek_character_name(var/ind, var/ckey)
	if(!fexists(CHAR_SAVE_FILE_PATH(ind, ckey)))
		return
	var/savefile/F = CHAR_SAVE_FILE(ind, ckey)
	var/name
	from_file(F["name"], name)
	return name

/datum/controller/subsystem/character_setup/proc/peek_character_icon(var/ind, var/ckey)
	var/mob/M = src.load_character(ind, ckey)
	if(!M)
		return
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		H.force_update_limbs()
		H.update_eyes()
	M.regenerate_icons()
	M.update_icon()
	var/icon/I = get_preview_icon(M)
	QDEL_IN(M, 1 SECONDS)
	return I

//Used for when we're trying to find a free character slot to save a character without a slot
/datum/controller/subsystem/character_setup/proc/find_character_save_slot(var/mob/living/carbon/human/H, var/ckey)
	var/saveslot = 0
	log_and_message_admins("Warning! [ckey]'s [H] failed to find a save_slot, and is picking one!")
	for(var/file in flist(load_path(ckey, "")))
		var/firstNumber = text2num(copytext(file, 1, 2))
		if(firstNumber)
			var/storedName = SScharacter_setup.peek_character_name(firstNumber, ckey)
			if(storedName == name)
				saveslot = firstNumber
				log_and_message_admins("[ckey]'s [H] found a savefile with it's realname [file]")
				break
	if(!saveslot)
		saveslot++
		while(fexists(load_path(ckey, "[saveslot].sav")))
			saveslot++
	return saveslot
