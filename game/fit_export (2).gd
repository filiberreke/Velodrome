extends RefCounted
# FIT activity writer, no third-party dependencies. All numeric values little-endian.
# GPS is a clearly fictional 250 m track near 53N, 30W, not an actual location.
const FIT_EPOCH_UNIX: int = 631065600
const CRC_TABLE := [0x0, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401, 0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400]
const TRACK_LENGTH := 250.0
const TRACK_RADIUS := 18.0
const STRAIGHT_LENGTH := (TRACK_LENGTH - 2.0 * PI * TRACK_RADIUS) / 2.0
const CENTER_LAT := 53.0
const CENTER_LON := -30.0
const DEGREES_PER_METER_LAT := 1.0 / 111320.0
const DEGREES_PER_METER_LON := 1.0 / (111320.0 * 0.60181502315)
const SEMICIRCLE_M := PI * TRACK_RADIUS

static func _field(value: int, count: int) -> PackedByteArray:
    var b := PackedByteArray()
    for i in range(count):
        b.append((value >> (i * 8)) & 0xff)
    return b

static func _crc(buffer: PackedByteArray) -> int:
    var crc := 0
    for byte in buffer:
        var tmp: int = CRC_TABLE[crc & 0xf]
        crc = ((crc >> 4) & 0xfff) ^ tmp ^ CRC_TABLE[byte & 0xf]
        tmp = CRC_TABLE[crc & 0xf]
        crc = ((crc >> 4) & 0xfff) ^ tmp ^ CRC_TABLE[(byte >> 4) & 0xf]
    return crc & 0xffff

# tuples: [field_number, byte_length, FIT_base_type]
static func _definition(local: int, global_message: int, fields: Array) -> PackedByteArray:
    var result := PackedByteArray([0x40 | local, 0x00, 0x00])
    result.append_array(_field(global_message, 2))
    result.append(fields.size())
    for f in fields:
        result.append(int(f[0]))
        result.append(int(f[1]))
        result.append(int(f[2]))
    return result

static func _message(local: int, fields: Array, values: Array) -> PackedByteArray:
    var result := PackedByteArray([local])
    for i in range(fields.size()):
        result.append_array(_field(int(values[i]), int(fields[i][1])))
    return result

# Distance along oval: long top straight, right-hand semicircle, bottom, left semicircle.
static func _point_at(distance_m: float) -> Vector2:
    var t: float = fposmod(distance_m, TRACK_LENGTH)
    var half: float = STRAIGHT_LENGTH * 0.5
    if t < STRAIGHT_LENGTH:
        return Vector2(-half + t, TRACK_RADIUS)
    t -= STRAIGHT_LENGTH
    if t < SEMICIRCLE_M:
        var a: float = PI * 0.5 - t / TRACK_RADIUS
        return Vector2(half + TRACK_RADIUS * cos(a), TRACK_RADIUS * sin(a))
    t -= SEMICIRCLE_M
    if t < STRAIGHT_LENGTH:
        return Vector2(half - t, -TRACK_RADIUS)
    t -= STRAIGHT_LENGTH
    var a: float = -PI * 0.5 - t / TRACK_RADIUS
    return Vector2(-half + TRACK_RADIUS * cos(a), TRACK_RADIUS * sin(a))

static func _semicircles_position(distance_m: float) -> Array[int]:
    var point := _point_at(distance_m)
    var lat: float = CENTER_LAT + point.y * DEGREES_PER_METER_LAT
    var lon: float = CENTER_LON + point.x * DEGREES_PER_METER_LON
    return [roundi(lat / 180.0 * 2147483648.0), roundi(lon / 180.0 * 2147483648.0)]

static func build(samples: Array[Dictionary], start_unix: int, with_gps: bool) -> PackedByteArray:
    if samples.size() < 2:
        return PackedByteArray()
    var fields_file := [[0, 1, 0x00], [1, 2, 0x84], [2, 2, 0x84], [4, 4, 0x86]]
    var fields_record := [[253, 4, 0x86], [5, 4, 0x86], [6, 2, 0x84], [7, 2, 0x84], [4, 1, 0x02]]
    if with_gps:
        fields_record.append_array([[0, 4, 0x85], [1, 4, 0x85]])
    var fields_lap := [[253, 4, 0x86], [2, 4, 0x86], [7, 4, 0x86], [8, 4, 0x86], [9, 4, 0x86], [25, 1, 0x00], [26, 1, 0x00]]
    var fields_session := [[253, 4, 0x86], [2, 4, 0x86], [7, 4, 0x86], [8, 4, 0x86], [9, 4, 0x86], [5, 1, 0x00], [6, 1, 0x00]]
    var fields_activity := [[253, 4, 0x86], [0, 4, 0x86], [1, 2, 0x84], [2, 1, 0x00], [3, 1, 0x00], [4, 1, 0x00]]
    var body := PackedByteArray()
    var first_t: float = float(samples[0]["time_s"])
    var first_d: float = float(samples[0]["distance_m"])
    var elapsed: float = maxf(0.0, float(samples[-1]["time_s"]) - first_t)
    var metres: float = maxf(0.0, float(samples[-1]["distance_m"]) - first_d)
    var start_fit: int = maxi(0, start_unix - FIT_EPOCH_UNIX)
    var end_fit: int = start_fit + roundi(elapsed)
    body.append_array(_definition(0, 0, fields_file))
    body.append_array(_message(0, fields_file, [4, 255, 0, start_fit])) # activity file, development manufacturer
    body.append_array(_definition(1, 20, fields_record))
    var prior_timestamp: int = -1
    for s in samples:
        var seconds: float = maxf(0.0, float(s["time_s"]) - first_t)
        var ts: int = start_fit + roundi(seconds)
        if ts == prior_timestamp:
            continue # FIT timestamps use whole seconds; emit at most one per second
        prior_timestamp = ts
        var distance: float = maxf(0.0, float(s["distance_m"]) - first_d)
        var speed: float = maxf(0.0, float(s["game_speed_kmh"]) / 3.6)
        var power: int = clampi(roundi(float(s["power_w"])), 0, 65534)
        var rpm: float = float(s["cadence_rpm"])
        var cadence_value: int = clampi(roundi(rpm), 0, 254) if rpm >= 0.0 else 255
        var values: Array = [ts, clampi(roundi(distance * 100.0), 0, 2147483647), clampi(roundi(speed * 1000.0), 0, 65534), power, cadence_value]
        if with_gps:
            values.append_array(_semicircles_position(distance))
        body.append_array(_message(1, fields_record, values))
    body.append_array(_definition(2, 19, fields_lap))
    body.append_array(_message(2, fields_lap, [end_fit, start_fit, roundi(elapsed * 1000.0), roundi(elapsed * 1000.0), roundi(metres * 100.0), 2, 58]))
    body.append_array(_definition(3, 18, fields_session))
    body.append_array(_message(3, fields_session, [end_fit, start_fit, roundi(elapsed * 1000.0), roundi(elapsed * 1000.0), roundi(metres * 100.0), 2, 58]))
    body.append_array(_definition(4, 34, fields_activity))
    body.append_array(_message(4, fields_activity, [end_fit, roundi(elapsed * 1000.0), 1, 0, 26, 1]))
    var header := PackedByteArray([14, 0x20])
    header.append_array(_field(100, 2))
    header.append_array(_field(body.size(), 4))
    header.append_array(".FIT".to_ascii_buffer())
    header.append_array(_field(_crc(header), 2))
    var result := header
    result.append_array(body)
    result.append_array(_field(_crc(result), 2))
    return result
