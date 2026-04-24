-- Canonical project isolation and authorization table
CREATE TABLE IF NOT EXISTS projects (
    project_id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    project_slug       TEXT        UNIQUE NOT NULL,
    display_name       TEXT        NOT NULL,
    ledger_namespace   TEXT        UNIQUE NOT NULL,
    project_token_hash TEXT        NOT NULL,
    task_next_seq      BIGINT      NOT NULL DEFAULT 1,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archived_at        TIMESTAMPTZ,
    token_rotated_at   TIMESTAMPTZ
);

-- Canonical current-state table (no hard deletes)
CREATE TABLE IF NOT EXISTS tasks (
    task_id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id           UUID        NOT NULL REFERENCES projects(project_id),
    task_key             TEXT        UNIQUE,
    kind                 TEXT        NOT NULL,
    title                TEXT        NOT NULL,
    state                TEXT        NOT NULL DEFAULT 'new',
    priority             TEXT,
    owner_agent_type     TEXT,
    owner_agent_id       TEXT,
    source_kind          TEXT,
    source_id            TEXT,
    issue_number         INTEGER,
    pr_number            INTEGER,
    branch               TEXT,
    next_action          TEXT,
    expected_callback_at TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at         TIMESTAMPTZ,
    invalidated_at       TIMESTAMPTZ,
    invalidation_reason  TEXT,
    revision             BIGINT      NOT NULL DEFAULT 1,
    idempotency_key      TEXT        UNIQUE
);

-- Authoritative task-level mutation history (append-only)
CREATE TABLE IF NOT EXISTS task_history (
    id           BIGSERIAL   PRIMARY KEY,
    project_id   UUID        NOT NULL REFERENCES projects(project_id),
    task_id      UUID        NOT NULL REFERENCES tasks(task_id),
    event_type   TEXT        NOT NULL,
    from_state   TEXT,
    to_state     TEXT,
    summary      TEXT,
    reason_code  TEXT,
    actor_type   TEXT,
    actor_id     TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payload_json JSONB       NOT NULL DEFAULT '{}'
);

-- Linked durable artifacts (issues, PRs, branches, wiki pages, etc.)
CREATE TABLE IF NOT EXISTS task_artifacts (
    id            BIGSERIAL   PRIMARY KEY,
    project_id    UUID        NOT NULL REFERENCES projects(project_id),
    task_id       UUID        NOT NULL REFERENCES tasks(task_id),
    artifact_kind TEXT        NOT NULL,
    artifact_ref  TEXT        NOT NULL,
    url           TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata_json JSONB       NOT NULL DEFAULT '{}'
);

-- Free-text notes attached to tasks
CREATE TABLE IF NOT EXISTS task_notes (
    id          BIGSERIAL   PRIMARY KEY,
    project_id  UUID        NOT NULL REFERENCES projects(project_id),
    task_id     UUID        NOT NULL REFERENCES tasks(task_id),
    note        TEXT        NOT NULL,
    author_type TEXT,
    author_id   TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_projects_slug       ON projects(project_slug);
CREATE INDEX IF NOT EXISTS idx_tasks_project_id    ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_state         ON tasks(state);
CREATE INDEX IF NOT EXISTS idx_tasks_owner_id      ON tasks(owner_agent_id);
CREATE INDEX IF NOT EXISTS idx_tasks_issue         ON tasks(project_id, issue_number) WHERE issue_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_overdue       ON tasks(expected_callback_at) WHERE expected_callback_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_history_task_id     ON task_history(task_id);
CREATE INDEX IF NOT EXISTS idx_history_project_id  ON task_history(project_id);
CREATE INDEX IF NOT EXISTS idx_artifacts_task      ON task_artifacts(task_id);
CREATE INDEX IF NOT EXISTS idx_notes_task          ON task_notes(task_id);
