"""Realtime communication package (Socket.IO + legacy WebSocket fallback)."""

from .socketio_gateway import sio

__all__ = ["sio"]
