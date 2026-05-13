"""
Recommendation model — scored service suggestions for seekers.

Scoring weights:
  3.0  — service category matches seeker's explicit interest
  2.0  — service category matches a category the seeker has previously booked
  0.0–1.0  — provider rating bonus (rating / 5.0)
  0.0–0.5  — recency bonus (newer services score higher, max 0.5)

Results are de-duplicated, capped at 15, and sorted by descending total score.
"""

from typing import List, Dict, Any, Optional
from ..database import neo4j_driver


class Recommendation:

    @staticmethod
    def get_for_seeker(seeker_id: str, limit: int = 15) -> List[Dict[str, Any]]:
        """
        Return scored, de-duplicated service recommendations for a seeker.
        Combines interest-match, booking-history match, provider quality, and recency.
        """
        query = """
        // ── 1. Seeker interests ───────────────────────────────────────────────
        // Support both Seeker and User labels (legacy nodes may carry either).
        MATCH (seeker)
        WHERE (seeker:Seeker OR seeker:User) AND seeker.id = $seekerId
        WITH seeker,
             coalesce(seeker.interests, []) AS interests

        // Past booking categories — use the Booking index, no full-graph scan.
        OPTIONAL MATCH (b:Booking {seekerId: $seekerId, status: 'completed'})
        WITH interests,
             collect(DISTINCT b.serviceType)[..20] AS bookedCategories

        // ── 2. Active services from verified providers only ───────────────────
        MATCH (svc:Service {isActive: true})
        MATCH (prov {id: svc.providerId})
        WHERE (prov:Provider OR prov:Seeker OR prov:User)
          AND coalesce(prov.isVerified, false) = true

        // ── 3. Scoring ────────────────────────────────────────────────────────
        WITH svc, prov, interests, bookedCategories,

             CASE WHEN svc.category IN interests THEN 3.0 ELSE 0.0 END
               AS interestScore,

             CASE WHEN svc.category IN bookedCategories THEN 2.0 ELSE 0.0 END
               AS historyScore,

             coalesce(prov.rating, 0.0) / 5.0 AS qualityScore,

             CASE
               WHEN duration.between(svc.createdAt, datetime()).days <= 7  THEN 0.5
               WHEN duration.between(svc.createdAt, datetime()).days <= 30 THEN 0.25
               ELSE 0.0
             END AS recencyScore

        WITH svc, prov,
             round((interestScore + historyScore + qualityScore + recencyScore) * 100) / 100.0
               AS totalScore

        ORDER BY totalScore DESC, svc.createdAt DESC
        LIMIT $limit

        // ── 4. Enrich with vehicle context ───────────────────────────────────
        OPTIONAL MATCH (v:Vehicle {id: svc.vehicleId})
        RETURN
            svc,
            totalScore,
            prov.name                  AS providerName,
            coalesce(prov.rating, 0.0) AS providerRating,
            prov.profileImageUrl       AS providerImageUrl,
            v.vehicleType              AS vehicleType,
            v.vehicleNumber            AS vehicleNumber,
            v.vehicleImageBase64       AS vehicleImageBase64
        ORDER BY totalScore DESC
        """

        result = neo4j_driver.execute_read(
            query, {'seekerId': seeker_id, 'limit': limit}
        )

        recommendations = []
        if result:
            for record in result:
                svc_node = record.get('svc')
                if not svc_node:
                    continue
                svc = Recommendation._serialize(dict(svc_node))
                svc['recommendationScore'] = record.get('totalScore', 0.0)
                svc['providerName']       = record.get('providerName')
                svc['providerRating']     = record.get('providerRating')
                svc['providerImageUrl']   = record.get('providerImageUrl')
                svc['vehicleType']        = record.get('vehicleType')
                svc['vehicleNumber']      = record.get('vehicleNumber')
                svc['vehicleImageBase64'] = record.get('vehicleImageBase64')
                recommendations.append(svc)

        return recommendations

    @staticmethod
    def get_by_category(category: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Return active services for a specific category (used for notification deep-link)."""
        query = """
        MATCH (svc:Service {isActive: true, category: $category})
        OPTIONAL MATCH (prov)
        WHERE (prov:Provider OR prov:Seeker OR prov:User) AND prov.id = svc.providerId
          AND coalesce(prov.isVerified, false) = true
        OPTIONAL MATCH (v:Vehicle {id: svc.vehicleId})
        RETURN svc,
               prov.name            AS providerName,
               coalesce(prov.rating, 0.0) AS providerRating,
               prov.profileImageUrl AS providerImageUrl,
               v.vehicleType        AS vehicleType,
               v.vehicleImageBase64 AS vehicleImageBase64
        ORDER BY svc.createdAt DESC
        LIMIT $limit
        """
        result = neo4j_driver.execute_read(query, {'category': category, 'limit': limit})
        services = []
        if result:
            for record in result:
                svc_node = record.get('svc') or record['svc']
                if not svc_node:
                    continue
                svc = Recommendation._serialize(dict(svc_node))
                svc['providerName']       = record.get('providerName')
                svc['providerRating']     = record.get('providerRating')
                svc['providerImageUrl']   = record.get('providerImageUrl')
                svc['vehicleType']        = record.get('vehicleType')
                svc['vehicleImageBase64'] = record.get('vehicleImageBase64')
                services.append(svc)
        return services

    @staticmethod
    def _serialize(data: Dict[str, Any]) -> Dict[str, Any]:
        """Convert Neo4j datetime types to ISO strings."""
        from neo4j.time import DateTime as Neo4jDateTime
        from datetime import datetime
        out = {}
        for k, v in data.items():
            if isinstance(v, Neo4jDateTime):
                out[k] = v.to_native().isoformat()
            elif isinstance(v, datetime):
                out[k] = v.isoformat()
            else:
                out[k] = v
        return out
