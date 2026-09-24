extends SceneTree

var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	var scene := load("res://scenes/studio.tscn") as PackedScene
	var studio = scene.instantiate()
	studio.browser_mode = true
	root.add_child(studio)
	await process_frame
	var initial_source: String = studio.document.to_json()

	studio.canvas.grab_focus()
	studio.curve_creator.start("arc")
	var guarded: bool = studio._request_before_destructive_action(
		Callable(studio, "_show_factor_workspace"), "leave the editor")
	await process_frame
	await process_frame
	await process_frame
	_check(not guarded and studio.unsaved_dialog.visible, "unapplied curve draft opens the explicit unsaved-work confirmation")
	_check(studio.unsaved_dialog.gui_get_focus_owner() == studio.unsaved_dialog.get_cancel_button(), "unsaved-work confirmation initially focuses the non-destructive Cancel action")
	_check(studio.unsaved_dialog.get_cancel_button().get_accessibility_name() == "Keep current workspace and cancel action" and studio.unsaved_dialog.get_ok_button().get_accessibility_name() == "Discard unsaved work and continue", "unsaved-work actions identify the safe and destructive choices explicitly")
	_check(studio.active_modal == studio.unsaved_dialog and studio.modal_focus_before == studio.canvas, "unsaved-work confirmation retains the exact editor focus owner")
	studio._cancel_pending_action()
	await process_frame
	_check(root.gui_get_focus_owner() == studio.canvas, "canceling unsaved-work confirmation restores canvas focus")
	_check(studio.document.to_json() == initial_source and studio.curve_creator.active, "canceling confirmation preserves accepted JSON and the unapplied curve draft")
	studio.curve_creator.cancel()

	studio.canvas.grab_focus()
	studio.curve_creator.start("arc")
	var guarded_open := Callable(studio, "_open_resource_after_guard").bind("res://fixtures/braid-v1.json")
	studio._request_before_destructive_action(guarded_open, "open braid-v1.json")
	await process_frame
	await process_frame
	studio._discard_and_continue()
	await process_frame
	await process_frame
	_check(studio.document.data.kind == "braid" and not studio.curve_creator.active, "confirming discard clears the draft and continues the requested exact open action")
	_check(studio.active_modal == null and studio.modal_focus_before == null, "continued action clears modal state")
	_check(root.gui_get_focus_owner() == studio.canvas, "continued action begins from the control that opened the confirmation")
	_check(studio.document.to_json() != initial_source and studio.baseline_source == studio.document.to_json(), "discard-and-continue accepts only the explicitly opened fixture")

	studio._open_resource("res://fixtures/multi-curve-v1.json")
	await process_frame
	studio.browser_drafts.button_pressed = true
	studio._select_record(0)
	var before_reindex: String = studio.document.to_json()
	studio.reindex_right_button.grab_focus()
	studio._request_reindex(1)
	await process_frame
	await process_frame
	await process_frame
	_check(studio.reindex_dialog.visible and not studio.pending_reindex.is_empty(), "validated reindex proposal opens its explicit confirmation")
	_check(studio.reindex_dialog.gui_get_focus_owner() == studio.reindex_dialog.get_cancel_button(), "reindex confirmation initially focuses Cancel instead of Apply")
	_check(studio.reindex_dialog.get_cancel_button().get_accessibility_name() == "Cancel row reindex" and studio.reindex_dialog.get_ok_button().get_accessibility_name() == "Apply validated row reindex", "reindex actions identify cancellation and the exact mutation explicitly")
	_check(studio.modal_focus_before == studio.reindex_right_button, "reindex confirmation retains the invoking control")
	studio._cancel_reindex()
	await process_frame
	_check(root.gui_get_focus_owner() == studio.reindex_right_button, "canceling reindex restores the invoking control")
	_check(studio.document.to_json() == before_reindex and not studio.history.can_undo(), "canceling reindex leaves exact source and history unchanged")

	studio.reindex_right_button.grab_focus()
	studio._request_reindex(1)
	await process_frame
	studio._confirm_reindex()
	await process_frame
	_check(root.gui_get_focus_owner() == studio.reindex_right_button, "confirming reindex restores the invoking control after the accepted update")
	_check(studio.document.to_json() != before_reindex and studio.history.can_undo(), "confirmed reindex remains the single intentional mathematical command")
	studio._undo()
	_check(studio.document.to_json() == before_reindex, "undo after focused reindex confirmation restores exact source")

	studio.canvas.grab_focus()
	studio._popup_fitted(studio.recovery_dialog, Vector2i(580, 230), studio.recovery_dialog.get_ok_button())
	await process_frame
	await process_frame
	_check(studio.recovery_dialog.gui_get_focus_owner() == studio.recovery_dialog.get_ok_button(), "recovery confirmation initially focuses Restore rather than destructive Discard")
	_check(studio.recovery_dialog.get_ok_button().get_accessibility_name() == "Restore recovered workspace" and studio.recovery_dialog.get_cancel_button().get_accessibility_name() == "Discard recovered workspace", "recovery actions identify restore and destructive discard explicitly")
	studio._discard_startup_recovery()
	await process_frame
	_check(root.gui_get_focus_owner() == studio.canvas, "closing recovery confirmation restores prior editor focus")
	_check(studio.document.to_json() == before_reindex and studio.active_modal == null and studio.modal_focus_before == null, "modal focus cleanup leaves mathematical JSON and modal state exact")

	studio.queue_free()
	await process_frame
	print("MODAL FOCUS %s: %d assertions, %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
