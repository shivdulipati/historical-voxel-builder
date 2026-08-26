extends Node3D

func _ready() -> void:
	var blob: Node3D = load("res://art/blob_poc.gd").new()
	add_child(blob)
	blob.build("mastaba")
	print("MASTABA BUILD OK, children: ", blob.get_child_count())
	for b in blob.get_children():
		if b.get_child_count() == 0:
			print("EMPTY INSTANCE: ", b.name)
	get_tree().quit(0)
