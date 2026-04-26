"""
Tests for all nine task tools:
  task_create, task_get, task_list, task_update, task_transition,
  task_invalidate, task_add_note, task_link_artifact, task_history
"""
import re
import uuid

import pytest

from .conftest import ToolFailed, call

pytestmark = pytest.mark.anyio

# ---------------------------------------------------------------------------
# task_create
# ---------------------------------------------------------------------------


async def test_task_create_returns_uuid_task_id(mcp, project):
    result = await call(mcp, "task_create",
                        project_id=project["project_id"],
                        project_token=project["project_token"],
                        kind="bug", title="Test task")
    assert re.fullmatch(r"[0-9a-f-]{36}", result["task_id"])
    uuid.UUID(result["task_id"])  # also validates uuid format


async def test_task_create_task_key_format(mcp, project):
    result = await call(mcp, "task_create",
                        project_id=project["project_id"],
                        project_token=project["project_token"],
                        kind="bug", title="Test task")
    slug_upper = project["project_slug"].upper()
    assert result["task_key"].startswith(slug_upper + "-")
    seq = result["task_key"].split("-")[-1]
    assert seq.isdigit()


async def test_task_create_key_increments_per_project(mcp, project):
    t1 = await call(mcp, "task_create",
                    project_id=project["project_id"],
                    project_token=project["project_token"],
                    kind="feature", title="First")
    t2 = await call(mcp, "task_create",
                    project_id=project["project_id"],
                    project_token=project["project_token"],
                    kind="feature", title="Second")
    seq1 = int(t1["task_key"].rsplit("-", 1)[-1])
    seq2 = int(t2["task_key"].rsplit("-", 1)[-1])
    assert seq2 == seq1 + 1


async def test_task_create_idempotency_key_deduplicates(mcp, project):
    kwargs = dict(project_id=project["project_id"],
                  project_token=project["project_token"],
                  kind="bug", title="Dup task",
                  idempotency_key=f"idem-{uuid.uuid4().hex[:8]}")
    t1 = await call(mcp, "task_create", **kwargs)
    t2 = await call(mcp, "task_create", **kwargs)
    assert t1["task_id"] == t2["task_id"]
    assert t2.get("idempotent") is True


async def test_task_create_invalid_kind_raises_validation_error(mcp, project):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_create",
                   project_id=project["project_id"],
                   project_token=project["project_token"],
                   kind="nonsense", title="Bad")
    assert exc.value.code == "validation_error"


async def test_task_create_invalid_state_raises_validation_error(mcp, project):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_create",
                   project_id=project["project_id"],
                   project_token=project["project_token"],
                   kind="bug", title="Bad", state="flying")
    assert exc.value.code == "validation_error"


async def test_task_create_invalid_priority_raises_validation_error(mcp, project):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_create",
                   project_id=project["project_id"],
                   project_token=project["project_token"],
                   kind="bug", title="Bad", priority="urgent")
    assert exc.value.code == "validation_error"


async def test_task_create_wrong_token_raises_invalid_token(mcp, project):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_create",
                   project_id=project["project_id"],
                   project_token="dead" * 16,
                   kind="bug", title="Bad")
    assert exc.value.code == "invalid_token"


async def test_task_create_unknown_project_raises_project_not_found(mcp, project):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_create",
                   project_id=str(uuid.uuid4()),
                   project_token=project["project_token"],
                   kind="bug", title="Bad")
    assert exc.value.code == "project_not_found"


# ---------------------------------------------------------------------------
# task_get
# ---------------------------------------------------------------------------


async def test_task_get_returns_full_record(mcp, task):
    result = await call(mcp, "task_get", task_id=task["task_id"])
    assert result["task_id"] == task["task_id"]
    assert result["task_key"] == task["task_key"]
    assert result["state"] == "new"
    assert result["kind"] == "bug"


async def test_task_get_not_found_raises_task_not_found(mcp):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_get", task_id=str(uuid.uuid4()))
    assert exc.value.code == "task_not_found"


# ---------------------------------------------------------------------------
# task_list
# ---------------------------------------------------------------------------


async def test_task_list_returns_list(mcp, task):
    result = await call(mcp, "task_list", project_id=task["project_id"])
    assert isinstance(result, list)
    assert len(result) >= 1


async def test_task_list_by_project_id_contains_task(mcp, task):
    result = await call(mcp, "task_list", project_id=task["project_id"])
    ids = [t["task_id"] for t in result]
    assert task["task_id"] in ids


async def test_task_list_by_project_slug_matches_by_id(mcp, task):
    by_id = await call(mcp, "task_list", project_id=task["project_id"])
    by_slug = await call(mcp, "task_list", project_slug=task["project_slug"])
    assert len(by_id) == len(by_slug)
    assert {t["task_id"] for t in by_id} == {t["task_id"] for t in by_slug}


async def test_task_list_state_filter(mcp, project):
    await call(mcp, "task_create",
               project_id=project["project_id"],
               project_token=project["project_token"],
               kind="bug", title="New task", state="new")
    result = await call(mcp, "task_list",
                        project_id=project["project_id"], state="new")
    assert all(t["state"] == "new" for t in result)


async def test_task_list_excludes_invalid_by_default(mcp, project):
    t = await call(mcp, "task_create",
                   project_id=project["project_id"],
                   project_token=project["project_token"],
                   kind="chore", title="To invalidate")
    await call(mcp, "task_invalidate",
               task_id=t["task_id"],
               project_id=project["project_id"],
               project_token=project["project_token"],
               reason_code="duplicate")
    excl = await call(mcp, "task_list",
                      project_id=project["project_id"], include_invalid=False)
    incl = await call(mcp, "task_list",
                      project_id=project["project_id"], include_invalid=True)
    excl_ids = {t["task_id"] for t in excl}
    incl_ids = {t["task_id"] for t in incl}
    assert t["task_id"] not in excl_ids
    assert t["task_id"] in incl_ids


async def test_task_list_overdue_filter_empty_when_none_overdue(mcp, task):
    result = await call(mcp, "task_list",
                        project_id=task["project_id"], overdue=True)
    assert isinstance(result, list)
    # None of the fixture tasks have an expected_callback_at in the past
    overdue_ids = {t["task_id"] for t in result}
    assert task["task_id"] not in overdue_ids


async def test_task_list_unknown_project_raises_project_not_found(mcp):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_list", project_slug="no-such-project")
    assert exc.value.code == "project_not_found"


# ---------------------------------------------------------------------------
# task_update
# ---------------------------------------------------------------------------


async def test_task_update_patches_fields(mcp, task):
    result = await call(mcp, "task_update",
                        task_id=task["task_id"],
                        project_id=task["project_id"],
                        project_token=task["project_token"],
                        revision=1,
                        pr_number=99,
                        next_action="Review PR")
    assert result["pr_number"] == 99
    assert result["next_action"] == "Review PR"


async def test_task_update_increments_revision(mcp, task):
    result = await call(mcp, "task_update",
                        task_id=task["task_id"],
                        project_id=task["project_id"],
                        project_token=task["project_token"],
                        revision=1,
                        priority="high")
    assert result["revision"] == 2


async def test_task_update_revision_mismatch_raises_revision_mismatch(mcp, task):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_update",
                   task_id=task["task_id"],
                   project_id=task["project_id"],
                   project_token=task["project_token"],
                   revision=99,
                   priority="low")
    assert exc.value.code == "revision_mismatch"


async def test_task_update_no_fields_raises_validation_error(mcp, task):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_update",
                   task_id=task["task_id"],
                   project_id=task["project_id"],
                   project_token=task["project_token"],
                   revision=1)
    assert exc.value.code == "validation_error"


async def test_task_update_wrong_token_raises_invalid_token(mcp, task):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_update",
                   task_id=task["task_id"],
                   project_id=task["project_id"],
                   project_token="dead" * 16,
                   revision=1,
                   priority="low")
    assert exc.value.code == "invalid_token"


async def test_task_update_unknown_task_raises_task_not_found(mcp, project):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_update",
                   task_id=str(uuid.uuid4()),
                   project_id=project["project_id"],
                   project_token=project["project_token"],
                   revision=1,
                   priority="low")
    assert exc.value.code in ("task_not_found", "revision_mismatch")


# ---------------------------------------------------------------------------
# task_transition
# ---------------------------------------------------------------------------


async def test_task_transition_changes_state(mcp, task):
    result = await call(mcp, "task_transition",
                        task_id=task["task_id"],
                        project_id=task["project_id"],
                        project_token=task["project_token"],
                        from_state="new", to_state="triage", revision=1)
    assert result["state"] == "triage"


async def test_task_transition_increments_revision(mcp, task):
    result = await call(mcp, "task_transition",
                        task_id=task["task_id"],
                        project_id=task["project_id"],
                        project_token=task["project_token"],
                        from_state="new", to_state="triage", revision=1)
    assert result["revision"] == 2


async def test_task_transition_revision_mismatch_raises_revision_mismatch(mcp, task):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_transition",
                   task_id=task["task_id"],
                   project_id=task["project_id"],
                   project_token=task["project_token"],
                   from_state="new", to_state="triage", revision=99)
    assert exc.value.code == "revision_mismatch"


async def test_task_transition_wrong_from_state_raises_revision_mismatch(mcp, task):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_transition",
                   task_id=task["task_id"],
                   project_id=task["project_id"],
                   project_token=task["project_token"],
                   from_state="triage", to_state="specifying", revision=1)
    assert exc.value.code == "revision_mismatch"


async def test_task_transition_invalid_to_state_raises_validation_error(mcp, task):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_transition",
                   task_id=task["task_id"],
                   project_id=task["project_id"],
                   project_token=task["project_token"],
                   from_state="new", to_state="flying", revision=1)
    assert exc.value.code == "validation_error"


async def test_task_transition_wrong_token_raises_invalid_token(mcp, task):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_transition",
                   task_id=task["task_id"],
                   project_id=task["project_id"],
                   project_token="dead" * 16,
                   from_state="new", to_state="triage", revision=1)
    assert exc.value.code == "invalid_token"


async def test_task_transition_sets_completed_at_when_done(mcp, task):
    result = await call(mcp, "task_transition",
                        task_id=task["task_id"],
                        project_id=task["project_id"],
                        project_token=task["project_token"],
                        from_state="new", to_state="done", revision=1)
    assert result["state"] == "done"
    assert result["completed_at"] is not None


# ---------------------------------------------------------------------------
# task_invalidate
# ---------------------------------------------------------------------------


async def test_task_invalidate_sets_state_invalid(mcp, task):
    result = await call(mcp, "task_invalidate",
                        task_id=task["task_id"],
                        project_id=task["project_id"],
                        project_token=task["project_token"],
                        reason_code="duplicate")
    assert result["state"] == "invalid"
    assert result["invalidated_at"] is not None
    assert result["invalidation_reason"] == "duplicate"


async def test_task_invalidate_already_invalid_raises_already_invalid(mcp, task):
    await call(mcp, "task_invalidate",
               task_id=task["task_id"],
               project_id=task["project_id"],
               project_token=task["project_token"],
               reason_code="duplicate")
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_invalidate",
                   task_id=task["task_id"],
                   project_id=task["project_id"],
                   project_token=task["project_token"],
                   reason_code="duplicate")
    assert exc.value.code == "already_invalid"


async def test_task_invalidate_wrong_token_raises_invalid_token(mcp, task):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_invalidate",
                   task_id=task["task_id"],
                   project_id=task["project_id"],
                   project_token="dead" * 16,
                   reason_code="duplicate")
    assert exc.value.code == "invalid_token"


async def test_task_invalidate_unknown_task_raises_task_not_found(mcp, project):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_invalidate",
                   task_id=str(uuid.uuid4()),
                   project_id=project["project_id"],
                   project_token=project["project_token"],
                   reason_code="duplicate")
    assert exc.value.code == "task_not_found"


# ---------------------------------------------------------------------------
# task_add_note
# ---------------------------------------------------------------------------


async def test_task_add_note_returns_note_record(mcp, task):
    result = await call(mcp, "task_add_note",
                        task_id=task["task_id"],
                        project_id=task["project_id"],
                        project_token=task["project_token"],
                        note="This is a note",
                        author_type="triage",
                        author_id="triage-agent")
    assert result["task_id"] == task["task_id"]
    assert result["note"] == "This is a note"
    assert result["author_type"] == "triage"
    assert "id" in result


async def test_task_add_note_wrong_token_raises_invalid_token(mcp, task):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_add_note",
                   task_id=task["task_id"],
                   project_id=task["project_id"],
                   project_token="dead" * 16,
                   note="bad note")
    assert exc.value.code == "invalid_token"


async def test_task_add_note_unknown_task_raises_task_not_found(mcp, project):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_add_note",
                   task_id=str(uuid.uuid4()),
                   project_id=project["project_id"],
                   project_token=project["project_token"],
                   note="ghost note")
    assert exc.value.code == "task_not_found"


# ---------------------------------------------------------------------------
# task_link_artifact
# ---------------------------------------------------------------------------


async def test_task_link_artifact_returns_artifact_record(mcp, task):
    result = await call(mcp, "task_link_artifact",
                        task_id=task["task_id"],
                        project_id=task["project_id"],
                        project_token=task["project_token"],
                        artifact_kind="issue",
                        artifact_ref="42",
                        url="https://github.com/example/repo/issues/42")
    assert result["task_id"] == task["task_id"]
    assert result["artifact_kind"] == "issue"
    assert result["artifact_ref"] == "42"
    assert "id" in result


async def test_task_link_artifact_all_valid_kinds(mcp, task):
    valid_kinds = ["issue", "pr", "branch", "commit", "wiki", "decision-record", "release"]
    for kind in valid_kinds:
        result = await call(mcp, "task_link_artifact",
                            task_id=task["task_id"],
                            project_id=task["project_id"],
                            project_token=task["project_token"],
                            artifact_kind=kind,
                            artifact_ref=f"ref-{kind}")
        assert result["artifact_kind"] == kind


async def test_task_link_artifact_invalid_kind_raises_validation_error(mcp, task):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_link_artifact",
                   task_id=task["task_id"],
                   project_id=task["project_id"],
                   project_token=task["project_token"],
                   artifact_kind="bogus",
                   artifact_ref="x")
    assert exc.value.code == "validation_error"


async def test_task_link_artifact_wrong_token_raises_invalid_token(mcp, task):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_link_artifact",
                   task_id=task["task_id"],
                   project_id=task["project_id"],
                   project_token="dead" * 16,
                   artifact_kind="issue",
                   artifact_ref="1")
    assert exc.value.code == "invalid_token"


async def test_task_link_artifact_unknown_task_raises_task_not_found(mcp, project):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_link_artifact",
                   task_id=str(uuid.uuid4()),
                   project_id=project["project_id"],
                   project_token=project["project_token"],
                   artifact_kind="issue",
                   artifact_ref="1")
    assert exc.value.code == "task_not_found"


# ---------------------------------------------------------------------------
# task_history
# ---------------------------------------------------------------------------


async def test_task_history_returns_structure(mcp, task):
    result = await call(mcp, "task_history", task_id=task["task_id"])
    assert "task" in result
    assert "history" in result
    assert "notes" in result
    assert "artifacts" in result
    assert isinstance(result["history"], list)
    assert isinstance(result["notes"], list)
    assert isinstance(result["artifacts"], list)


async def test_task_history_task_record_matches(mcp, task):
    result = await call(mcp, "task_history", task_id=task["task_id"])
    assert result["task"]["task_id"] == task["task_id"]


async def test_task_history_created_event_present(mcp, task):
    result = await call(mcp, "task_history", task_id=task["task_id"])
    event_types = [e["event_type"] for e in result["history"]]
    assert "task.created" in event_types


async def test_task_history_records_transition(mcp, task):
    await call(mcp, "task_transition",
               task_id=task["task_id"],
               project_id=task["project_id"],
               project_token=task["project_token"],
               from_state="new", to_state="triage", revision=1)
    result = await call(mcp, "task_history", task_id=task["task_id"])
    transitions = [e for e in result["history"] if e["event_type"] == "task.transitioned"]
    assert len(transitions) == 1
    assert transitions[0]["from_state"] == "new"
    assert transitions[0]["to_state"] == "triage"


async def test_task_history_records_note(mcp, task):
    await call(mcp, "task_add_note",
               task_id=task["task_id"],
               project_id=task["project_id"],
               project_token=task["project_token"],
               note="History test note")
    result = await call(mcp, "task_history", task_id=task["task_id"])
    assert len(result["notes"]) == 1
    assert result["notes"][0]["note"] == "History test note"


async def test_task_history_records_artifact(mcp, task):
    await call(mcp, "task_link_artifact",
               task_id=task["task_id"],
               project_id=task["project_id"],
               project_token=task["project_token"],
               artifact_kind="pr",
               artifact_ref="7")
    result = await call(mcp, "task_history", task_id=task["task_id"])
    assert len(result["artifacts"]) == 1
    assert result["artifacts"][0]["artifact_kind"] == "pr"


async def test_task_history_not_found_raises_task_not_found(mcp):
    with pytest.raises(ToolFailed) as exc:
        await call(mcp, "task_history", task_id=str(uuid.uuid4()))
    assert exc.value.code == "task_not_found"


async def test_task_history_events_in_chronological_order(mcp, task):
    await call(mcp, "task_transition",
               task_id=task["task_id"],
               project_id=task["project_id"],
               project_token=task["project_token"],
               from_state="new", to_state="triage", revision=1)
    await call(mcp, "task_add_note",
               task_id=task["task_id"],
               project_id=task["project_id"],
               project_token=task["project_token"],
               note="Note after transition")
    result = await call(mcp, "task_history", task_id=task["task_id"])
    timestamps = [e["created_at"] for e in result["history"]]
    assert timestamps == sorted(timestamps)
