extends RefCounted
class_name TeamBranchText
## Text for the team experiment branch badge and live teammate notices.
##
## Inputs are the JSON messages feagi-desktop sends on its event socket
## (see feagi-desktop `commands/team_bv_events.rs`). Pure functions only, so
## they can be tested headless.

const MODE_COLLABORATIVE: String = "collaborative"
const MODE_FORK: String = "fork"
const MODE_PENDING: String = "pending"


## True when the badge should be shown (a team experiment is running).
static func is_team_state(state: Dictionary) -> bool:
	return bool(state.get("team", false)) and typeof(state.get("branch")) == TYPE_DICTIONARY


## Branch mode of a team state: "collaborative", "fork", "pending" or "unknown".
static func mode_of(state: Dictionary) -> String:
	if not is_team_state(state):
		return ""
	return str((state["branch"] as Dictionary).get("mode", "unknown"))


## Badge label, e.g. "Collaborative genome (rev 12)" or "Independent fork (from rev 10)".
static func badge_label(state: Dictionary) -> String:
	if not is_team_state(state):
		return ""
	var branch: Dictionary = state["branch"]
	match mode_of(state):
		MODE_COLLABORATIVE:
			return "Collaborative genome (rev %d)" % int(branch.get("master_revision", 0))
		MODE_FORK:
			return "Independent fork (from rev %d)" % int(branch.get("diverged_from_revision", 0))
		MODE_PENDING:
			return "Checking branch..."
		_:
			return "Branch unknown"


## Tooltip explaining what saving means on this branch.
static func badge_tooltip(state: Dictionary) -> String:
	match mode_of(state):
		MODE_COLLABORATIVE:
			return "Your edits save to the team's shared genome. Teammates see them and are notified."
		MODE_FORK:
			return "Your edits save to your own fork. Teammates are not notified. A teammate can make it the collaborative genome from Neurorobotics Studio."
		MODE_PENDING:
			return "Neurorobotics Studio is checking whether this connectome keeps you on the collaborative genome."
		"":
			return ""
		_:
			return "This brain was not loaded from the collaborative genome or a team connectome; autosave is paused."


## Live notice for a teammate's change to the collaborative genome running here.
static func event_text(event: Dictionary) -> String:
	var actor: String = str(event.get("actor_display_name", ""))
	if actor.strip_edges() == "" or actor == "<null>":
		actor = "A teammate"
	var revision_value = event.get("revision")
	var revision: String = "a new revision" if revision_value == null else "revision %d" % int(revision_value)
	match str(event.get("kind", "")):
		"master_replaced":
			return "%s replaced the collaborative genome with a fork (%s)." % [actor, revision]
		"master_reverted":
			return "%s switched the collaborative genome back to an earlier version (%s)." % [actor, revision]
		"master_checkpoint_reverted":
			return "%s restored a checkpoint into the collaborative genome (%s)." % [actor, revision]
		_:
			return "%s saved %s of the collaborative genome." % [actor, revision]
