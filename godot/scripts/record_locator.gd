class_name RecordLocator
extends RefCounted

# DiagramDocument currently bounds the largest inspector at 161 rows. Keep an
# independent conservative ceiling so this view helper cannot become an
# unbounded search surface if another record source calls it later.
const MAX_RECORDS := 192
const MAX_QUERY_LENGTH := 80

static func find(records: Array[Dictionary], query: String) -> Dictionary:
	if records.size() > MAX_RECORDS:
		return {"ok": false, "error": "Record search exceeds the 192-row bound", "results": []}
	var normalized := query.strip_edges().to_lower()
	if normalized.length() > MAX_QUERY_LENGTH:
		return {"ok": false, "error": "Record search is limited to 80 characters", "results": []}
	var terms := normalized.split(" ", false)
	var results: Array[Dictionary] = []
	for row in records.size():
		var record: Dictionary = records[row]
		var kind := str(record.get("kind", ""))
		var id := str(record.get("id", ""))
		var label := str(record.get("label", ""))
		var haystack := " ".join([kind, id, label, str(row + 1)]).to_lower()
		var matches := true
		for term in terms:
			if term not in haystack:
				matches = false
				break
		if matches:
			results.append({
				"row": row,
				"record": record.duplicate(true),
				"display": label,
				"exact_id": not id.is_empty() and normalized == id.to_lower()
			})
	return {"ok": true, "error": "", "results": results}
