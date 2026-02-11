#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────
# E2E test: verify that a .NET Core 3.1-targeted ASP.NET Core app
# produces correct spans (with hierarchy) for HTTP requests when
# instrumented with OpenTelemetry .NET Auto-Instrumentation.
#
# The test app:
#   - Starts a Kestrel server on a random port
#   - Makes HTTP GET /test  → produces: HTTP Client span → ASP.NET Server span → Manual Internal span
#   - Makes HTTP GET /health → produces: HTTP Client span → ASP.NET Server span
#
# We assert:
#   1. Spans exist for each kind (Client, Server, Internal)
#   2. HTTP request details are present (url, method, status code)
#   3. Span hierarchy is correct (shared TraceId, ParentSpanId linkage)
#   4. Manual span from custom ActivitySource is present
# ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOLUTION_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_APP_DIR="$SCRIPT_DIR/core3-spans-test"

TRACER_HOME="${OTEL_DOTNET_AUTO_HOME:-$SOLUTION_ROOT/bin/tracer-home}"

echo "=== .NET Core 3.1 Span Collection E2E Test ==="
echo "Solution root: $SOLUTION_ROOT"
echo "Tracer home:   $TRACER_HOME"
echo "Test app:      $TEST_APP_DIR"

# ── Validate tracer-home exists ──────────────────────────────────────
if [ ! -d "$TRACER_HOME" ]; then
  echo "ERROR: Tracer home directory not found at $TRACER_HOME"
  echo "Make sure the build has completed (./build.sh) before running this test."
  exit 1
fi

# ── Build the test application ───────────────────────────────────────
echo ""
echo "--- Building test application ---"
# Clean previous publish output to avoid nested out/out/out directory issue
rm -rf "$TEST_APP_DIR/out"
dotnet publish "$TEST_APP_DIR/TestApplication.Core3.csproj" \
  -c Release \
  -f netcoreapp3.1 \
  -o "$TEST_APP_DIR/out"

TEST_APP_DLL="$TEST_APP_DIR/out/TestApplication.Core3.dll"
if [ ! -f "$TEST_APP_DLL" ]; then
  echo "ERROR: Test app DLL not found at $TEST_APP_DLL"
  exit 1
fi

# ── Set up instrumentation env vars ─────────────────────────────────
# These match the Odigos production staticVariables configuration
# (with $TRACER_HOME in place of /var/odigos/dotnet and $OS_TYPE in
# place of linux-{{.LIBC_TYPE}}).
#
# Path resolution: the Odigos container image assembles its own
# directory layout which differs from what `build.sh` produces.
# We try the Odigos path first, then fall back to the build output path.
export OS_TYPE="${OS_TYPE:-linux-glibc}"

export CORECLR_ENABLE_PROFILING="1"
export CORECLR_PROFILER="{918728DD-259F-4A6A-AC2B-B85E1B658318}"
export OTEL_DOTNET_AUTO_HOME="$TRACER_HOME"

# Native profiler: Odigos layout puts it in $TRACER_HOME/linux-<libc>/,
# build.sh puts it at $TRACER_HOME/ root.
if [ -f "$TRACER_HOME/$OS_TYPE/OpenTelemetry.AutoInstrumentation.Native.so" ]; then
  export CORECLR_PROFILER_PATH="$TRACER_HOME/$OS_TYPE/OpenTelemetry.AutoInstrumentation.Native.so"
elif [ -f "$TRACER_HOME/OpenTelemetry.AutoInstrumentation.Native.so" ]; then
  export CORECLR_PROFILER_PATH="$TRACER_HOME/OpenTelemetry.AutoInstrumentation.Native.so"
else
  echo "ERROR: OpenTelemetry.AutoInstrumentation.Native.so not found in $TRACER_HOME/$OS_TYPE/ or $TRACER_HOME/"
  exit 1
fi

# Startup hook: Odigos layout uses net/, build.sh uses netcoreapp3.1/
if [ -f "$TRACER_HOME/net/OpenTelemetry.AutoInstrumentation.StartupHook.dll" ]; then
  export DOTNET_STARTUP_HOOKS="$TRACER_HOME/net/OpenTelemetry.AutoInstrumentation.StartupHook.dll"
elif [ -f "$TRACER_HOME/netcoreapp3.1/OpenTelemetry.AutoInstrumentation.StartupHook.dll" ]; then
  export DOTNET_STARTUP_HOOKS="$TRACER_HOME/netcoreapp3.1/OpenTelemetry.AutoInstrumentation.StartupHook.dll"
else
  echo "ERROR: OpenTelemetry.AutoInstrumentation.StartupHook.dll not found in $TRACER_HOME/net/ or $TRACER_HOME/netcoreapp3.1/"
  exit 1
fi

# AdditionalDeps / shared store: explicitly UNSET.
# The upstream build creates AdditionalDeps/ with a deps.json that
# references the full transitive closure (including DnsClient 1.4.0 via
# MongoDB), but the store/ directory is incomplete — ComposeStore didn't
# place the actual DLLs there. The .NET runtime sees the deps.json,
# tries to resolve DnsClient.dll from the store, and hard-crashes.
# The DOTNET_STARTUP_HOOKS mechanism alone is sufficient for our needs.
unset DOTNET_ADDITIONAL_DEPS 2>/dev/null || true
unset DOTNET_SHARED_STORE 2>/dev/null || true

# Test-specific OTel settings
export OTEL_SERVICE_NAME="e2e-core3-test"
export OTEL_TRACES_EXPORTER="none"
export OTEL_METRICS_EXPORTER="none"
export OTEL_LOGS_EXPORTER="none"
export OTEL_DOTNET_AUTO_TRACES_CONSOLE_EXPORTER_ENABLED="true"
export OTEL_DOTNET_AUTO_TRACES_ADDITIONAL_SOURCES="TestApp.Core3"

echo ""
echo "--- Instrumentation environment ---"
echo "CORECLR_ENABLE_PROFILING=$CORECLR_ENABLE_PROFILING"
echo "CORECLR_PROFILER=$CORECLR_PROFILER"
echo "CORECLR_PROFILER_PATH=$CORECLR_PROFILER_PATH"
echo "OTEL_DOTNET_AUTO_HOME=$OTEL_DOTNET_AUTO_HOME"
echo "DOTNET_STARTUP_HOOKS=$DOTNET_STARTUP_HOOKS"
echo "DOTNET_ADDITIONAL_DEPS=${DOTNET_ADDITIONAL_DEPS:-<not set>}"
echo "DOTNET_SHARED_STORE=${DOTNET_SHARED_STORE:-<not set>}"

# ── Run the test app and capture output ──────────────────────────────
echo ""
echo "--- Running instrumented test application ---"
OUTPUT_FILE="$TEST_APP_DIR/test-output.txt"

# Run the app; allow non-zero exit because the console exporter may write to stderr
set +e
dotnet "$TEST_APP_DLL" 2>&1 | tee "$OUTPUT_FILE"
APP_EXIT_CODE=${PIPESTATUS[0]}
set -e

echo ""
echo "--- App exit code: $APP_EXIT_CODE ---"
echo ""
echo "--- Full captured output ---"
cat "$OUTPUT_FILE"
echo ""

# ═════════════════════════════════════════════════════════════════════
# ASSERTION HELPERS
# ═════════════════════════════════════════════════════════════════════

PASS_COUNT=0
FAIL_COUNT=0

assert_contains() {
  local description="$1"
  local pattern="$2"
  if grep -qE "$pattern" "$OUTPUT_FILE"; then
    echo "✅ PASS: $description"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "❌ FAIL: $description"
    echo "   Pattern not found: $pattern"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_count_ge() {
  local description="$1"
  local pattern="$2"
  local min_count="$3"
  local actual_count
  actual_count=$(grep -cE "$pattern" "$OUTPUT_FILE" || true)
  if [ "$actual_count" -ge "$min_count" ]; then
    echo "✅ PASS: $description (found $actual_count, need >= $min_count)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "❌ FAIL: $description (found $actual_count, need >= $min_count)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# ═════════════════════════════════════════════════════════════════════
# 1. SPAN EXISTENCE — verify the expected span kinds appear
# ═════════════════════════════════════════════════════════════════════
echo ""
echo "--- 1. Span Existence ---"

# We made 2 HTTP calls, so expect >= 2 Client spans
assert_count_ge \
  "HTTP Client spans exist (>= 2)" \
  "Activity\.Kind.*Client" 2

# The server handled 2 requests, so expect >= 2 Server spans
assert_count_ge \
  "HTTP Server spans exist (>= 2)" \
  "Activity\.Kind.*Server" 2

# GET /test creates one Internal manual span
assert_contains \
  "Manual Internal span exists" \
  "Activity\.Kind.*Internal"

# ═════════════════════════════════════════════════════════════════════
# 2. SPAN DISPLAY NAMES — verify the correct operation names
# ═════════════════════════════════════════════════════════════════════
echo ""
echo "--- 2. Span Display Names ---"

# HTTP client spans are typically named "GET" or "HTTP GET"
assert_contains \
  "Client span DisplayName contains GET" \
  "Activity\.DisplayName.*(GET|HTTP GET)"

# ASP.NET Core server spans are named like "/test" or "GET /test"
assert_contains \
  "Server span for /test endpoint" \
  "Activity\.DisplayName.*/test"

assert_contains \
  "Server span for /health endpoint" \
  "Activity\.DisplayName.*/health"

# Our manual span
assert_contains \
  "Manual span 'ManualServerWork' exists" \
  "Activity\.DisplayName.*ManualServerWork"

# ═════════════════════════════════════════════════════════════════════
# 3. HTTP REQUEST DETAILS — verify HTTP semantic conventions
# ═════════════════════════════════════════════════════════════════════
echo ""
echo "--- 3. HTTP Request Details ---"

# HTTP method tag (varies by OTel version: http.method or http.request.method)
assert_contains \
  "HTTP method tag present" \
  "http\.(request\.)?method.*GET"

# URL or url.full tag
assert_contains \
  "HTTP URL tag present" \
  "(http\.url|url\.full|http\.target).*/(test|health)"

# HTTP status code (http.status_code or http.response.status_code)
assert_contains \
  "HTTP status code 200 present" \
  "(http\.(response\.)?status_code|StatusCode).*200"

# ═════════════════════════════════════════════════════════════════════
# 4. ACTIVITY SOURCE — custom source is recorded
# ═════════════════════════════════════════════════════════════════════
echo ""
echo "--- 4. Activity Sources ---"

assert_contains \
  "Custom ActivitySource 'TestApp.Core3' recorded" \
  "TestApp\.Core3"

# ═════════════════════════════════════════════════════════════════════
# 5. TRACE HIERARCHY — spans share TraceId, parent-child linkage
# ═════════════════════════════════════════════════════════════════════
echo ""
echo "--- 5. Trace Hierarchy ---"

# Extract all TraceIds emitted
TRACE_IDS=$(grep -oE "Activity\.TraceId:\s+[0-9a-f]+" "$OUTPUT_FILE" | awk '{print $NF}' | sort -u)
TRACE_ID_COUNT=$(echo "$TRACE_IDS" | wc -l | tr -d ' ')

echo "   Found $TRACE_ID_COUNT distinct TraceId(s): $TRACE_IDS"

# We expect at least 2 distinct traces (one per HTTP request cycle)
if [ "$TRACE_ID_COUNT" -ge 2 ]; then
  echo "✅ PASS: At least 2 distinct traces found ($TRACE_ID_COUNT)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "❌ FAIL: Expected >= 2 distinct traces, found $TRACE_ID_COUNT"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Verify ParentSpanId is present (proves parent-child linkage)
# The manual span and server spans should have a ParentSpanId
PARENT_SPAN_COUNT=$(grep -cE "Activity\.ParentSpanId:\s+[0-9a-f]+" "$OUTPUT_FILE" || true)
echo "   Found $PARENT_SPAN_COUNT span(s) with ParentSpanId"

if [ "$PARENT_SPAN_COUNT" -ge 3 ]; then
  echo "✅ PASS: At least 3 spans have a ParentSpanId (proves hierarchy)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "❌ FAIL: Expected >= 3 spans with ParentSpanId, found $PARENT_SPAN_COUNT"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Verify that spans within the same trace share the same TraceId
# Pick the first trace and count how many spans belong to it
FIRST_TRACE_ID=$(echo "$TRACE_IDS" | head -1)
SPANS_IN_FIRST_TRACE=$(grep -c "Activity\.TraceId:.*$FIRST_TRACE_ID" "$OUTPUT_FILE" || true)
echo "   First trace ($FIRST_TRACE_ID) has $SPANS_IN_FIRST_TRACE span(s)"

# The /test request should produce >= 3 spans in one trace:
#   HTTP Client → ASP.NET Server → Manual Internal
if [ "$SPANS_IN_FIRST_TRACE" -ge 3 ]; then
  echo "✅ PASS: First trace has >= 3 correlated spans (Client → Server → Internal)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  # Maybe it's the second trace that has 3 — check all
  MAX_SPANS_IN_TRACE=0
  for tid in $TRACE_IDS; do
    count=$(grep -c "Activity\.TraceId:.*$tid" "$OUTPUT_FILE" || true)
    if [ "$count" -gt "$MAX_SPANS_IN_TRACE" ]; then
      MAX_SPANS_IN_TRACE=$count
    fi
  done
  if [ "$MAX_SPANS_IN_TRACE" -ge 3 ]; then
    echo "✅ PASS: A trace has >= 3 correlated spans (Client → Server → Internal)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "❌ FAIL: No trace has >= 3 correlated spans (max was $MAX_SPANS_IN_TRACE)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
fi

# ═════════════════════════════════════════════════════════════════════
# SUMMARY
# ═════════════════════════════════════════════════════════════════════
echo ""
echo "============================================"
echo "  RESULTS: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "============================================"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo ""
  echo "Full output for debugging:"
  echo "---"
  cat "$OUTPUT_FILE"
  echo "---"
  exit 1
fi

echo ""
echo "=== All assertions passed ==="
