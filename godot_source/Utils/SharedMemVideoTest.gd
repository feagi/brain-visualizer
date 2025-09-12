extends Node

@onready var rect: TextureRect = $TextureRect
var reader: Variant = null

func _ready():
    var shm_path := OS.get_environment("FEAGI_VIDEO_SHM")
    if shm_path.is_empty():
        # Try common temp environment variables; if not set, require explicit path
        var tmp = OS.get_environment("TMPDIR")
        if tmp.is_empty():
            tmp = OS.get_environment("TMP")
        if tmp.is_empty():
            push_warning("SharedMemVideoTest: FEAGI_VIDEO_SHM not set and no TMP/TMPDIR found. Set FEAGI_VIDEO_SHM to the shared memory file path.")
            return
        shm_path = tmp.path_join("feagi_video_shm--temp.bin")
    if ClassDB.class_exists("SharedMemVideo"):
        reader = ClassDB.instantiate("SharedMemVideo")
    else:
        push_warning("SharedMemVideoTest: SharedMemVideo class not available (extension not loaded)")
        return
    var ok = reader.open(shm_path)
    if not ok:
        push_warning("SharedMemVideoTest: failed to open shared memory file: %s" % shm_path)

func _process(_dt: float) -> void:
    if reader == null:
        return
    var tex = reader.get_texture()
    if tex:
        rect.texture = tex


