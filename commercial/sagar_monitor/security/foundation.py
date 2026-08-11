from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping
import base64
import hashlib
import hmac
import json
import re
import secrets
import sqlite3
import uuid


MIGRATION_PATH = Path(__file__).resolve().parents[2] / "migrations" / "0005_security_foundation.sql"
ROLES = {"admin", "operator", "viewer"}
PASSWORD_MIN_LENGTH = 8


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def _utc(value: datetime | str | None = None) -> datetime:
    if value is None:
        return datetime.now(timezone.utc)
    if isinstance(value, datetime):
        result = value
    else:
        result = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if result.tzinfo is None:
        result = result.replace(tzinfo=timezone.utc)
    return result.astimezone(timezone.utc)


def _iso(value: datetime | str | None = None) -> str:
    return _utc(value).isoformat()


def _sha256(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _normalize_username(value: object) -> str:
    username = str(value or "").strip().lower()
    if not re.fullmatch(r"[a-z0-9][a-z0-9._-]{2,63}", username):
        raise ValueError("username must be 3-64 characters using letters, numbers, dot, underscore or hyphen")
    return username


def validate_password_strength(password: str) -> None:
    value = str(password or "")
    if len(value) < PASSWORD_MIN_LENGTH:
        raise ValueError(f"password must be at least {PASSWORD_MIN_LENGTH} characters")
    classes = (
        any(ch.islower() for ch in value),
        any(ch.isupper() for ch in value),
        any(ch.isdigit() for ch in value),
        any(not ch.isalnum() for ch in value),
    )
    if sum(classes) < 3:
        raise ValueError("password must contain at least three character classes")
    common = {"admin@12345", "password", "password123", "qwerty123", "letmein"}
    if value.lower() in common:
        raise ValueError("common/default passwords are forbidden")


def hash_password(password: str, *, salt: bytes | None = None) -> str:
    validate_password_strength(password)
    salt = salt or secrets.token_bytes(16)
    n, r, p = 2**14, 8, 1
    digest = hashlib.scrypt(password.encode("utf-8"), salt=salt, n=n, r=r, p=p, dklen=32)
    return f"scrypt${n}${r}${p}${_b64(salt)}${_b64(digest)}"


def verify_password(password: str, stored: str) -> bool:
    try:
        algorithm, n, r, p, salt_text, expected = stored.split("$", 5)
        if algorithm != "scrypt":
            return False
        salt = base64.urlsafe_b64decode(salt_text + "=" * (-len(salt_text) % 4))
        digest = hashlib.scrypt(
            str(password).encode("utf-8"),
            salt=salt,
            n=int(n),
            r=int(r),
            p=int(p),
            dklen=32,
        )
        return hmac.compare_digest(_b64(digest), expected)
    except (ValueError, TypeError, MemoryError):
        return False


def apply_security_migration(connection: sqlite3.Connection) -> None:
    connection.execute("PRAGMA foreign_keys=ON")
    connection.executescript(MIGRATION_PATH.read_text(encoding="utf-8"))


def create_organization(
    connection: sqlite3.Connection,
    *,
    name: str,
    organization_id: str | None = None,
    now: datetime | str | None = None,
) -> str:
    apply_security_migration(connection)
    clean_name = str(name or "").strip()
    if len(clean_name) < 2:
        raise ValueError("organization name is required")
    organization_id = organization_id or str(uuid.uuid4())
    connection.execute(
        "INSERT INTO organizations_v1(organization_id,name,status,created_at) VALUES(?,?,'active',?)",
        (organization_id, clean_name, _iso(now)),
    )
    connection.commit()
    return organization_id


def create_user(
    connection: sqlite3.Connection,
    *,
    organization_id: str,
    username: str,
    password: str,
    role: str,
    status: str = "active",
    user_id: str | None = None,
    now: datetime | str | None = None,
) -> str:
    apply_security_migration(connection)
    clean_role = str(role or "").strip().lower()
    if clean_role not in ROLES:
        raise ValueError(f"role must be one of {sorted(ROLES)}")
    clean_status = str(status or "").strip().lower()
    if clean_status not in {"active", "disabled"}:
        raise ValueError("status must be active or disabled")
    clean_username = _normalize_username(username)
    password_hash = hash_password(password)
    user_id = user_id or str(uuid.uuid4())
    connection.execute(
        """
        INSERT INTO users_v1(user_id,organization_id,username,password_hash,role,status,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?)
        """,
        (
            user_id,
            organization_id,
            clean_username,
            password_hash,
            clean_role,
            clean_status,
            _iso(now),
            _iso(now),
        ),
    )
    connection.commit()
    return user_id


def authenticate_user(
    connection: sqlite3.Connection,
    *,
    organization_id: str,
    username: str,
    password: str,
) -> dict[str, Any] | None:
    clean_username = _normalize_username(username)
    row = connection.execute(
        """
        SELECT user_id,organization_id,username,password_hash,role,status
        FROM users_v1
        WHERE organization_id=? AND username=?
        """,
        (organization_id, clean_username),
    ).fetchone()
    if row is None or str(row[5]) != "active" or not verify_password(password, str(row[3])):
        return None
    return {
        "user_id": str(row[0]),
        "organization_id": str(row[1]),
        "username": str(row[2]),
        "role": str(row[4]),
        "status": str(row[5]),
    }


@dataclass(frozen=True)
class SessionTokens:
    session_token: str
    csrf_token: str
    expires_at: str


def create_session(
    connection: sqlite3.Connection,
    *,
    user_id: str,
    ttl_seconds: int,
    client_fingerprint: str = "",
    now: datetime | str | None = None,
) -> SessionTokens:
    apply_security_migration(connection)
    ttl_seconds = int(ttl_seconds)
    if ttl_seconds < 60 or ttl_seconds > 86_400:
        raise ValueError("session ttl must be between 60 and 86400 seconds")
    current = _utc(now)
    expires = current + timedelta(seconds=ttl_seconds)
    session_token = secrets.token_urlsafe(48)
    csrf_token = secrets.token_urlsafe(32)
    connection.execute(
        """
        INSERT INTO sessions_v1(
            session_hash,user_id,organization_id,csrf_hash,created_at,expires_at,last_seen_at,client_fingerprint,revoked_at
        )
        SELECT ?,user_id,organization_id,?,?,?,?,?,NULL FROM users_v1 WHERE user_id=?
        """,
        (
            _sha256(session_token),
            _sha256(csrf_token),
            _iso(current),
            _iso(expires),
            _iso(current),
            str(client_fingerprint or ""),
            user_id,
        ),
    )
    connection.commit()
    return SessionTokens(
        session_token=session_token,
        csrf_token=csrf_token,
        expires_at=_iso(expires),
    )


def validate_session(
    connection: sqlite3.Connection,
    session_token: str,
    *,
    organization_id: str | None = None,
    client_fingerprint: str = "",
    now: datetime | str | None = None,
) -> dict[str, Any] | None:
    current = _utc(now)
    row = connection.execute(
        """
        SELECT s.user_id,s.organization_id,s.expires_at,s.revoked_at,s.client_fingerprint,u.username,u.role,u.status
        FROM sessions_v1 s
        JOIN users_v1 u ON u.user_id=s.user_id
        WHERE s.session_hash=?
        """,
        (_sha256(session_token),),
    ).fetchone()
    if row is None:
        return None
    if row[3] is not None or str(row[7]) != "active" or _utc(row[2]) <= current:
        return None
    if organization_id is not None and str(row[1]) != str(organization_id):
        return None
    stored_fingerprint = str(row[4] or "")
    if stored_fingerprint and stored_fingerprint != str(client_fingerprint or ""):
        return None
    connection.execute(
        "UPDATE sessions_v1 SET last_seen_at=? WHERE session_hash=?",
        (_iso(current), _sha256(session_token)),
    )
    connection.commit()
    return {
        "user_id": str(row[0]),
        "organization_id": str(row[1]),
        "username": str(row[5]),
        "role": str(row[6]),
        "expires_at": _iso(row[2]),
    }


def revoke_session(
    connection: sqlite3.Connection,
    session_token: str,
    *,
    now: datetime | str | None = None,
) -> bool:
    cursor = connection.execute(
        "UPDATE sessions_v1 SET revoked_at=? WHERE session_hash=? AND revoked_at IS NULL",
        (_iso(now), _sha256(session_token)),
    )
    connection.commit()
    return cursor.rowcount > 0


def verify_csrf(connection: sqlite3.Connection, session_token: str, csrf_token: str) -> bool:
    row = connection.execute(
        "SELECT csrf_hash FROM sessions_v1 WHERE session_hash=? AND revoked_at IS NULL",
        (_sha256(session_token),),
    ).fetchone()
    return row is not None and hmac.compare_digest(str(row[0]), _sha256(csrf_token))


def authorize(
    session: Mapping[str, Any] | None,
    allowed_roles: Iterable[str],
    *,
    organization_id: str | None = None,
) -> bool:
    if session is None:
        return False
    allowed = {str(role).lower() for role in allowed_roles}
    if str(session.get("role", "")).lower() not in allowed:
        return False
    if organization_id is not None and str(session.get("organization_id", "")) != str(organization_id):
        return False
    return True


def create_enrollment_token(
    connection: sqlite3.Connection,
    *,
    organization_id: str,
    ttl_seconds: int,
    max_uses: int = 1,
    now: datetime | str | None = None,
) -> str:
    apply_security_migration(connection)
    ttl_seconds = int(ttl_seconds)
    max_uses = int(max_uses)
    if ttl_seconds < 60 or ttl_seconds > 86_400 * 7:
        raise ValueError("enrollment ttl must be between 60 and 604800 seconds")
    if max_uses < 1 or max_uses > 1000:
        raise ValueError("max_uses must be between 1 and 1000")
    token = secrets.token_urlsafe(48)
    current = _utc(now)
    expires = current + timedelta(seconds=ttl_seconds)
    connection.execute(
        """
        INSERT INTO enrollment_tokens_v1(
            token_hash,organization_id,created_at,expires_at,max_uses,use_count,revoked_at
        ) VALUES(?,?,?,?,?,0,NULL)
        """,
        (_sha256(token), organization_id, _iso(current), _iso(expires), max_uses),
    )
    connection.commit()
    return token


def consume_enrollment_token(
    connection: sqlite3.Connection,
    token: str,
    *,
    organization_id: str,
    now: datetime | str | None = None,
) -> dict[str, Any] | None:
    current = _utc(now)
    token_hash = _sha256(token)
    row = connection.execute(
        """
        SELECT organization_id,expires_at,max_uses,use_count,revoked_at
        FROM enrollment_tokens_v1 WHERE token_hash=?
        """,
        (token_hash,),
    ).fetchone()
    if row is None:
        return None
    if str(row[0]) != str(organization_id) or row[4] is not None or _utc(row[1]) <= current:
        return None
    if int(row[3]) >= int(row[2]):
        return None
    cursor = connection.execute(
        """
        UPDATE enrollment_tokens_v1
        SET use_count=use_count+1
        WHERE token_hash=? AND use_count < max_uses AND revoked_at IS NULL
        """,
        (token_hash,),
    )
    connection.commit()
    if cursor.rowcount != 1:
        return None
    return {
        "organization_id": str(row[0]),
        "expires_at": _iso(row[1]),
        "max_uses": int(row[2]),
        "use_count": int(row[3]) + 1,
    }


def consume_rate_limit(
    connection: sqlite3.Connection,
    key: str,
    *,
    limit: int,
    window_seconds: int,
    now: datetime | str | None = None,
) -> dict[str, Any]:
    apply_security_migration(connection)
    limit = int(limit)
    window_seconds = int(window_seconds)
    if limit < 1 or window_seconds < 1:
        raise ValueError("rate limit and window must be positive")
    current = _utc(now)
    normalized_key = _sha256(str(key))
    row = connection.execute(
        "SELECT window_started_at,count FROM rate_limits_v1 WHERE key_hash=?",
        (normalized_key,),
    ).fetchone()
    if row is None or current >= _utc(row[0]) + timedelta(seconds=window_seconds):
        connection.execute(
            """
            INSERT INTO rate_limits_v1(key_hash,window_started_at,count)
            VALUES(?,?,1)
            ON CONFLICT(key_hash) DO UPDATE SET window_started_at=excluded.window_started_at,count=1
            """,
            (normalized_key, _iso(current)),
        )
        connection.commit()
        return {"allowed": True, "remaining": max(limit - 1, 0), "reset_at": _iso(current + timedelta(seconds=window_seconds))}
    count = int(row[1])
    if count >= limit:
        return {"allowed": False, "remaining": 0, "reset_at": _iso(_utc(row[0]) + timedelta(seconds=window_seconds))}
    connection.execute(
        "UPDATE rate_limits_v1 SET count=count+1 WHERE key_hash=?",
        (normalized_key,),
    )
    connection.commit()
    return {"allowed": True, "remaining": max(limit - count - 1, 0), "reset_at": _iso(_utc(row[0]) + timedelta(seconds=window_seconds))}


def append_audit_event(
    connection: sqlite3.Connection,
    *,
    organization_id: str,
    event_type: str,
    actor_user_id: str | None = None,
    subject_id: str | None = None,
    detail: Mapping[str, Any] | None = None,
    now: datetime | str | None = None,
) -> int:
    apply_security_migration(connection)
    current = _iso(now)
    last = connection.execute(
        "SELECT sequence_id,event_hash FROM security_audit_log_v1 ORDER BY sequence_id DESC LIMIT 1"
    ).fetchone()
    previous_hash = str(last[1]) if last is not None else "GENESIS"
    payload = {
        "organization_id": str(organization_id),
        "event_type": str(event_type),
        "actor_user_id": actor_user_id,
        "subject_id": subject_id,
        "detail": dict(detail or {}),
        "occurred_at": current,
        "previous_hash": previous_hash,
    }
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    event_hash = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    cursor = connection.execute(
        """
        INSERT INTO security_audit_log_v1(
            organization_id,event_type,actor_user_id,subject_id,detail_json,occurred_at,previous_hash,event_hash
        ) VALUES(?,?,?,?,?,?,?,?)
        """,
        (
            payload["organization_id"],
            payload["event_type"],
            payload["actor_user_id"],
            payload["subject_id"],
            json.dumps(payload["detail"], sort_keys=True, separators=(",", ":"), ensure_ascii=True),
            current,
            previous_hash,
            event_hash,
        ),
    )
    connection.commit()
    return int(cursor.lastrowid)


def verify_audit_chain(connection: sqlite3.Connection) -> dict[str, Any]:
    rows = connection.execute(
        """
        SELECT sequence_id,organization_id,event_type,actor_user_id,subject_id,detail_json,occurred_at,previous_hash,event_hash
        FROM security_audit_log_v1 ORDER BY sequence_id ASC
        """
    ).fetchall()
    previous_hash = "GENESIS"
    for row in rows:
        try:
            detail = json.loads(str(row[5]))
        except (TypeError, ValueError, json.JSONDecodeError):
            return {"ok": False, "sequence_id": int(row[0]), "reason": "invalid detail json"}
        payload = {
            "organization_id": str(row[1]),
            "event_type": str(row[2]),
            "actor_user_id": row[3],
            "subject_id": row[4],
            "detail": detail,
            "occurred_at": str(row[6]),
            "previous_hash": str(row[7]),
        }
        canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        expected = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
        if str(row[7]) != previous_hash or not hmac.compare_digest(expected, str(row[8])):
            return {"ok": False, "sequence_id": int(row[0]), "reason": "audit chain mismatch"}
        previous_hash = str(row[8])
    return {"ok": True, "events": len(rows), "head": previous_hash}
