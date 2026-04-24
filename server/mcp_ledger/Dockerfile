FROM python:3.12-alpine

WORKDIR /app

# Build dependencies for asyncpg (compiles against libpq)
RUN apk add --no-cache gcc musl-dev postgresql-dev libffi-dev

COPY pyproject.toml .
COPY mcp_ledger/ ./mcp_ledger/

RUN pip install --no-cache-dir .

EXPOSE 8000

CMD ["mcp-ledger"]
