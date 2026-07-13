"""Shared pytest fixtures — keep SQLite schema present across module teardowns."""

import os

import pytest

from app.database import Base, engine

# Avoid live OSRM calls during unit/e2e tests (straight-line densify still runs).
os.environ.setdefault("ROUTE_GEOMETRY_PROVIDER", "straight")


@pytest.fixture(autouse=True)
def _ensure_db_schema():
    """Recreate tables if a prior test module called drop_all."""
    Base.metadata.create_all(bind=engine)
    yield
