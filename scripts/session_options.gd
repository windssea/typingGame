class_name SessionOptions
extends RefCounted

const SPEEDS := [0.65,0.85,1.0,1.3,1.6]
const SPEED_NAMES := ["慢慢来  0.65×","轻松练  0.85×","标准  1.0×","加速  1.3×","飞快  1.6×"]
const RANK_IDS := ["normal","hard","expert"]
const RANK_NAMES := ["进阶","高手","大师"]
const RANK_SPEEDS := [1.0,1.35,1.75]
const RANK_HINTS := ["标准挑战 · 保持准确，追求连击","更快目标 · 更长赛程 · 容错减少","高速进攻 · 强化敌军 · 极限反应"]

static func record_suffix(context: String, speed: float, rank: String) -> String:
	if context=="challenge":
		return "" if rank=="normal" else ":"+rank
	return "" if is_equal_approx(speed,1.0) else ":speed_%d" % roundi(speed*100)

static func rank_index(rank: String) -> int:
	return maxi(0,RANK_IDS.find(rank))
