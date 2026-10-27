extends Control
# Deliberately small: race progress only; no lane markings.
var progress: Array[float] = [0.0, 0.0, 0.0, 0.0]
const COLORS := [Color("ffdc46"), Color("54d39b"), Color("52b5fa"), Color("ff7676")]
const TRACK_LENGTH := 250.0
var rider_colours: Array[Color] = []
var peloton: Dictionary = {}
var leader_id := -1

func set_race_leader(positions: Array) -> void:
    leader_id = -1
    for i in range(positions.size()):
        if leader_id < 0 or positions[i] > positions[leader_id]: leader_id = i
    queue_redraw()


func set_peloton(value: Dictionary) -> void:
    peloton = value.duplicate(true)
    queue_redraw()

var start_lines: Array[float] = [0.0]

func set_colors(values: Array[Color]) -> void:
    rider_colours = values
    queue_redraw()

func set_progress(values: Array[float]) -> void:
    progress = values.duplicate()
    queue_redraw()

func _point(distance: float) -> Vector2:
    var t: float = fposmod(distance / TRACK_LENGTH, 1.0)
    var center := Vector2(size.x * 0.5, size.y * 0.53)
    var radius_x: float = size.x * 0.38
    var radius_y: float = size.y * 0.30
    # Oval stadium: two straights connected by semicircular turns.
    var corner_r: float = radius_y
    var straight_length: float = 2.0 * (radius_x - corner_r)
    var perim: float = 2.0 * straight_length + TAU * corner_r
    var d: float = fposmod(t * perim + straight_length, perim) # Start/finish at the end of the straight, before a bend
    var left_x: float = center.x - (radius_x - corner_r)
    var right_x: float = center.x + (radius_x - corner_r)
    if d < straight_length:
        return Vector2(right_x - d, center.y - corner_r)
    d -= straight_length
    if d < PI * corner_r:
        var theta: float = -PI * 0.5 - d / corner_r
        return Vector2(left_x + corner_r * cos(theta), center.y + corner_r * sin(theta))
    d -= PI * corner_r
    if d < straight_length:
        return Vector2(left_x + d, center.y + corner_r)
    d -= straight_length
    var theta: float = PI * 0.5 - d / corner_r
    return Vector2(right_x + corner_r * cos(theta), center.y + corner_r * sin(theta))

func _draw() -> void:
    var last: Vector2 = _point(0.0)
    for j in range(1, 129):
        var next: Vector2 = _point(TRACK_LENGTH * float(j) / 128.0)
        draw_line(last, next, Color("50758b"), 10.0, true)
        draw_line(last, next, Color("183347"), 5.0, true)
        last = next
    if not peloton.is_empty():
        var tail: float = float(peloton.tail)
        var front: float = float(peloton.front)
        for segment in range(32):
            draw_line(_point(lerpf(tail,front,float(segment)/32.0)),_point(lerpf(tail,front,float(segment+1)/32.0)),Color(0.25,0.92,0.94,0.55),18.0,true)
        for index in range(2):
            var distance: float = front if index == 0 else tail
            var colour: Color = Color("f6aa46") if index == 0 else Color("51e4e9")
            var at: Vector2 = _point(distance)
            var normal: Vector2 = (_point(distance+0.5)-_point(distance-0.5)).orthogonal().normalized()*12.0
            draw_line(at-normal,at+normal,colour,4.0,true)
            draw_string(ThemeDB.fallback_font,at+normal*(1.5 if index == 0 else -1.5),"K" if index == 0 else "S",HORIZONTAL_ALIGNMENT_LEFT,-1,15,colour)
        draw_string(ThemeDB.fallback_font,Vector2(12,20),"PELOTON  ·  K kop / S staart",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("51e4e9"))
    for start in start_lines:
        var finish: Vector2 = _point(start)
        draw_line(finish - Vector2(0, 6), finish + Vector2(0, 6), Color.WHITE, 2.0, true)
    # Other riders first, player last, making the yellow dot easy to spot.
    for i in range(progress.size() - 1, 0, -1):
        _draw_rider_dot(i)
    if not progress.is_empty():
        _draw_rider_dot(0)

    if leader_id >= 0 and leader_id < progress.size():
        var at := _point(progress[leader_id])
        var outward := (at - Vector2(size.x * .5, size.y * .53)).normalized()
        var label_at := at + outward * 20.0 + Vector2(-6, 7)
        draw_line(at, at + outward * 13.0, Color.WHITE, 2.0, true)
        draw_string_outline(ThemeDB.fallback_font, label_at, "L", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color("0a1725"))
        draw_string(ThemeDB.fallback_font, label_at, "L", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

func _draw_rider_dot(i: int) -> void:
        var pos: Vector2 = _point(progress[i])
        draw_circle(pos, 7.0 if i == 0 else 5.6, Color.WHITE if i == 0 else Color("0a1725"))
        var colour: Color = rider_colours[i] if i < rider_colours.size() else COLORS[i % COLORS.size()]
        draw_circle(pos, 4.8 if i == 0 else 4.0, colour)
