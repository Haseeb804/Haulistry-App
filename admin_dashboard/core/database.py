"""
Direct Neo4j connection for admin-level queries.

Actual node labels in Neo4j Aura:
  Provider   — service providers (role='provider')
  Seeker     — service customers  (role='seeker')
  Service    — services offered by providers via vehicles
  Vehicle    — vehicles owned by providers
  Booking    — always carries an extra service-type label (e.g. Booking:Harvester)
  Notification — push notifications
  AdminUser  — admin dashboard accounts only
"""

import streamlit as st
from neo4j import GraphDatabase
from typing import Any
from .config import settings


def _is_aura_uri(uri: str) -> bool:
    return uri.startswith(("neo4j+s://", "neo4j+ssc://"))


def _normalize_uri(uri: str) -> str:
    """
    neo4j+s:// fails SSL cert verification on Windows / corporate networks
    (BoltSecurityError SSLCertVerificationError). neo4j+ssc:// uses the same
    routing protocol with encryption but skips cert verification.
    """
    if uri.startswith("neo4j+s://"):
        return "neo4j+ssc://" + uri[len("neo4j+s://"):]
    return uri


@st.cache_resource(show_spinner=False)
def get_driver():
    """
    Mirrors backend _initialize(): create driver with NO connectivity probe.
    Routing is resolved lazily on first query.
    """
    uri = _normalize_uri(settings.neo4j_uri)
    try:
        driver = GraphDatabase.driver(
            uri,
            auth=(settings.neo4j_username, settings.neo4j_password),
            max_connection_lifetime=3600,
            max_connection_pool_size=50,
            connection_acquisition_timeout=60,
        )
        return driver
    except Exception:
        return None


def _open_session(driver):
    if _is_aura_uri(settings.neo4j_uri):
        return driver.session()
    return driver.session(database=settings.neo4j_database)


def run_query(
    cypher: str,
    params: dict | None = None,
    write: bool = False,
) -> list[dict]:
    driver = get_driver()
    if driver is None:
        return []
    params = params or {}

    def _tx(tx):
        return [dict(r) for r in tx.run(cypher, **params)]

    try:
        with _open_session(driver) as session:
            return session.execute_write(_tx) if write else session.execute_read(_tx)
    except Exception:
        return []


def is_connected() -> bool:
    driver = get_driver()
    if driver is None:
        return False
    try:
        with _open_session(driver) as s:
            r = s.run("RETURN 1 AS n").single()
            return bool(r and r["n"] == 1)
    except Exception:
        return False


# ─── Platform Statistics ──────────────────────────────────────────────────────

def get_platform_stats() -> dict:
    q = """
    MATCH (p:Provider) WITH count(p) AS totalProviders
    MATCH (s:Seeker)   WITH totalProviders, count(s) AS totalSeekers
    WITH totalProviders, totalSeekers, (totalProviders + totalSeekers) AS totalUsers
    OPTIONAL MATCH (b) WHERE any(lbl IN labels(b) WHERE lbl STARTS WITH 'Booking')
    WITH totalUsers, totalProviders, totalSeekers, count(b) AS totalBookings
    OPTIONAL MATCH (cb)
    WHERE any(lbl IN labels(cb) WHERE lbl STARTS WITH 'Booking')
      AND cb.status = 'completed'
    WITH totalUsers, totalProviders, totalSeekers, totalBookings,
         count(cb) AS completedBookings
    OPTIONAL MATCH (pb:Provider)
    WHERE pb.isVerified IS NULL OR pb.isVerified = false
    WITH totalUsers, totalProviders, totalSeekers,
         totalBookings, completedBookings, count(pb) AS pendingVerifications
    RETURN totalUsers, totalProviders, totalSeekers,
           totalBookings, completedBookings, pendingVerifications
    """
    rows = run_query(q)
    return rows[0] if rows else {}


def get_revenue_stats() -> dict:
    q = """
    MATCH (b)
    WHERE any(lbl IN labels(b) WHERE lbl STARTS WITH 'Booking')
      AND b.status = 'completed'
    RETURN
      sum(COALESCE(b.finalPrice, b.estimatedPrice, 0)) AS totalRevenue,
      avg(COALESCE(b.finalPrice, b.estimatedPrice, 0)) AS avgBookingValue,
      count(b) AS completedCount
    """
    rows = run_query(q)
    return rows[0] if rows else {}


def get_bookings_by_status() -> list[dict]:
    q = """
    MATCH (b) WHERE any(lbl IN labels(b) WHERE lbl STARTS WITH 'Booking')
    RETURN b.status AS status, count(b) AS count
    ORDER BY count DESC
    """
    return run_query(q)


def get_bookings_trend(days: int = 30) -> list[dict]:
    q = """
    MATCH (b)
    WHERE any(lbl IN labels(b) WHERE lbl STARTS WITH 'Booking')
      AND b.createdAt >= datetime() - duration({days: $days})
    RETURN date(b.createdAt) AS date, count(b) AS bookings
    ORDER BY date ASC
    """
    return run_query(q, {"days": days})


def get_services_by_category() -> list[dict]:
    q = """
    MATCH (s:Service {isActive: true})
    RETURN s.category AS category, count(s) AS count
    ORDER BY count DESC
    """
    return run_query(q)


# ─── Users ────────────────────────────────────────────────────────────────────

def get_all_users(role: str | None = None, page: int = 0, size: int = 50) -> list[dict]:
    if role == "provider":
        match_clause = "MATCH (u:Provider)"
    elif role == "seeker":
        match_clause = "MATCH (u:Seeker)"
    else:
        match_clause = "MATCH (u:Provider|Seeker)"

    q = f"""
    {match_clause}
    RETURN u.id AS id, u.name AS name, u.email AS email,
           u.phone AS phone, u.role AS role,
           u.isVerified AS isVerified, u.isActive AS isActive,
           u.rating AS rating, u.createdAt AS createdAt,
           u.profileImageUrl AS profileImageUrl,
           u.rejectionReason AS rejectionReason
    ORDER BY u.createdAt DESC
    SKIP $skip LIMIT $limit
    """
    return run_query(q, {"skip": page * size, "limit": size})


def get_user_detail(user_id: str) -> dict:
    q = """
    MATCH (u {id: $id})
    WHERE u:Provider OR u:Seeker OR u:User
    OPTIONAL MATCH (u)-[:OWNS]->(v:Vehicle)
    OPTIONAL MATCH (u)-[:OFFERS]->(s:Service)
    WITH u,
         collect(DISTINCT {id: v.id, type: v.vehicleType, number: v.vehicleNumber,
                            isAvailable: v.isAvailable}) AS vehicles,
         collect(DISTINCT {id: s.id, name: s.name, category: s.category,
                            isActive: s.isActive}) AS services
    RETURN u.id AS id, u.name AS name, u.email AS email,
           u.phone AS phone, u.role AS role,
           u.isVerified AS isVerified, u.isActive AS isActive,
           u.rating AS rating, u.cnic AS cnic,
           u.createdAt AS createdAt, u.updatedAt AS updatedAt,
           u.profileImageUrl AS profileImageUrl,
           u.latitude AS latitude, u.longitude AS longitude,
           u.rejectionReason AS rejectionReason,
           vehicles, services
    """
    rows = run_query(q, {"id": user_id})
    return rows[0] if rows else {}


def get_pending_providers() -> list[dict]:
    q = """
    MATCH (p:Provider)
    WHERE p.isVerified IS NULL OR p.isVerified = false
    OPTIONAL MATCH (p)-[:OWNS]->(v:Vehicle)
    WITH p, count(v) AS vehicleCount
    RETURN p.id AS id, p.name AS name, p.email AS email,
           p.phone AS phone, p.cnic AS cnic,
           p.isVerified AS isVerified, p.isActive AS isActive,
           p.createdAt AS createdAt,
           p.profileImageUrl AS profileImageUrl,
           p.vehicleImageBase64 AS vehicleImageBase64,
           p.vehicleLicenseImageBase64 AS vehicleLicenseImageBase64,
           vehicleCount
    ORDER BY p.createdAt DESC
    """
    return run_query(q)


def verify_provider(provider_id: str) -> bool:
    q = """
    MATCH (p {id: $id}) WHERE p:Provider OR p:User
    SET p.isVerified = true,
        p.isActive   = true,
        p.rejectionReason = null,
        p.verifiedAt = datetime(),
        p.updatedAt  = datetime()
    RETURN p.id AS id
    """
    rows = run_query(q, {"id": provider_id}, write=True)
    return bool(rows)


def reject_provider(provider_id: str, reason: str) -> bool:
    q = """
    MATCH (p {id: $id}) WHERE p:Provider OR p:User
    SET p.isVerified = false,
        p.isActive   = false,
        p.rejectionReason = $reason,
        p.updatedAt  = datetime()
    RETURN p.id AS id
    """
    rows = run_query(q, {"id": provider_id, "reason": reason}, write=True)
    return bool(rows)


# ─── Bookings ─────────────────────────────────────────────────────────────────

def get_all_bookings(status: str | None = None, page: int = 0, size: int = 50) -> list[dict]:
    status_filter = "AND b.status = $status" if status else ""
    q = f"""
    MATCH (b)
    WHERE any(lbl IN labels(b) WHERE lbl STARTS WITH 'Booking') {status_filter}
    OPTIONAL MATCH (seeker)
    WHERE (seeker:Seeker OR seeker:Provider OR seeker:User) AND seeker.id = b.seekerId
    OPTIONAL MATCH (provider)
    WHERE (provider:Provider OR provider:Seeker OR provider:User) AND provider.id = b.providerId
    RETURN b.id AS id, b.status AS status,
           b.seekerId AS seekerId,
           COALESCE(b.seekerName, seeker.name, '—') AS seekerName,
           b.providerId AS providerId,
           COALESCE(b.providerName, provider.name, '—') AS providerName,
           b.serviceType AS serviceType,
           b.pickupAddress AS pickupAddress, b.dropAddress AS dropAddress,
           b.estimatedPrice AS estimatedPrice, b.finalPrice AS finalPrice,
           b.distanceInKm AS distanceInKm,
           b.createdAt AS createdAt, b.updatedAt AS updatedAt,
           b.scheduledDateTime AS scheduledDateTime
    ORDER BY b.createdAt DESC
    SKIP $skip LIMIT $limit
    """
    params: dict[str, Any] = {"skip": page * size, "limit": size}
    if status:
        params["status"] = status
    return run_query(q, params)


# ─── Services ─────────────────────────────────────────────────────────────────

def get_all_services(active_only: bool = False, page: int = 0, size: int = 50) -> list[dict]:
    active_prop = " {isActive: true}" if active_only else ""
    q = f"""
    MATCH (p:Provider|Seeker)-[:OFFERS]->(s:Service{active_prop})
    OPTIONAL MATCH (v:Vehicle)-[:PROVIDES]->(s)
    RETURN s.id AS id, s.name AS name, s.category AS category,
           s.basePrice AS basePrice, s.pricePerKm AS pricePerKm,
           s.pricePerHour AS pricePerHour, s.isActive AS isActive,
           s.createdAt AS createdAt,
           p.id AS providerId, p.name AS providerName,
           v.vehicleType AS vehicleType, v.vehicleNumber AS vehicleNumber
    ORDER BY s.createdAt DESC
    SKIP $skip LIMIT $limit
    """
    return run_query(q, {"skip": page * size, "limit": size})


# ─── Vehicles ─────────────────────────────────────────────────────────────────

def get_all_vehicles(page: int = 0, size: int = 50) -> list[dict]:
    q = """
    MATCH (p:Provider|Seeker)-[:OWNS]->(v:Vehicle)
    RETURN v.id AS id, v.vehicleType AS vehicleType,
           v.vehicleNumber AS vehicleNumber, v.vehicleModel AS vehicleModel,
           v.vehicleYear AS vehicleYear, v.capacity AS capacity,
           v.isAvailable AS isAvailable,
           v.createdAt AS createdAt,
           p.id AS providerId, p.name AS providerName
    ORDER BY v.createdAt DESC
    SKIP $skip LIMIT $limit
    """
    return run_query(q, {"skip": page * size, "limit": size})


# ─── Feedback ─────────────────────────────────────────────────────────────────

def get_all_feedback(page: int = 0, size: int = 50) -> list[dict]:
    q = """
    MATCH (f:Feedback)
    RETURN f.id AS id, f.bookingId AS bookingId,
           f.providerId AS providerId, f.seekerId AS seekerId,
           f.rating AS rating, f.comment AS comment,
           f.reviewerType AS reviewerType,
           f.createdAt AS createdAt
    ORDER BY f.createdAt DESC
    SKIP $skip LIMIT $limit
    """
    return run_query(q, {"skip": page * size, "limit": size})


# ─── Provider Performance ─────────────────────────────────────────────────────

def get_provider_performance(provider_id: str) -> dict:
    q = """
    MATCH (p {id: $id}) WHERE p:Provider OR p:Seeker OR p:User
    WITH p
    OPTIONAL MATCH (b)
    WHERE any(lbl IN labels(b) WHERE lbl STARTS WITH 'Booking')
      AND b.providerId = $id AND b.status = 'completed'
    WITH p, count(b) AS completedJobs,
         sum(COALESCE(b.finalPrice, b.estimatedPrice, 0)) AS totalEarnings
    OPTIONAL MATCH (cb)
    WHERE any(lbl IN labels(cb) WHERE lbl STARTS WITH 'Booking')
      AND cb.providerId = $id AND cb.status = 'cancelled'
    WITH p, completedJobs, totalEarnings, count(cb) AS cancelledJobs
    OPTIONAL MATCH (f:Feedback {providerId: $id})
    RETURN p.name AS name, p.rating AS rating,
           completedJobs, cancelledJobs, totalEarnings,
           avg(f.rating) AS avgRating,
           count(f) AS reviewCount
    """
    rows = run_query(q, {"id": provider_id})
    return rows[0] if rows else {}


def get_top_providers(limit: int = 10) -> list[dict]:
    q = """
    MATCH (p:Provider {isVerified: true})
    OPTIONAL MATCH (b)
    WHERE any(lbl IN labels(b) WHERE lbl STARTS WITH 'Booking')
      AND b.providerId = p.id AND b.status = 'completed'
    WITH p, count(b) AS completedJobs,
         sum(COALESCE(b.finalPrice, b.estimatedPrice, 0)) AS earnings
    RETURN p.id AS id, p.name AS name, p.rating AS rating,
           p.email AS email, completedJobs, earnings
    ORDER BY completedJobs DESC
    LIMIT $limit
    """
    return run_query(q, {"limit": limit})


def toggle_user_status(user_id: str, active: bool) -> bool:
    q = """
    MATCH (u {id: $id})
    WHERE u:Provider OR u:Seeker OR u:User
    SET u.isActive = $active, u.updatedAt = datetime()
    RETURN u.id AS id
    """
    rows = run_query(q, {"id": user_id, "active": active}, write=True)
    return bool(rows)


def toggle_service_status(service_id: str, active: bool) -> bool:
    q = """
    MATCH (s:Service {id: $id})
    SET s.isActive = $active, s.updatedAt = datetime()
    RETURN s.id AS id
    """
    rows = run_query(q, {"id": service_id, "active": active}, write=True)
    return bool(rows)


def get_recent_activity(limit: int = 20) -> list[dict]:
    q = """
    MATCH (b)
    WHERE any(lbl IN labels(b) WHERE lbl STARTS WITH 'Booking')
    OPTIONAL MATCH (seeker)
    WHERE (seeker:Seeker OR seeker:Provider OR seeker:User) AND seeker.id = b.seekerId
    RETURN 'booking' AS type, b.id AS id,
           b.status AS status,
           COALESCE(b.seekerName, seeker.name, 'Unknown') AS actor,
           COALESCE(b.serviceType, '—') AS detail,
           b.createdAt AS timestamp
    ORDER BY b.createdAt DESC
    LIMIT $limit
    """
    return run_query(q, {"limit": limit})


def get_revenue_by_category() -> list[dict]:
    q = """
    MATCH (b)
    WHERE any(lbl IN labels(b) WHERE lbl STARTS WITH 'Booking')
      AND b.status = 'completed'
    RETURN COALESCE(b.serviceType, 'other') AS category,
           count(b) AS bookings,
           sum(COALESCE(b.finalPrice, b.estimatedPrice, 0)) AS revenue
    ORDER BY revenue DESC
    """
    return run_query(q)


def get_daily_revenue(days: int = 30) -> list[dict]:
    q = """
    MATCH (b)
    WHERE any(lbl IN labels(b) WHERE lbl STARTS WITH 'Booking')
      AND b.status = 'completed'
      AND b.updatedAt >= datetime() - duration({days: $days})
    RETURN date(b.updatedAt) AS date,
           count(b) AS bookings,
           sum(COALESCE(b.finalPrice, b.estimatedPrice, 0)) AS revenue
    ORDER BY date ASC
    """
    return run_query(q, {"days": days})


# ─── Notifications ────────────────────────────────────────────────────────────

def get_notifications_all(limit: int = 100) -> list[dict]:
    q = """
    MATCH (n:Notification)
    RETURN n.id AS id, n.userId AS userId, n.title AS title,
           n.body AS body, n.type AS type, n.isRead AS isRead,
           n.createdAt AS createdAt
    ORDER BY n.createdAt DESC
    LIMIT $limit
    """
    return run_query(q, {"limit": limit})


# ─── Admin User Management ────────────────────────────────────────────────────

def get_admin_user(username: str) -> dict | None:
    q = """
    MATCH (a:AdminUser {username: $username})
    RETURN a.id AS id, a.username AS username, a.email AS email,
           a.passwordHash AS passwordHash, a.firebaseUid AS firebaseUid,
           a.role AS role, a.isActive AS isActive, a.createdAt AS createdAt
    """
    rows = run_query(q, {"username": username})
    return rows[0] if rows else None


def get_admin_user_by_email(email: str) -> dict | None:
    q = """
    MATCH (a:AdminUser {email: $email})
    RETURN a.id AS id, a.username AS username, a.email AS email,
           a.passwordHash AS passwordHash, a.firebaseUid AS firebaseUid,
           a.role AS role, a.isActive AS isActive, a.createdAt AS createdAt
    """
    rows = run_query(q, {"email": email})
    return rows[0] if rows else None


def get_admin_user_by_firebase_uid(uid: str) -> dict | None:
    q = """
    MATCH (a:AdminUser {firebaseUid: $uid})
    RETURN a.id AS id, a.username AS username, a.email AS email,
           a.passwordHash AS passwordHash, a.firebaseUid AS firebaseUid,
           a.role AS role, a.isActive AS isActive, a.createdAt AS createdAt
    """
    rows = run_query(q, {"uid": uid})
    return rows[0] if rows else None


def create_admin_user(
    username: str,
    email: str,
    password_hash: str,
    firebase_uid: str | None = None,
) -> bool:
    import uuid
    node_id = str(uuid.uuid4())
    q = """
    MERGE (a:AdminUser {username: $username})
    ON CREATE SET
        a.id           = $id,
        a.email        = $email,
        a.passwordHash = $passwordHash,
        a.firebaseUid  = $firebaseUid,
        a.role         = 'admin',
        a.isActive     = true,
        a.createdAt    = datetime()
    ON MATCH SET
        a.email        = $email,
        a.passwordHash = $passwordHash,
        a.firebaseUid  = COALESCE($firebaseUid, a.firebaseUid),
        a.updatedAt    = datetime()
    RETURN a.id AS id
    """
    rows = run_query(q, {
        "username": username, "email": email,
        "passwordHash": password_hash,
        "firebaseUid": firebase_uid,
        "id": node_id,
    }, write=True)
    if rows:
        return True
    verify = get_admin_user(username)
    return verify is not None


def admin_user_count() -> int:
    q = "MATCH (a:AdminUser) RETURN count(a) AS total"
    rows = run_query(q)
    return int(rows[0].get("total", 0)) if rows else 0


def get_all_admin_users() -> list[dict]:
    q = """
    MATCH (a:AdminUser)
    RETURN a.id AS id, a.username AS username, a.email AS email,
           a.role AS role, a.isActive AS isActive, a.createdAt AS createdAt
    ORDER BY a.createdAt ASC
    """
    return run_query(q)


def toggle_admin_user(admin_id: str, active: bool) -> bool:
    q = """
    MATCH (a:AdminUser {id: $id})
    SET a.isActive = $active, a.updatedAt = datetime()
    RETURN a.id AS id
    """
    rows = run_query(q, {"id": admin_id, "active": active}, write=True)
    return bool(rows)


def delete_admin_user(admin_id: str) -> bool:
    q = "MATCH (a:AdminUser {id: $id}) DELETE a RETURN count(*) AS deleted"
    rows = run_query(q, {"id": admin_id}, write=True)
    return bool(rows)


# ─── Provider Transactions & Earnings ────────────────────────────────────────

PLATFORM_COMMISSION_RATE = 0.10  # 10 % platform fee

def get_all_providers_earnings(page: int = 0, size: int = 100) -> list[dict]:
    """
    Aggregated earnings for every provider, sorted by gross earnings descending.
    Returns: providerId, providerName, providerEmail, isVerified, isActive,
             completedBookings, grossEarnings, commission, netEarnings,
             pendingBookings, pendingValue
    """
    q = """
    MATCH (p:Provider)
    OPTIONAL MATCH (cb)
    WHERE any(lbl IN labels(cb) WHERE lbl STARTS WITH 'Booking')
      AND cb.providerId = p.id AND cb.status = 'completed'
    WITH p,
         count(cb) AS completedBookings,
         sum(COALESCE(cb.finalPrice, cb.estimatedPrice, 0)) AS grossEarnings
    OPTIONAL MATCH (pb)
    WHERE any(lbl IN labels(pb) WHERE lbl STARTS WITH 'Booking')
      AND pb.providerId = p.id
      AND pb.status IN ['accepted','active','in_progress',
                        'provider_arriving','provider_arrived']
    WITH p, completedBookings, grossEarnings,
         count(pb)  AS pendingBookings,
         sum(COALESCE(pb.estimatedPrice, 0)) AS pendingValue
    RETURN p.id          AS providerId,
           p.name        AS providerName,
           p.email       AS providerEmail,
           p.isVerified  AS isVerified,
           p.isActive    AS isActive,
           completedBookings,
           grossEarnings,
           grossEarnings * 0.10 AS commission,
           grossEarnings * 0.90 AS netEarnings,
           pendingBookings,
           pendingValue
    ORDER BY grossEarnings DESC
    SKIP $skip LIMIT $limit
    """
    return run_query(q, {"skip": page * size, "limit": size})


def get_provider_earnings_summary(provider_id: str) -> dict:
    """Complete earnings summary for one provider."""
    q = """
    MATCH (p) WHERE (p:Provider OR p:Seeker) AND p.id = $id
    OPTIONAL MATCH (cb)
    WHERE any(lbl IN labels(cb) WHERE lbl STARTS WITH 'Booking')
      AND cb.providerId = $id AND cb.status = 'completed'
    WITH p,
         count(cb) AS completedBookings,
         sum(COALESCE(cb.finalPrice, cb.estimatedPrice, 0)) AS grossEarnings
    OPTIONAL MATCH (pb)
    WHERE any(lbl IN labels(pb) WHERE lbl STARTS WITH 'Booking')
      AND pb.providerId = $id
      AND pb.status IN ['accepted','active','in_progress',
                        'provider_arriving','provider_arrived']
    WITH p, completedBookings, grossEarnings,
         count(pb)  AS pendingBookings,
         sum(COALESCE(pb.estimatedPrice, 0)) AS pendingValue
    OPTIONAL MATCH (ab)
    WHERE any(lbl IN labels(ab) WHERE lbl STARTS WITH 'Booking')
      AND ab.providerId = $id
    OPTIONAL MATCH (xb)
    WHERE any(lbl IN labels(xb) WHERE lbl STARTS WITH 'Booking')
      AND xb.providerId = $id AND xb.status = 'cancelled'
    RETURN p.name       AS name,
           p.email      AS email,
           p.isVerified AS isVerified,
           completedBookings,
           grossEarnings,
           grossEarnings * 0.10 AS commission,
           grossEarnings * 0.90 AS netEarnings,
           pendingBookings,
           pendingValue,
           count(DISTINCT ab) AS totalBookings,
           count(DISTINCT xb) AS cancelledBookings
    """
    rows = run_query(q, {"id": provider_id})
    return rows[0] if rows else {}


def get_provider_transactions(
    provider_id: str, page: int = 0, size: int = 50, status: str | None = None
) -> list[dict]:
    """All bookings for a provider with payment details, newest first."""
    status_filter = "AND b.status = $status" if status else ""
    q = f"""
    MATCH (b)
    WHERE any(lbl IN labels(b) WHERE lbl STARTS WITH 'Booking')
      AND b.providerId = $id {status_filter}
    OPTIONAL MATCH (sk)
    WHERE (sk:Seeker OR sk:User) AND sk.id = b.seekerId
    RETURN b.id        AS id,
           b.status    AS status,
           b.serviceType AS serviceType,
           COALESCE(b.seekerName, sk.name, '—') AS seekerName,
           COALESCE(b.finalPrice, b.estimatedPrice, 0) AS amount,
           b.finalPrice      AS finalPrice,
           b.estimatedPrice  AS estimatedPrice,
           b.distanceInKm    AS distanceKm,
           b.pickupAddress   AS pickupAddress,
           b.createdAt       AS createdAt,
           b.updatedAt       AS updatedAt
    ORDER BY b.createdAt DESC
    SKIP $skip LIMIT $limit
    """
    params: dict[str, Any] = {"id": provider_id, "skip": page * size, "limit": size}
    if status:
        params["status"] = status
    return run_query(q, params)


def get_provider_monthly_earnings(provider_id: str, months: int = 12) -> list[dict]:
    """Monthly completed-earnings breakdown for a provider (last N months)."""
    q = """
    MATCH (b)
    WHERE any(lbl IN labels(b) WHERE lbl STARTS WITH 'Booking')
      AND b.providerId = $id
      AND b.status = 'completed'
      AND b.updatedAt >= datetime() - duration({months: $months})
    RETURN date.truncate('month', date(b.updatedAt)) AS month,
           count(b) AS bookings,
           sum(COALESCE(b.finalPrice, b.estimatedPrice, 0)) AS revenue
    ORDER BY month ASC
    """
    return run_query(q, {"id": provider_id, "months": months})


def count_provider_transactions(provider_id: str, status: str | None = None) -> int:
    """Total booking count for a provider (used for pagination)."""
    status_filter = "AND b.status = $status" if status else ""
    q = f"""
    MATCH (b)
    WHERE any(lbl IN labels(b) WHERE lbl STARTS WITH 'Booking')
      AND b.providerId = $id {status_filter}
    RETURN count(b) AS total
    """
    params: dict[str, Any] = {"id": provider_id}
    if status:
        params["status"] = status
    rows = run_query(q, params)
    return int(rows[0].get("total", 0)) if rows else 0
