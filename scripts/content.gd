class_name GameContent
extends RefCounted

static func lessons() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/curriculum.json"))
	return parsed.lessons

static func modes() -> Array:
	return [
		{"id":"dojo", "name":"星火练习场", "tag":"LEARN / 无压力", "description":"从 F 和 J 开始。\n看见按键，建立肌肉记忆。", "goal":"完成 18 个目标 · 无失败惩罚"},
		{"id":"bubbles", "name":"字母泡泡", "tag":"PLAY / 自由找键", "description":"挑选一个泡泡，\n用正确输入把它点亮。", "goal":"自由选择目标 · 无时间压力"},
		{"id":"rain", "name":"字母陨落", "tag":"REACT / 反应训练", "description":"在符文落地前输入。\n把准确变成稳定的节奏。", "goal":"守住 90 秒 · 5 次失误机会"},
		{"id":"sprint", "name":"一分钟冲刺", "tag":"SPRINT / 速度挑战", "description":"专注下一个目标，\n在一分钟内突破自己。", "goal":"60 秒连续输入 · 比拼准确与速度"},
		{"id":"castle", "name":"守护键之城", "tag":"DEFEND / 塔防战役", "description":"建造元素塔，强化魔法，\n迎战六波军团与统领。", "goal":"六波战役 · 三种塔 · 两场 Boss"},
		{"id":"balloons", "name":"气球猎手", "tag":"POP / 找键与反应", "description":"输入字母击破上升气球，\n让天空绽放彩色碎片。", "goal":"优先处理高处目标 · 练习找键"},
		{"id":"aliens", "name":"外星攻防战", "tag":"SPACE / 输入与防御", "description":"激光迎击俯冲外星舰，\n三连击恢复基地护盾。", "goal":"护盾与船体 · 连击补给"},
		{"id":"moles", "name":"打字打地鼠", "tag":"WHACK / 定位与切换", "description":"地鼠从六个洞口探头，\n看准举牌文字，敲中它！", "goal":"训练漏掉不扣血 · 准确定位"},
		{"id":"racing", "name":"键盘拉力赛", "tag":"RACE / 稳定与速度", "description":"输入推进赛车，连击加速。\n挑战时抢在对手前冲线。", "goal":"训练自由完赛 · 挑战竞速"},
		{"id":"fighter", "name":"指尖格斗馆", "tag":"FIGHT / 连击与反应", "description":"完成输入挥出重拳，\n打断对手蓄力，连击制胜。", "goal":"四次命中击倒对手 · 攻击打断"}
	]
