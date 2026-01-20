extends Node

## StatusReporter
## Writes status updates to a file that the Desktop Suite can read

var _status_file_path: String = ""
var _enabled: bool = false

func _ready() -> void:
	# Check if launched from Desktop Suite via command-line arguments
	var all_args = OS.get_cmdline_args()  # Get ALL arguments (including engine args)
	var user_args = OS.get_cmdline_user_args()  # Get user-passed arguments (after --)
	
	print("[StatusReporter] ========================================")
	print("[StatusReporter] All args: ", all_args)
	print("[StatusReporter] User args: ", user_args)
	print("[StatusReporter] ========================================")
	
	# Try both argument lists
	var args_to_check = [all_args, user_args]
	
	for args in args_to_check:
		for i in range(args.size()):
			if args[i] == "--status-file" and i + 1 < args.size():
				_status_file_path = args[i + 1]
				_enabled = true
				print("[StatusReporter] ✅ Enabled - writing to: ", _status_file_path)
				report_status("Brain Visualizer launched")
				return
	
	print("[StatusReporter] ⚠️ Disabled - not launched from Desktop Suite")

## Report a status message
func report_status(message: String) -> void:
	if not _enabled or _status_file_path == "":
		return
	
	var file = FileAccess.open(_status_file_path, FileAccess.WRITE)
	if file:
		var timestamp = Time.get_datetime_string_from_system()
		file.store_string(JSON.stringify({
			"status": message,
			"timestamp": timestamp
		}))
		file.close()
		print("[StatusReporter] ", message)
	else:
		push_error("Failed to write status to: ", _status_file_path)

## Report an error
func report_error(message: String) -> void:
	report_status("❌ " + message)

## Report success
func report_success(message: String) -> void:
	report_status("✓ " + message)

