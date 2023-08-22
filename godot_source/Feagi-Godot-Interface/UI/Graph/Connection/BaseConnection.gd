extends Line2D
class_name BaseConnection
## Base class all Cortical Connections inherit from, mainly responsive for drawing of the line

const LINE_WIDTH_PIXELS: int = 10

func _init():
    points = PackedVector2Array([Vector2(0,0), Vector2(0,0)])
    width = LINE_WIDTH_PIXELS
    end_cap_mode = Line2D.LINE_CAP_ROUND
    begin_cap_mode = Line2D.LINE_CAP_ROUND
    antialiased = true


func _move_start_point(point: Vector2) -> void:
    points = PackedVector2Array([point, points[1]])

func _move_exit_point(point: Vector2) -> void:
    points = PackedVector2Array([points[0], point])