extends Control

signal menu_closed

@onready var overlay: ColorRect = $Overlay
@onready var menu_panel: PanelContainer = $MenuPanel
@onready var close_button: Button = $MenuPanel/MarginContainer/VBoxContainer/Header/CloseButton
@onready var total_words_label: Label = $MenuPanel/MarginContainer/VBoxContainer/TotalWordsLabel
@onready var word_list: VBoxContainer = $MenuPanel/MarginContainer/VBoxContainer/ScrollContainer/WordList
@onready var hamburger_button: Button = $"../HeaderBar/MarginContainer/Header/OpenListMenuButton"

# متغیری برای ذخیره انیمیشن فعلی تا تداخلی پیش نیاید
var tween: Tween

func _ready() -> void:
	close_button.pressed.connect(close_menu)
	hamburger_button.pressed.connect(open_menu)
	overlay.gui_input.connect(_on_overlay_gui_input)
	
	# در ابتدا، اوورلی شفاف باشد، منو مخفی، و هامبورگر فعال
	overlay.modulate.a = 0.0
	visible = false
	menu_panel.position.x = -menu_panel.size.x  # پنل خارج از صفحه در چپ شروع می‌شود

func open_menu() -> void:
	visible = true
	_populate_list()
	
	# اگر انیمیشن قبلی در حال اجراست، آن را متوقف کن
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween().set_parallel(true)
	
	# ۱. تاریک شدن پس‌زمینه (Overlay)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	
	# ۲. منو از خارج صفحه (چپ) وارد شود
	tween.tween_property(menu_panel, "position:x", 0, 0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func close_menu() -> void:
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween().set_parallel(true)
	
	# ۱. شفاف شدن پس‌زمینه
	tween.tween_property(overlay, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	
	# ۲. خروج پنل به سمت خارج صفحه (چپ)
	tween.tween_property(menu_panel, "position:x", -menu_panel.size.x, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	
	# وقتی انیمیشن بسته شدن تمام شد، کل کنترل را مخفی کن
	tween.chain().tween_callback(func(): 
		visible = false
		menu_closed.emit()
	)

func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_menu()
		
# ==========================================
# بقیه متدهای شما (بدون تغییر باقی می‌مانند)
# ==========================================
func _populate_list() -> void:
	for child in word_list.get_children():
		child.queue_free()
		
	var review_words: Array = Global.get_review_words()
	_update_total_count(review_words.size())
	
	for entry in review_words:
		_create_word_item(entry)

func _create_word_item(entry: Dictionary) -> void:
	var item_box = HBoxContainer.new()
	item_box.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var word_label = Label.new()
	word_label.text = entry.get("word", "Unknown")
	word_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL 
	
	var delete_btn = Button.new()
	delete_btn.text = "حذف"
	delete_btn.modulate = Color("#EF4444") 
	
	delete_btn.pressed.connect(func(): _on_delete_word_pressed(entry, item_box))
	
	item_box.add_child(word_label)
	item_box.add_child(delete_btn)
	
	word_list.add_child(item_box)

func _on_delete_word_pressed(entry: Dictionary, item_node: Node) -> void:
	var word: String = entry.get("word", "")
	var book: int = entry.get("book", 0)
	var lesson: int = entry.get("lesson", 0)
	
	Global.remove_review_word(word, book, lesson)
	item_node.queue_free()
	
	var new_count = Global.get_review_words().size()
	_update_total_count(new_count)

func _update_total_count(count: int) -> void:
	total_words_label.text = "تعداد کل کلمات در مرور: %d" % count
