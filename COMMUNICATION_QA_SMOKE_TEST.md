# Communication QA Smoke Test (Provider ↔ Seeker)

This checklist verifies that call/message events are routed to the correct receiver, and that communication is only allowed during active service.

## Scope

- Call routing (voice/video)
- Message directionality
- Caller/receiver role behavior
- Service-status-based communication restrictions

## Test Setup

Use two real sessions/devices:

- **Device A**: Provider account
- **Device B**: Seeker account

Required:

- Both accounts authenticated
- Push notifications enabled on both devices
- Internet stable on both devices
- One shared booking between these two users

---

## Test 1 — Provider calls Seeker (routing correctness)

1. Start with booking in an active status (`accepted` / `provider_arriving` / `provider_arrived` / `in_progress`).
2. On **Device A (Provider)**, open tracking/chat and tap **Voice Call**.
3. Observe **Device A** shows outgoing/calling UI only.
4. Observe **Device B (Seeker)** receives incoming call UI.
5. Accept on Device B.

Expected:

- Incoming call screen appears on **Device B only**.
- Device A does **not** receive incoming UI for its own call.
- After accept, both enter call session.

---

## Test 2 — Seeker calls Provider (reverse routing correctness)

1. While booking is still active, on **Device B (Seeker)** initiate call.
2. Observe **Device B** shows outgoing/calling UI.
3. Observe **Device A (Provider)** receives incoming call UI.

Expected:

- Incoming call screen appears on **Device A only**.
- No loopback incoming UI on Device B.

---

## Test 3 — Reject / missed flow on caller side

1. Place call from either side.
2. On receiver device, tap **Reject** (or let it timeout).

Expected:

- Caller exits calling state cleanly.
- Caller does not remain stuck in pending ring UI.

---

## Test 4 — Messaging directionality

1. During active booking, send message from Provider to Seeker.
2. Verify message appears as incoming on Seeker side.
3. Send reply from Seeker to Provider.

Expected:

- Messages appear on opposite device only as new incoming content.
- Sender does not receive its own message as incoming event.

---

## Test 5 — Communication restriction after completion

1. Complete the active booking.
2. Re-open chat on both devices.
3. Attempt:
   - send text
   - send image/voice message
   - start voice/video call

Expected:

- Communication actions are disabled/blocked.
- User sees restriction messaging (service is not active).
- Backend rejects non-active communication attempts if manually triggered.

---

## Test 6 — Access control / participant validation

1. Attempt communication with a user not assigned as seeker/provider of the booking.

Expected:

- Backend blocks with authorization/validation failure.
- No call or message is created for invalid participant pair.

---

## Pass Criteria

Release is considered verified if all are true:

- No call notification loopback to sender
- Correct receiver gets incoming call UI in both directions
- Caller sees proper calling lifecycle until answer/reject/missed/end
- Messages are bidirectional and correctly targeted
- Communication is blocked immediately once service is completed

---

## Notes Template (fill during QA)

- Build/branch:
- Device A (Provider):
- Device B (Seeker):
- Test date/time:
- Tester:
- Result per test (1-6):
- Defects found:
- Screenshots/video refs:
