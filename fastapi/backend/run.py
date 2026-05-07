"""Entry point for development.
Run with:  python run.py
The Flutter app expects http://10.0.2.2:8001 (Android emulator) /
http://localhost:8001 (iOS simulator / web).
"""

import os

import uvicorn


if __name__ == "__main__":
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8001"))

    uvicorn.run(
        "app.main:app",
        host=host,
        port=port,
        reload=True,
        log_level="info",
    )
