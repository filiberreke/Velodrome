extends RefCounted
## Colour families follow the reference photo, artwork belongs to Vélodrome.
## Slots run with race distance, starting beside the finish on the left.
const RED:Texture2D=preload("res://assets/boarding/velodrome-boarding-rood.png")
const LIGHT:Texture2D=preload("res://assets/boarding/velodrome-boarding-licht.png")
const STEF_LIGHT:Texture2D=preload("res://assets/boarding/eerlijke-stefs-licht.png")
const STEF_DARK:Texture2D=preload("res://assets/boarding/eerlijke-stefs-donker.png")
const GREEN:Texture2D=preload("res://assets/boarding/sjampanje-groen.png")
const IVORY:Texture2D=preload("res://assets/boarding/sjampanje-ivoor.png")
const TOUR:Texture2D=preload("res://assets/boarding/tour-dambiance-vierkant.png")
const FRIES:Texture2D=preload("res://assets/kiosks/chasse-patate-boarding.png")
const WIELERPRAAT:Texture2D=preload("res://assets/boarding/wielerpraat-boarding.png")
const PELOTON:Texture2D=preload("res://assets/boarding/pelotonpredictor-boarding.png")
const PANELS=[
	[PELOTON,"blue"],[RED,"red"],[STEF_LIGHT,"light"],[TOUR,"yellow"],
	[GREEN,"green"],[RED,"red"],[LIGHT,"light"],[GREEN,"green"],
	[STEF_DARK,"dark"],[RED,"red"],[IVORY,"light"],[FRIES,"yellow"],
	[STEF_LIGHT,"light"],[RED,"red"],[RED,"red"],[TOUR,"yellow"],
	[LIGHT,"light"],[RED,"red"],[STEF_LIGHT,"light"],[WIELERPRAAT,"blue"]
]
