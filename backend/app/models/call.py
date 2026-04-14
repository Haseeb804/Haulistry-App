"""
Call Model
Manages voice/video calls between users
"""
from typing import Optional, Dict, Any, List
from datetime import datetime
from ..database.neo4j_driver import neo4j_driver


class Call:
    def __init__(
        self,
        call_id: str,
        caller_id: str,
        receiver_id: str,
        booking_id: str,
        call_type: str,  # 'voice' or 'video'
        status: str,  # 'initiated', 'ringing', 'answered', 'ended', 'missed', 'rejected'
        started_at: Optional[datetime] = None,
        ended_at: Optional[datetime] = None,
        duration: int = 0,  # in seconds
        agora_channel: Optional[str] = None,
        agora_token: Optional[str] = None
    ):
        self.call_id = call_id
        self.caller_id = caller_id
        self.receiver_id = receiver_id
        self.booking_id = booking_id
        self.call_type = call_type
        self.status = status
        self.started_at = started_at or datetime.now()
        self.ended_at = ended_at
        self.duration = duration
        self.agora_channel = agora_channel
        self.agora_token = agora_token

    @staticmethod
    def create_call(
        caller_id: str,
        receiver_id: str,
        booking_id: str,
        call_type: str,
        agora_channel: str,
        agora_token: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """Create a new call record"""
        query = """
        MATCH (caller) WHERE (caller:Seeker OR caller:Provider OR caller:User) AND caller.id = $callerId
        MATCH (receiver) WHERE (receiver:Seeker OR receiver:Provider OR receiver:User) AND receiver.id = $receiverId
                MATCH (b:Booking {id: $bookingId})
                WHERE toLower(coalesce(b.status, '')) IN ['confirmed', 'accepted', 'provider_arriving', 'provider_arrived', 'in_progress']
                    AND (
                        (b.seekerId = $callerId AND b.providerId = $receiverId)
                        OR
                        (b.providerId = $callerId AND b.seekerId = $receiverId)
                    )
        
        CREATE (c:Call {
            id: randomUUID(),
            callerId: $callerId,
            receiverId: $receiverId,
            bookingId: $bookingId,
            callType: $callType,
            status: 'initiated',
            startedAt: datetime(),
            agoraChannel: $agoraChannel,
            agoraToken: $agoraToken
        })
        
        CREATE (c)-[:CALL_FROM]->(caller)
        CREATE (c)-[:CALL_TO]->(receiver)
        CREATE (c)-[:FOR_BOOKING]->(b)
        
        RETURN c, caller.name as callerName, receiver.name as receiverName,
               CASE WHEN caller:Provider THEN 'provider' WHEN caller:Seeker THEN 'seeker' ELSE coalesce(caller.role, 'user') END as callerRole,
               CASE WHEN receiver:Provider THEN 'provider' WHEN receiver:Seeker THEN 'seeker' ELSE coalesce(receiver.role, 'user') END as receiverRole
        """
        
        params = {
            "callerId": caller_id,
            "receiverId": receiver_id,
            "bookingId": booking_id,
            "callType": call_type,
            "agoraChannel": agora_channel,
            "agoraToken": agora_token
        }
        
        result = neo4j_driver.execute_write(query, params)
        
        if result and len(result) > 0:
            call_record = result[0].get('c')
            if call_record:
                call = Call._serialize_neo4j_data(call_record)
                call['callerName'] = result[0].get('callerName')
                call['receiverName'] = result[0].get('receiverName')
                call['callerRole'] = result[0].get('callerRole', 'user')
                call['receiverRole'] = result[0].get('receiverRole', 'user')
                return call
        
        return None

    @staticmethod
    def update_call_status(
        call_id: str,
        status: str,
        duration: Optional[int] = None
    ) -> bool:
        """Update call status and duration"""
        query = """
        MATCH (c:Call {id: $callId})
        SET c.status = $status
        """
        
        params = {"callId": call_id, "status": status}
        
        if status == 'answered':
            query += ", c.answeredAt = datetime()"
        elif status in ['ended', 'missed', 'rejected']:
            query += ", c.endedAt = datetime()"
            if duration is not None:
                query += ", c.duration = $duration"
                params["duration"] = duration
        
        query += " RETURN c"
        
        result = neo4j_driver.execute_write(query, params)
        return result is not None and len(result) > 0

    @staticmethod
    def get_call_history(user_id: str, limit: int = 20) -> List[Dict[str, Any]]:
        """Get call history for a user"""
        query = """
        MATCH (c:Call)
        WHERE c.callerId = $userId OR c.receiverId = $userId
        OPTIONAL MATCH (c)-[:CALL_FROM]->(caller)
        OPTIONAL MATCH (c)-[:CALL_TO]->(receiver)
        WITH c, caller.name as callerName, receiver.name as receiverName,
             CASE WHEN caller:Provider THEN 'provider' WHEN caller:Seeker THEN 'seeker' ELSE coalesce(caller.role, 'user') END as callerRole,
             CASE WHEN receiver:Provider THEN 'provider' WHEN receiver:Seeker THEN 'seeker' ELSE coalesce(receiver.role, 'user') END as receiverRole
        RETURN c, callerName, receiverName, callerRole, receiverRole
        ORDER BY c.startedAt DESC
        LIMIT $limit
        """
        
        result = neo4j_driver.execute_read(query, {"userId": user_id, "limit": limit})
        
        calls = []
        if result:
            for record in result:
                if record['c']:
                    call = Call._serialize_neo4j_data(record['c'])
                    call['callerName'] = record['callerName']
                    call['receiverName'] = record['receiverName']
                    call['callerRole'] = record.get('callerRole', 'user')
                    call['receiverRole'] = record.get('receiverRole', 'user')
                    calls.append(call)
        
        return calls

    @staticmethod
    def get_call_by_id(call_id: str) -> Optional[Dict[str, Any]]:
        """Get call details by ID"""
        query = """
        MATCH (c:Call {id: $callId})
        OPTIONAL MATCH (c)-[:CALL_FROM]->(caller)
        OPTIONAL MATCH (c)-[:CALL_TO]->(receiver)
        RETURN c, caller.name as callerName, receiver.name as receiverName,
               CASE WHEN caller:Provider THEN 'provider' WHEN caller:Seeker THEN 'seeker' ELSE coalesce(caller.role, 'user') END as callerRole,
               CASE WHEN receiver:Provider THEN 'provider' WHEN receiver:Seeker THEN 'seeker' ELSE coalesce(receiver.role, 'user') END as receiverRole
        """
        
        result = neo4j_driver.execute_read(query, {"callId": call_id})
        
        if result and len(result) > 0:
            call = Call._serialize_neo4j_data(result[0]['c'])
            call['callerName'] = result[0].get('callerName')
            call['receiverName'] = result[0].get('receiverName')
            call['callerRole'] = result[0].get('callerRole', 'user')
            call['receiverRole'] = result[0].get('receiverRole', 'user')
            return call
        
        return None

    @staticmethod
    def _serialize_neo4j_data(data: Dict[str, Any]) -> Dict[str, Any]:
        """Convert Neo4j data to JSON-serializable format"""
        result = {}
        for key, value in data.items():
            if hasattr(value, 'iso_format'):  # Neo4j DateTime
                result[key] = value.iso_format()
            else:
                result[key] = value
        return result
