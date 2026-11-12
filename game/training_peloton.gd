extends RefCounted
## A compact rotating paceline. Its centre follows a constant training tempo;
## bounded internal movement changes the lead without attacks or breakaways.
const Exercise := preload("res://piste_exercise_session.gd")
const CENTER_LANE := 2.38
const HALF_WIDTH := 1.20
const LENGTH_M := 9.0
const ROTATION_SECONDS := 56.0
static func center_distance(reference: float) -> float:
	return Exercise.pack_tail(reference)+LENGTH_M*.5
static func sample(reference: float, elapsed: float) -> Dictionary:
	var distances: Array[float] = []
	var lanes: Array[float] = []
	var front := -INF
	var tail := INF
	var leader := -1
	var center := center_distance(reference)
	for i in range(Exercise.PACK_COUNT):
		var phase := TAU*(float(i)/Exercise.PACK_COUNT+elapsed/ROTATION_SECONDS)
		var at := center+LENGTH_M*.5*cos(phase)
		distances.append(at)
		lanes.append(CENTER_LANE+HALF_WIDTH*sin(phase))
		if at > front: front = at; leader = i
		tail = minf(tail,at)
	return {"distances":distances,"lanes":lanes,"front":front,"tail":tail,"center":center,"leader":leader}
