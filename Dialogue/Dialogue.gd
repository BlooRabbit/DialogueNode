tool

extends Node2D

# Stand-alone node for the display of dialogues based on json files made with Levrault's dialogue editor
# Editor can be found here:  https://github.com/Levrault/LE-dialogue-editor
# Use it to make and file your json file in the Dialogue folder
# Load .json by triggering load(path), where path is the name without extension in a folder called Dialogue
# Then start dialogue with start() from your game script(s)
# To use a timed dialogue box (which closes automatically), use the signal dialogue_timer(seconds)

export (int) var width = 600
export (int) var height = 300
export (String) var dialoguetext = "This is standard text."
export (String) var npc_name = "NAME"
export (String) var dialog_key = "DIALOGUE_PLACEHOLDER"
export (bool) var has_input := false

var _portraits_res := {}
var _dialogues := {}
var _conditions := {}
var _current_dialogue := {}

enum States { pending, questionning }

var _message : String = ''
var _is_last_dialogue : bool= false
var _has_next_button : bool = false
var _has_timer : bool = false
var _state: int = States.pending

#  change the below to allocate the various panels (which you can easily customize)
onready var _text = $Panel/VBox/Message # message
onready var _name = $Panel/VBox/Namelabel # npc name
onready var _portrait = $Panel/VBox/Photo # npc picture
onready var _choices_panel = $Panel/VBox/Choices # panel for choices
onready var _next = $Panel/VBox/MarginContainer/Next # next button
onready var _end = $Panel/VBox/MarginContainer/End # end of dialogue button
onready var _timer = $Timer # timer for timed messages

# initial dialogue file is based on NPC name - can be changed easily
onready var dialogue_json : Dictionary = get_json("Dialogue/"+npc_name+".json")

signal dialogue_started
signal dialogue_changed(name, portrait, message)
signal dialogue_text_displayed
signal dialogue_last_text_displayed
signal dialogue_finished
signal dialogue_last_dialogue_displayed
signal dialogue_animation_skipped
signal dialogue_choices_changed(choices)
signal dialogue_choices_displayed
signal dialogue_choices_finished(choices)
signal dialogue_choices_pressed
signal dialogue_timer(seconds)

# --------------------------

func _ready():
	# change this to adjust panel size 
	$Panel.rect_size.x = width
	$Panel.rect_size.y = height
	# to do : position of control (self.position) can be set easily
	# to do : animate panel popping up 

	_load_portrait_in_memory()
	
	connect("dialogue_started", self, "_on_Dialogue_started")
	connect("dialogue_changed", self, "_on_Dialogue_changed")
	connect("dialogue_finished", self, "_on_Dialogue_finished")
	connect("dialogue_last_dialogue_displayed", self, "_on_Last_dialogue")
	connect("dialogue_choices_changed", self, "_on_Choice_changed")
	connect("dialogue_choices_finished", self, "_on_Choices_finished")
	connect("dialogue_text_displayed", self,"_on_dialogue_displayed")

	_next.visible=false
	_end.visible=false
	_choices_panel.visible=false
	
#--------------------------------------------------------------------
	# the below is only for testing purposes
	# load and start functions should rather be triggered by game scripts
	loaddialogue("Intro") # required to load the correct json file
	start()  # starts the dialogue
#--------------------------------------------------------------------

# -------------------------------------------------------
# Output Dialogue functions
# Change the below to change the way things are displayed
# -------------------------------------------------------

# show dialogue box
func _on_Dialogue_started() -> void:
	visible = true

func next_action() -> void:

#	this is what happens when there is a choice to be made
	if _state == States.questionning:
		_choices_panel.visible = true
		_choices_panel.get_child(0).grab_focus()
		emit_signal("dialogue_choices_displayed")
		return

#	this is what happens when the last dialogue box is displayed
	if _is_last_dialogue and _state == States.pending:
		emit_signal("dialogue_last_text_displayed")
		return

#	this is what happens when there is a next dialogue but no choices
	emit_signal("dialogue_text_displayed")

#	this is to display the dialogue text
func _on_Dialogue_changed(name: String, portrait: StreamTexture, message: String) -> void:
	_message = message
	_name.text = name
	_portrait.texture = portrait
	_text.parse_bbcode(message)

	# make letters appear progressively
	var textsize=message.length()
	$Tween.interpolate_property(_text,"visible_characters",0,textsize,textsize*0.02,Tween.TRANS_LINEAR,Tween.EASE_IN_OUT)
	$Tween.start()
	yield($Tween,"tween_completed")
	
	# add "next" or "end" button unless it is a timed dialogue box
	if not _has_timer :
		if _is_last_dialogue: _end.visible=true
		if _has_next_button: _next.visible=true

# Add and display player's optional choices
func _on_Choice_changed(choices: Array) -> void:
	_state = States.questionning
	_choices_panel.visible=true
	for choice in choices:
		# the below is based on creating buttons but other stuff is possible
		var button: Button = Button.new()
		button.text = choice["text"][TranslationServer.get_locale()]
		button.connect("pressed", self, "_on_Choice_pressed", [choice["next"]])
		_choices_panel.add_child(button)

func _on_Choice_pressed(next: String) -> void:
	for choice in _choices_panel.get_children():
		choice.queue_free()
	_state = States.pending
	_choices_panel.hide()
	emit_signal("dialogue_choices_finished", next)
	emit_signal("dialogue_choices_pressed")

# Reset dialogue when finished
func _on_Dialogue_finished() -> void:
	hide()
	_timer.stop()
	_next.visible=false
	_end.visible=false
	_choices_panel.visible=false
	_is_last_dialogue = false
	_has_next_button = false
	_has_timer = false
	# you could also queue_free() the dialogue box, depending on your game system

# Last dialogue box has been displayed
func _on_Last_dialogue() -> void:
	_is_last_dialogue = true
	# you can add here whatever happens after a final dialogue box

# end button is pressed
func _on_End_pressed():
	_on_Dialogue_finished()

# next button pressed
func _on_Next_pressed():
	next()
	_has_next_button=false
	_next.visible=false

# timed dialogue box (signal "dialogue_timer" and the waiting time value)
func dialogue_timer(seconds:int):
	_has_timer = true
	yield(get_tree().create_timer(seconds),"timeout")
	_on_Timeout()

# Triggered by the timer node when time is out
func _on_Timeout() -> void:
	_on_Dialogue_finished()

# ----------------------------------------
# Back-office dialogue functions
# These should run pretty much plug & play
# ----------------------------------------

# Load dialogue
func loaddialogue(path) -> void: # path is the name of the file without extension
	dialogue_json = get_json("Dialogue/"+path+".json")

# starts the dialogue
func start() -> void:
	emit_signal("dialogue_started")
	_current_dialogue = get_next(dialogue_json.root)
	change()

# Send dialogue based on language
func next() -> void:
	_current_dialogue = get_next(_current_dialogue)
	change()

# show next interactions
func change() -> void:
	var text: String = _current_dialogue["text"][TranslationServer.get_locale()]
	emit_signal(
		"dialogue_changed",
		_current_dialogue["name"],
		_portraits_res[_current_dialogue["portrait"]],
		text
	)

	# dialog triggers a signal
	if _current_dialogue.has("signals"):
		_emit_dialogue_signal(_current_dialogue["signals"])

	# player can make some choice
	if _current_dialogue.has("choices"):
		var conditions: Array = (
			_current_dialogue.get("conditions")
			if _current_dialogue.has("conditions")
			else []
		)
		emit_signal("dialogue_choices_changed", get_choices(_current_dialogue.choices, conditions))
		return

	# there is no linked dialogue and no choice
	if not _current_dialogue.has("conditions") and not _current_dialogue.get("next"):
		emit_signal("dialogue_last_dialogue_displayed")
		clear()
	
	# in other cases: display a next button if there is a next node 
	if _current_dialogue.has("next"): 
		_has_next_button=true

# clear dialogue
func clear() -> void:
	_dialogues = {}
	_current_dialogue = {}
	_conditions = {}

func get_next(node: Dictionary) -> Dictionary:
	if node.has("next"):
		return dialogue_json[node.next]

	var next := ""
	var default_next := ""
	if node.has("conditions"):
		var conditions = node.conditions.duplicate(true)
		var matching_condition := 0

		for condition in conditions:
			var predicated_next: String = condition.next
			condition.erase("next")

			if condition.empty():
				default_next = predicated_next

			# partial matching
			var current_matching_condition := 0
			for key in condition:
				if _conditions.has(key):
					# conditions will never match
					if _conditions.size() < condition.size():
						continue

					if condition.empty():
						default_next = predicated_next

					if _check_conditions(condition, key):
						current_matching_condition += 1

			if current_matching_condition > matching_condition:
				matching_condition = current_matching_condition
				next = predicated_next

	if not next.empty():
		return dialogue_json[next]

	assert(default_next.empty() == false)
	return dialogue_json[default_next]

func get_choices(choices: Array, conditions: Array = []) -> Array:
	if conditions.empty():
		return choices

	var result := []
	var conditional_choices := {}

	for choice in choices:
		if choice.has("uuid"):
			conditional_choices[choice.uuid] = choice
		else:
			result.append(choice)

	if conditional_choices.empty():
		return choices

	var matching_condition := 0
	for condition in conditions:
		var current_matching_condition := 0
		for key in condition:
			var predicated_next: String = condition.next
			condition.erase("next")

			if _conditions.has(key):
				# conditions will never match
				if _conditions.size() < condition.size():
					continue

				if condition.empty():
					result.append(conditional_choices[predicated_next])

				if _check_conditions(condition, key):
					current_matching_condition += 1

			if current_matching_condition > matching_condition:
				result.append(conditional_choices[predicated_next])

	# dialogue json file was badly configuarated since it doesn't have a default choice
	assert(not result.empty())
	return result


# Valid conditions
# (Not sure this works)
# @returns {bool}
func _check_conditions(condition: Dictionary, key: String) -> bool:
	match condition[key].operator:
		"lower":
			return condition[key].value > _conditions[key]
		"greater":
			return condition[key].value < _conditions[key]
		"different":
			return condition[key].value != _conditions[key]
		_:
			return condition[key].value == _conditions[key]


# Check all dialogue portraits and set them in memory
func _load_portrait_in_memory() -> void:
	for key in dialogue_json:
		var values: Dictionary = dialogue_json[key]
		if (
			not values.has("portrait")
			or values.portrait.empty()
			or _portraits_res.has(values.portrait)
		):
			continue # to do: replace with standard image if there is no ref in the json
		_portraits_res[values.portrait] = load(values.portrait)

# Function used for signals
func _convert_value_to_type(type: String, value):
	match type:
		"Vector2":
			return Vector2(value["x"], value["y"])
		"Number":
			if "." in type: return float(value)
			else: return int(value)
	return value

func _on_Choices_finished(key: String) -> void:
	disconnect("dialogue_choices_finished", self, "_on_Choices_finished")
	# get choice
	_current_dialogue = dialogue_json[key]
	change()

# Emit signals - this requires that the signals are "declared" somewhere ("signal string(value)")
# For example timed dialog works with a signal called "dialogue_timer" 
func _emit_dialogue_signal(signals: Dictionary) -> void:
	for key in signals:
		if not signals[key] is Dictionary:
			if signals[key] == null:
				connect(key, self, key)
				emit_signal(key)
				continue
			connect(key, self, key)
			emit_signal(key, signals[key])
			continue

		var multi_values_signal: Dictionary = signals[key]
		for type in multi_values_signal:
			var value = _convert_value_to_type(type, multi_values_signal[type])
			connect(key, self, key)
			emit_signal(key, value)


# --------------------------
# Read and parse Json file
# --------------------------

func get_json(file_path: String) -> Dictionary:
	var file := File.new()

	if file.open(file_path, file.READ) != OK:
		print("get_json: file cannot been read")
		return {}

	var text_content := file.get_as_text()
	file.close()
	var data_parse = JSON.parse(text_content)
	if data_parse.error != OK:
		print("get_json: error while parsing")
		return {}
		
	data_parse.result.erase("__editor")
	return data_parse.result
