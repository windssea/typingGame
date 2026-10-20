class_name EnemyTactics
extends RefCounted

# Decisions only. Models own movement, damage and rewards; views read these intents.
static func enter(agent: Dictionary, intent: String, seconds := 0.0) -> void:
	agent.intent = intent
	agent.intent_left = seconds
	agent.intent_duration = seconds

static func warning_window(word: String, duration: float) -> float:
	return minf(duration * .6, maxf(duration * .4, 2.5 + word.length() * .35))

static func arcade(agent: Dictionary, mode: String, dt: float) -> void:
	var window := warning_window(agent.word, agent.duration)
	match str(agent.intent):
		"exposed":
			agent.intent_left = maxf(0, agent.intent_left - dt)
			if agent.intent_left <= 0: enter(agent, "ready")
		"ready", "cruise":
			if agent.remaining <= window and agent.get("feature", "") != "supply":
				enter(agent, "windup", window)
		"windup":
			agent.intent_left = maxf(0, agent.remaining)
			if mode == "aliens" and agent.remaining <= window * .5:
				enter(agent, "dive", window * .5)
		"dive":
			agent.intent_left = maxf(0, agent.remaining)

static func wounded_ally(agent: Dictionary, agents: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var ratio := 1.0
	for other in agents:
		if other.id == agent.id or other.position.distance_to(agent.position) > 300: continue
		var health_ratio: float = float(other.health) / other.max_health
		if health_ratio < ratio:
			ratio = health_ratio
			best = other
	return best

static func castle(agent: Dictionary, agents: Array[Dictionary], keep: Vector2, dt: float, window: float) -> String:
	agent.aim = keep
	agent.pace = 1.0
	match str(agent.intent):
		"recover":
			agent.pace = .25
			agent.intent_left -= dt
			if agent.intent_left <= 0: enter(agent, "march")
		"flank":
			agent.aim = agent.waypoint
			if agent.position.distance_to(agent.waypoint) < 12:
				enter(agent, "rush")
		"rush":
			agent.pace = 1.1
		"casting", "arming":
			if agent.intent=="casting":
				var recipient := agents.filter(func(a): return a.id==agent.ally and a.health<a.max_health and a.position.distance_to(agent.position)<190)
				if recipient.is_empty():
					agent.timer = 2.0
					enter(agent,"march")
					return ""
			agent.pace = 0.0
			agent.intent_left -= dt
			if agent.intent_left <= 0:
				var action: String = agent.intent
				enter(agent, "march")
				return action
		"march", "escort":
			if agent.kind == "bomber" and agent.position.distance_to(keep) < 165:
				enter(agent, "arming", window)
				agent.pace = 0.0
			elif agent.kind == "shaman":
				agent.timer = maxf(0, agent.timer - dt)
				var ally := wounded_ally(agent, agents)
				if not ally.is_empty():
					agent.aim = ally.position + (ally.position - keep).normalized() * 70
					if agent.intent != "escort": enter(agent, "escort")
					if agent.timer <= 0 and agent.position.distance_to(ally.position) < 170:
						agent.ally = ally.id
						enter(agent, "casting", window)
						agent.pace = 0.0
				elif agent.intent == "escort": enter(agent, "march")
	return ""

static func caption(agent: Dictionary) -> String:
	return {"windup":"蓄力 · 输入打断", "dive":"俯冲 · 优先击落", "exposed":"破绽 · 双倍重拳",
		"casting":"治疗 · 输入打断", "arming":"引爆 · 输入拆弹", "recover":"已打断", "flank":"侧翼包抄", "rush":"冲锋"}.get(agent.get("intent", ""), "")
