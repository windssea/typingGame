extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func make_run(mode := "dojo", index := 0) -> GameRun:
	var game := GameRun.new()
	game.setup(mode, GameContent.lessons()[index], 1.0, 42)
	return game

func complete_target(game: GameRun, target: Dictionary) -> void:
	for character in str(target.word).substr(target.typed):
		game.type_character(character)

func _initialize() -> void:
	run_tests.call_deferred()

func run_tests() -> void:
	var lessons := GameContent.lessons()
	check(lessons.size() == 10, "ten curricula")
	var ids := {}
	for lesson in lessons:
		check(not ids.has(lesson.id), "unique lesson id")
		ids[lesson.id] = true
		for word in lesson.words:
			check(not word.is_empty(), "nonempty word")
			for character in word:
				check(character in lesson.keys, "word uses only taught keys: " + lesson.id + "/" + word)
	var game := make_run()
	check(game.targets.size() == 1, "dojo begins with one target")
	game.type_character("x")
	check(game.attempts == 1 and game.correct == 0 and game.hp == 100, "wrong key counted without beginner damage")
	for i in range(18):
		complete_target(game,game.targets[0])
	check(game.done and game.won and game.kills == 18, "dojo completion")
	check(is_equal_approx(game.accuracy(),18.0/19.0), "accuracy calculation")
	var before := game.attempts
	game.type_character("f")
	check(game.attempts == before, "finished game ignores input")
	game = make_run("dojo",6)
	var word: String = game.targets[0].word
	game.type_character(word[0])
	game.type_character(word[1])
	game.backspace()
	check(game.correct == 1 and game.targets[0].typed == 1, "backspace retracts effective character")
	game.cancel_target()
	check(game.correct == 0 and game.locked == -1 and game.targets[0].typed == 0, "cancel cannot inflate WPM")
	game.paused = true
	game.step(10)
	game.type_character(word[0])
	check(game.elapsed == 0 and game.correct == 0, "pause freezes time and typing")
	game = make_run("dojo",8)
	word = game.targets[0].word
	game.type_character(word[0].to_lower())
	check(game.correct == 0, "uppercase is exact")
	game = make_run("rain")
	game.elapsed = 89.9
	game.step(0.2)
	check(game.done and game.won, "rain survives ninety seconds")
	game = make_run("rain")
	for i in range(5):
		game.spawn_target()
		game.targets[-1].position.y = 580
	game.step(0.01)
	check(game.done and not game.won, "five missed rain targets end run")
	game = make_run("dojo",9)
	word = game.targets[0].word
	complete_target(game, game.targets[0])
	check(game.correct == word.length() and game.kills == 1, "spaces and punctuation accepted")
	game = make_run("bubbles",0)
	check(game.targets.size()==4,"bubble mode offers multiple choices")
	for i in range(18):
		var selected := game.target_by_id(game.locked)
		complete_target(game,game.targets[0] if selected.is_empty() else selected)
		for a in game.targets:
			for b in game.targets:
				check(a.id==b.id or a.position!=b.position,"bubbles never occupy the same slot")
	check(game.done and game.won and game.kills==18,"bubble completion at eighteen targets")
	game = make_run("sprint",6)
	complete_target(game,game.targets[0])
	check(game.kills==1 and game.targets.size()==1,"sprint advances to next target")
	game.step(59.9)
	check(not game.done,"sprint does not end early")
	game.step(0.2)
	check(game.done and game.won,"sprint ends after sixty seconds")
	var seeded_a := make_run("dojo",6)
	var seeded_b := make_run("dojo",6)
	check(seeded_a.targets[0].word == seeded_b.targets[0].word, "seeded content is reproducible")

	var store := ProfileStore.new()
	store.path = "user://test-profile-%d.json" % Time.get_ticks_usec()
	store.data.xp = 10
	check(store.save_profile(), "first save succeeds")
	store.data.xp = 20
	check(store.save_profile(), "second save succeeds")
	var reload := ProfileStore.new()
	reload.path = store.path
	reload.load_profile()
	check(reload.data.xp == 20, "profile round trip")
	var corrupt := FileAccess.open(store.path,FileAccess.WRITE)
	corrupt.store_string("broken")
	corrupt.close()
	reload = ProfileStore.new()
	reload.path = store.path
	reload.load_profile()
	check(reload.data.xp == 10, "corrupt primary recovers backup")
	check(not reload.import_text("{}") and reload.data.xp == 10, "invalid import leaves profile intact")
	var invalid := ProfileStore.fresh()
	invalid.version = 999
	check(not reload.import_text(JSON.stringify(invalid)), "future schema rejected")
	invalid = ProfileStore.fresh()
	invalid.records = {"bad":{"score":"oops"}}
	check(not reload.import_text(JSON.stringify(invalid)), "malformed nested stats rejected")
	invalid = ProfileStore.fresh()
	invalid.settings.sound = "wrong"
	check(not reload.import_text(JSON.stringify(invalid)),"malformed sound setting rejected")
	var imported := ProfileStore.fresh()
	imported.xp = 42
	check(reload.import_text(JSON.stringify(imported)) and reload.data.xp == 42, "valid import")
	game = make_run()
	for i in range(18):
		complete_target(game,game.targets[0])
	reload.record_run(game,0)
	check(reload.data.completed.has("home_index") and reload.data.xp == 132, "completion and XP persistence")
	game = make_run("dojo",1)
	game.context="challenge"
	for i in range(18):
		complete_target(game,game.targets[0])
	reload.record_run(game,1)
	check(not reload.data.completed.has("home_core"),"challenge does not mark training mastery")
	check(reload.data.records.has("challenge:dojo:home_core"),"challenge scores use separate namespace")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(store.path + suffix):
			DirAccess.remove_absolute(store.path + suffix)
	print("TEST RESULTS: %d checks; %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
