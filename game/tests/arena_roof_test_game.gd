extends "res://main.gd"
## Isolate verification from the user's running trainer/game UDP socket.
func _bind_bridge(_port: int = UDP_PORT) -> Error:
	return super._bind_bridge(0)
