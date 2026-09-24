extends RefCounted
class_name GenomeEditApplier
## Dispatches one history step to the writer that knows that gesture.


static func apply(edit: GenomeEdit, forward: bool) -> Dictionary:
	if edit is PositionEdit:
		return await GenomePositionApplier.apply(edit as PositionEdit, forward)
	if edit is DeleteAreaEdit:
		return await DeleteAreaApplier.apply(edit as DeleteAreaEdit, forward)
	return {"ok": false, "save_failed": false}
