extends RefCounted
const SPEEDS := [30,35,40,45]
const COLOURS := [Color("268cd3"),Color("35ad77"),Color("ff922e"),Color("df504b")]
var distances: Array[float] = []
var lanes: Array[float] = []
static func rider_name(index: int) -> String: return "%dkm/u Pacer" % SPEEDS[index]
func reset(rng: RandomNumberGenerator, origin: float = 0, lap_length: float = 250.0) -> void:
	distances.clear(); lanes.clear()
	var rotation := rng.randf_range(0,lap_length)
	for i in range(4):
		distances.append(origin+rotation+i*lap_length/4.0+rng.randf_range(-15,15))
		lanes.append(1.18+.6*rng.randi_range(0,4))
func advance(game, dt: float) -> void:
	for i in range(distances.size()):
		distances[i] += float(SPEEDS[i])/3.6*dt/game._path_metric(distances[i],lanes[i])
