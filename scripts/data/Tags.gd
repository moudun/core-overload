class_name Tags
## Tags.gd —— V1.3 构筑标签系统。
## 武器 / 协议 / 过载卡都携带标签；同类标签累计到 2 / 4 / 6 层触发套装阈值。
## 标签只描述「这套构筑想做什么」，具体生效公式集中在 GameState.tag_bonus_*。

const OVERCLOCK := "OVERCLOCK"    ## 主动推高过载换输出
const CRYO := "CRYO"              ## 冻结 / 减速
const ARC := "ARC"                ## 电击 / 连锁
const VOID := "VOID"              ## 低 HP 高风险
const SALVAGE := "SALVAGE"        ## 资源拾取强化
const FORTIFY := "FORTIFY"        ## 护盾 / 防御
const PRECISION := "PRECISION"    ## 蓄力 / 弱点

const ALL := [OVERCLOCK, CRYO, ARC, VOID, SALVAGE, FORTIFY, PRECISION]

## 阈值：达到 2 / 4 / 6 层各解锁一档
const THRESHOLDS := [2, 4, 6]

const COLORS := {
	OVERCLOCK: Color(1.00, 0.42, 0.30),
	CRYO: Color(0.38, 0.82, 1.00),
	ARC: Color(0.72, 0.62, 1.00),
	VOID: Color(0.95, 0.30, 0.62),
	SALVAGE: Color(1.00, 0.82, 0.32),
	FORTIFY: Color(0.40, 1.00, 0.68),
	PRECISION: Color(0.60, 0.95, 0.95),
}

## 每个标签在 2 / 4 / 6 层时的效果文案 key（Lang）
const DESC_KEYS := {
	OVERCLOCK: ["tag_oc_2", "tag_oc_4", "tag_oc_6"],
	CRYO: ["tag_cryo_2", "tag_cryo_4", "tag_cryo_6"],
	ARC: ["tag_arc_2", "tag_arc_4", "tag_arc_6"],
	VOID: ["tag_void_2", "tag_void_4", "tag_void_6"],
	SALVAGE: ["tag_sal_2", "tag_sal_4", "tag_sal_6"],
	FORTIFY: ["tag_fort_2", "tag_fort_4", "tag_fort_6"],
	PRECISION: ["tag_prec_2", "tag_prec_4", "tag_prec_6"],
}


static func color_of(tag: String) -> Color:
	return COLORS.get(tag, Color(0.7, 0.7, 0.7))


static func short_name(tag: String) -> String:
	match tag:
		OVERCLOCK:
			return "OC"
		CRYO:
			return "CRYO"
		ARC:
			return "ARC"
		VOID:
			return "VOID"
		SALVAGE:
			return "SALV"
		FORTIFY:
			return "FORT"
		PRECISION:
			return "PREC"
	return tag.substr(0, 4)


## 由层数得到已解锁档位 0..3
static func tier_of(count: int) -> int:
	var t := 0
	for th in THRESHOLDS:
		if count >= th:
			t += 1
	return t
