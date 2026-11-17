extends Node
## Every number that shapes how the game plays. Mirrors MECHANICS.md / mechanics.json.

const CELL := 32
const MAP_W := 3840
const MAP_H := 2560
const POP_MAX := 100

const RES := ["food", "wood", "stone", "gold"]
const RES_NAMES := {"food": "Comida", "wood": "Madeira", "stone": "Pedra", "gold": "Ouro"}
const RES_SHORT := {"food": "C", "wood": "M", "stone": "P", "gold": "O"}
const RES_COLORS := {
	"food": Color(0.92, 0.35, 0.35),
	"wood": Color(0.62, 0.42, 0.22),
	"stone": Color(0.7, 0.7, 0.72),
	"gold": Color(0.98, 0.82, 0.2),
}

const START_RES := {"food": 200, "wood": 200, "stone": 100, "gold": 100}
const START_VILLAGERS := 4

const CARRY_CAP := 10.0
## resources gathered per second by one villager
const GATHER_RATE := {"wood": 0.6, "food": 0.9, "farm": 0.7, "stone": 0.45, "gold": 0.45}

const EPOCHS := [
	{"name": "Idade da Pedra", "cost": {}, "time": 0.0},
	{"name": "Idade do Bronze", "cost": {"food": 300, "wood": 150}, "time": 30.0},
	{"name": "Idade do Ferro", "cost": {"food": 600, "wood": 300, "gold": 200}, "time": 40.0},
	{"name": "Idade Medieval", "cost": {"food": 800, "stone": 400, "gold": 400}, "time": 50.0},
]
## military hit points and attack grow by this share each epoch
const EPOCH_BONUS := 0.15

const UNITS := {
	"villager": {"name": "Aldeão", "hp": 50.0, "atk": 3.0, "range": 12.0, "cd": 1.5, "speed": 70.0,
		"cost": {"food": 50}, "time": 10.0, "epoch": 0, "cls": "villager", "radius": 9.0, "sight": 220.0, "pop": 1},
	"spear": {"name": "Lanceiro", "hp": 110.0, "atk": 9.0, "range": 14.0, "cd": 1.2, "speed": 75.0,
		"cost": {"food": 50, "wood": 25}, "time": 14.0, "epoch": 0, "cls": "infantry", "radius": 10.0, "sight": 260.0, "pop": 1},
	"archer": {"name": "Arqueiro", "hp": 70.0, "atk": 7.0, "range": 180.0, "cd": 1.6, "speed": 75.0,
		"cost": {"wood": 40, "gold": 30}, "time": 15.0, "epoch": 1, "cls": "archer", "radius": 9.0, "sight": 280.0, "pop": 1},
	"cavalry": {"name": "Cavaleiro", "hp": 160.0, "atk": 11.0, "range": 16.0, "cd": 1.4, "speed": 120.0,
		"cost": {"food": 80, "gold": 60}, "time": 20.0, "epoch": 2, "cls": "cavalry", "radius": 13.0, "sight": 300.0, "pop": 2},
	"catapult": {"name": "Catapulta", "hp": 150.0, "atk": 40.0, "range": 260.0, "cd": 4.0, "speed": 45.0,
		"cost": {"wood": 150, "gold": 120}, "time": 30.0, "epoch": 3, "cls": "siege", "radius": 14.0, "sight": 300.0, "pop": 3},
}

## attacker kind -> target class -> damage multiplier (rock-paper-scissors)
const BONUS := {
	"spear": {"cavalry": 2.5},
	"archer": {"infantry": 1.5},
	"cavalry": {"archer": 2.0, "siege": 2.0},
	"catapult": {"building": 3.0},
	"villager": {},
}
## damage dealt to buildings by non-siege units is reduced
const VS_BUILDING := 0.35

const BUILDINGS := {
	"town_center": {"name": "Centro da Cidade", "hp": 2400.0, "size": 4, "cost": {"wood": 300, "stone": 200},
		"time": 60.0, "epoch": 0, "pop": 10, "drop": true, "trains": ["villager"], "atk": 6.0, "range": 210.0, "cd": 2.0, "solid": true},
	"house": {"name": "Casa", "hp": 400.0, "size": 2, "cost": {"wood": 40}, "time": 15.0, "epoch": 0, "pop": 5,
		"drop": false, "trains": [], "solid": true},
	"barracks": {"name": "Quartel", "hp": 1000.0, "size": 3, "cost": {"wood": 150}, "time": 30.0, "epoch": 0, "pop": 0,
		"drop": false, "trains": ["spear", "archer", "cavalry", "catapult"], "solid": true},
	"depot": {"name": "Depósito", "hp": 500.0, "size": 2, "cost": {"wood": 100}, "time": 20.0, "epoch": 0, "pop": 0,
		"drop": true, "trains": [], "solid": true},
	"farm": {"name": "Fazenda", "hp": 200.0, "size": 3, "cost": {"wood": 60}, "time": 12.0, "epoch": 0, "pop": 0,
		"drop": false, "trains": [], "solid": false},
	"tower": {"name": "Torre", "hp": 900.0, "size": 2, "cost": {"wood": 50, "stone": 100}, "time": 30.0, "epoch": 1,
		"pop": 0, "drop": false, "trains": [], "atk": 8.0, "range": 230.0, "cd": 1.8, "solid": true},
}
## what a villager can build, in button order
const BUILD_MENU := ["house", "farm", "depot", "barracks", "tower", "town_center"]

const RESOURCE_NODES := {
	"tree": {"res": "wood", "amount": 100.0, "radius": 14.0},
	"berries": {"res": "food", "amount": 150.0, "radius": 12.0},
	"stone": {"res": "stone", "amount": 400.0, "radius": 18.0},
	"gold": {"res": "gold", "amount": 400.0, "radius": 18.0},
}

const DIFFICULTY := {
	"Facil": {"villagers": 12, "first_attack": 420.0, "wave": 4, "wave_grow": 2, "gather_mult": 0.8, "think": 1.6},
	"Normal": {"villagers": 18, "first_attack": 300.0, "wave": 6, "wave_grow": 3, "gather_mult": 1.0, "think": 1.0},
	"Dificil": {"villagers": 24, "first_attack": 210.0, "wave": 8, "wave_grow": 4, "gather_mult": 1.2, "think": 0.7},
}

const TEAM_COLORS := [Color(0.22, 0.5, 0.95), Color(0.9, 0.22, 0.2)]

var difficulty := "Normal"


func cost_text(cost: Dictionary) -> String:
	var parts := []
	for r in RES:
		if cost.has(r):
			parts.append("%d%s" % [cost[r], RES_SHORT[r]])
	return " ".join(parts)
