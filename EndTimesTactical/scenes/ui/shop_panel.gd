extends PanelContainer

@onready var _title_lbl:  Label         = $VBox/TitleRow/TitleLabel
@onready var _caps_lbl:   Label         = $VBox/TitleRow/CapsLabel
@onready var _close_btn:  Button        = $VBox/TitleRow/CloseBtn
@onready var _buy_vbox:   VBoxContainer = $VBox/ColumnsRow/BuyColumn/BuyScroll/BuyVBox
@onready var _sell_col:   VBoxContainer = $VBox/ColumnsRow/SellColumn
@onready var _sell_vbox:  VBoxContainer = $VBox/ColumnsRow/SellColumn/SellScroll/SellVBox

var _vendor_sells: Array  = []
var _markup: float        = 1.0
var _buys: bool           = true


func init(vendor_name: String, vendor_data: Dictionary) -> void:
	_vendor_sells = vendor_data.get("sells", [])
	_markup       = float(vendor_data.get("markup", 1.0))
	_buys         = vendor_data.get("buys", true)
	_title_lbl.text = "TRADE — %s" % vendor_name
	_sell_col.visible = _buys
	_refresh()


func _ready() -> void:
	_close_btn.pressed.connect(queue_free)


func _refresh() -> void:
	_caps_lbl.text = "Caps: %d" % GameState.caps

	# ── Buy column ──────────────────────────────────────────────────────────
	for child in _buy_vbox.get_children():
		child.queue_free()

	for item_id: String in _vendor_sells:
		var item := DataManager.get_item(item_id)
		if item.is_empty():
			continue
		var price: int = maxi(1, int(item.get("value", 0) * _markup))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(IconMapper.make_item_icon(item_id, item.get("type", "")))

		var lbl := Label.new()
		lbl.text = item.get("name", item_id)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(lbl)

		var price_lbl := Label.new()
		price_lbl.text = "%dc" % price
		price_lbl.add_theme_font_size_override("font_size", 18)
		price_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		row.add_child(price_lbl)

		var buy_btn := Button.new()
		buy_btn.text = "BUY"
		buy_btn.custom_minimum_size = Vector2(60, 30)
		buy_btn.disabled = GameState.caps < price
		buy_btn.pressed.connect(_on_buy.bind(item_id, price))
		row.add_child(buy_btn)

		_buy_vbox.add_child(row)

	# ── Sell column ─────────────────────────────────────────────────────────
	if not _buys:
		return

	for child in _sell_vbox.get_children():
		child.queue_free()

	for entry in GameState.inventory:
		if entry.get("equipped", false):
			continue
		var item := DataManager.get_item(entry.get("item_id", ""))
		if item.is_empty() or item.get("value", 0) <= 0:
			continue
		var sell_price: int = maxi(1, int(item.get("value", 0) * 0.5))
		var qty: int = entry.get("quantity", 1)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(IconMapper.make_item_icon(entry.get("item_id", ""), item.get("type", "")))

		var lbl := Label.new()
		lbl.text = "%s  ×%d" % [item.get("name", "?"), qty]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(lbl)

		var price_lbl := Label.new()
		price_lbl.text = "%dc" % sell_price
		price_lbl.add_theme_font_size_override("font_size", 18)
		price_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		row.add_child(price_lbl)

		var sell_btn := Button.new()
		sell_btn.text = "SELL"
		sell_btn.custom_minimum_size = Vector2(60, 30)
		sell_btn.pressed.connect(_on_sell.bind(entry.get("item_id", ""), sell_price))
		row.add_child(sell_btn)

		_sell_vbox.add_child(row)


func _on_buy(item_id: String, price: int) -> void:
	if GameState.caps < price:
		return
	GameState.caps -= price
	GameState.add_item(item_id, 1)
	_refresh()


func _on_sell(item_id: String, sell_price: int) -> void:
	if not GameState.has_item(item_id):
		return
	GameState.remove_item(item_id, 1)
	GameState.caps += sell_price
	_refresh()
