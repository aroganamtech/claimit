"""
Vercel serverless entry point for the Claimit Web Backend.

Vercel looks for a callable named `app` (any ASGI app) in api/index.py.
We add the project root to sys.path so `app.*` imports resolve, then
re-export the FastAPI instance.
"""

import sys
import os

# Make sure the project root (parent of api/) is importable
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.main import app  # noqa: F401  — Vercel picks this up automatically
