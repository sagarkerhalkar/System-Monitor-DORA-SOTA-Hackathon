FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8081

WORKDIR /app
COPY hackathon/services/ai_ops/app.py /app/app.py

# The upstream Python runtime currently includes msgpack/setuptools even though
# this stdlib-only service does not use them. Remove the unused packages rather
# than carrying known HIGH-severity vulnerabilities into the runtime image.
RUN python -m pip uninstall --yes msgpack setuptools \
    && useradd --create-home --uid 10001 appuser

USER 10001:10001

EXPOSE 8081
HEALTHCHECK --interval=15s --timeout=3s --retries=3 CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8081/healthz', timeout=2).read()"

ENTRYPOINT ["python", "/app/app.py"]
