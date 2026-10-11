extends SceneTree

func _initialize() -> void:
	var path: String = "res://scenes/book_menu/book_selection.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	text = text.replace("    BookSession.selected_book_id", "\tBookSession.selected_book_id")
	text = text.replace("    # Book IDs", "\t# Book IDs")
	text = text.replace("    Global.current_book", "\tGlobal.current_book")
	text = text.replace("    Global.current_lesson", "\tGlobal.current_lesson")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	quit()
