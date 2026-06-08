#!/usr/bin/env python3
"""Minimal app stub — replace with your service logic."""

import os

from fastapi import FastAPI

app = FastAPI(title="__APP_NAME__")

PORT = int(os.getenv("PORT", "__APP_PORT__"))


@app.get("/health")
async def health():
    return {"status": "healthy", "app": "__APP_NAME__"}


@app.get("/")
async def root():
    return {"app": "__APP_NAME__", "health": "/health"}
