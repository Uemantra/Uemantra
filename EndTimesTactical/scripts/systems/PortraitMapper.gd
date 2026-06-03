class_name PortraitMapper
# Resolves NPC portrait textures. Checks the portrait path defined in each NPC's JSON file
# (e.g. res://art/portraits/ava_chen.png) and returns it if the file exists.
# Returns null when no portrait is found, leaving the text placeholder visible.


static func get_portrait(_npc_id: String, npc_data: Dictionary) -> Texture2D:
	var portrait_path: String = npc_data.get("portrait", "")
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		return load(portrait_path) as Texture2D
	return null
