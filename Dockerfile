# Tactical Tides referee — the authoritative match server. It runs the SAME Godot rules code the
# client uses (shared-code anti-cheat: every turn is re-validated by the identical brain), headless,
# on Cloud Run. Build context is the PROJECT ROOT:
#   docker build -t tt-referee .
# Cloud Run injects $PORT (8080); server_main reads it. Set SUPABASE_SERVICE_KEY for persistence.
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.6-stable

# Fetch tools + the few libs Godot's headless binary links against.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates wget unzip \
      libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1 \
    && rm -rf /var/lib/apt/lists/*

# Install the Godot headless binary.
RUN wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" \
    && unzip -q "Godot_v${GODOT_VERSION}_linux.x86_64.zip" \
    && mv "Godot_v${GODOT_VERSION}_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm "Godot_v${GODOT_VERSION}_linux.x86_64.zip"

WORKDIR /app
COPY . /app

# Generate the import cache / class_name registry on Linux. The referee itself loads no textures or
# audio (it runs via --script, so NO autoloads init), but Godot needs .godot/ to resolve globals.
RUN godot --headless --path /app --import 2>&1 | tail -3 || true

EXPOSE 8080
CMD ["godot", "--headless", "--path", "/app", "--script", "res://scripts/server/server_main.gd"]
