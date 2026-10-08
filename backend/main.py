"""Clinical-AI API entry point."""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from config import get_settings
from database import close_database_connection, connect_to_database, database_is_healthy
from routes import auth, diseases, predictions, symptoms, users
from services.prediction_engine import get_engine
from services.safety import GENERAL_DISCLAIMER

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)-8s %(name)s: %(message)s"
)
logger = logging.getLogger("clinical_ai")

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Connect the database and load the model and vector store once at startup."""
    try:
        await connect_to_database()
    except Exception:
        logger.exception("Database connection failed. Auth and history will be unavailable.")

    if not get_engine().load():
        logger.warning("Prediction model unavailable - run `python train_model.py`.")

    yield
    await close_database_connection()


app = FastAPI(
    title="Clinical-AI API",
    version="1.0.0",
    description=(
        "Explainable, multilingual clinical decision support. "
        + GENERAL_DISCLAIMER
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --------------------------------------------------------------------------- #
# Error handling - the API never returns an empty body.
# --------------------------------------------------------------------------- #
@app.exception_handler(RequestValidationError)
async def validation_handler(request: Request, exc: RequestValidationError):
    first = exc.errors()[0] if exc.errors() else {}
    field = ".".join(str(p) for p in first.get("loc", [])[1:]) or "request"
    message = first.get("msg", "The request couldn't be processed.")
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": f"{field}: {message}", "errors": exc.errors()},
    )


@app.exception_handler(Exception)
async def unhandled_handler(request: Request, exc: Exception):
    logger.exception("Unhandled error on %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Something went wrong on the server. Try again."},
    )


# --------------------------------------------------------------------------- #
# Routes
# --------------------------------------------------------------------------- #
prefix = settings.API_PREFIX
for router in (auth.router, users.router, symptoms.router, predictions.router,
               diseases.router):
    app.include_router(router, prefix=prefix)


@app.get(f"{prefix}/health", tags=["health"])
async def health():
    engine = get_engine()
    db_ok = await database_is_healthy()
    components = {
        "database": db_ok,
        "prediction_model": engine.is_ready,
    }
    return {
        "status": "ok" if db_ok and engine.is_ready else "degraded",
        "components": components,
        "model": engine.bundle.metadata if engine.is_ready else None,
        "translation_provider": settings.TRANSLATION_PROVIDER,
        "supported_languages": settings.SUPPORTED_LANGUAGES,
        "disclaimer": GENERAL_DISCLAIMER,
    }


@app.get("/", include_in_schema=False)
async def root():
    return {"name": settings.APP_NAME, "docs": "/docs", "health": f"{prefix}/health"}
