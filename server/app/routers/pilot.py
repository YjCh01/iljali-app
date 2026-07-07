"""파일럿 프로그램 — 구직자 참여 상태."""

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.services.auth_token_service import verify_token
from app.services.pilot_program_service import (
    bus_location_tower_status_for_seeker,
    update_bus_location_tower_position,
)

router = APIRouter(prefix="/v1/pilot", tags=["pilot"])


class BusLocationTowerPositionBody(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    accuracy_m: float | None = Field(default=None, ge=0, le=10000)


def _resolve_bearer(authorization: str | None) -> dict:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="인증이 필요합니다.")
    token = authorization.split(" ", 1)[1].strip()
    payload = verify_token(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="세션이 만료되었습니다.")
    return payload


@router.get("/bus-location-tower/me")
def bus_location_tower_me(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    member_type = str(payload.get("member_type", "seeker"))
    if member_type != "seeker":
        raise HTTPException(status_code=403, detail="개인회원만 이용할 수 있습니다.")
    email = str(payload.get("sub", "")).lower()
    return bus_location_tower_status_for_seeker(db, email=email)


@router.post("/bus-location-tower/location")
def bus_location_tower_location(
    body: BusLocationTowerPositionBody,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    member_type = str(payload.get("member_type", "seeker"))
    if member_type != "seeker":
        raise HTTPException(status_code=403, detail="개인회원만 이용할 수 있습니다.")
    email = str(payload.get("sub", "")).lower()
    try:
        return update_bus_location_tower_position(
            db,
            email=email,
            latitude=body.latitude,
            longitude=body.longitude,
            accuracy_m=body.accuracy_m,
        )
    except ValueError as error:
        raise HTTPException(status_code=403, detail=str(error)) from error
