## 🧪 Origin: An AI Tools Benchmark

This project was born as a **personal benchmark to evaluate the main AI code generation tools** available in 2025–2026: **GitHub Copilot, OpenAI Codex, Google Gemini, and Cursor**.

### The methodology

- **Same prompts, different tools**: The exact prompts used are documented in [`prompts.txt`](./prompts.txt).
- **Deliberately unknown stack**: Go, Flutter, and ESP32/Arduino were chosen precisely because I had no prior experience with them — eliminating any personal bias in the evaluation.
- **Production-grade target**: The goal wasn't a tutorial or a toy project. The prompts were designed to generate a real, secure, end-to-end system.

### Key findings

| Tool | Strength | Weakness |
|------|----------|----------|
| **Codex** | Best for complex, multi-layer generation from scratch | Less context-aware on iterative changes |
| **Cursor** | Excellent for iterative development on existing code | Needs more guidance on initial architecture |
| **Copilot** | Strong for isolated code fragments | Struggles with cross-layer coherence |
| **Gemini** | Good for boilerplate and standard patterns | Less reliable on domain-specific logic |

> **Conclusion**: No single tool wins across all scenarios. The quality of the prompt and the clarity of the architecture definition matter more than the tool itself.

 
 # GortuinoAI

🤖 GortuinoAI: Intelligent IoT Monitoring & Actuation Ecosystem
GortuinoAI is an end-to-end Full-Stack IoT solution designed for critical thermal monitoring and fluid control. It seamlessly integrates the high performance of Go, the hardware versatility of Arduino/ESP32, and a high-fidelity Flutter mobile interface. The code is 100% generate from AI Agents.

The system is built with a focus on industrial safety, featuring automated valve shut-offs, dual battery telemetry, and robust JWT-based security.

🏗️ System Architecture
GortuinoAI operates through three synchronized layers:

1. 🔌 Gortuino Core (ESP32 Firmware)
The edge-computing brain. Responsible for signal digitalization and real-time actuation.

Smart Provisioning: Initial WiFi/MQTT setup via BLE (Bluetooth Low Energy)—no hardcoded credentials required.

Hexa-Variable Telemetry: Simultaneous monitoring of 4 temperature sensors (DS18B20) and a dual 12V battery bank via voltage dividers.

On-Demand Mode: Active listener on the casa/peticion topic for immediate data reporting.

Auto-Healing: Robust reconnection logic for both WiFi and MQTT brokers.

2. ⚙️ Gortuino Engine (Go Backend)
A high-concurrency microservice acting as the central nervous system.

JWT Security: Protected /api/* routes requiring Bearer Token authentication.

Safe-Start Protocol: Forces an OFF state on all relays upon service startup to prevent accidental actuation.

Concurrency Management: Utilizes Goroutines for non-blocking 30-second valve safety timers.

Data Persistence: 24-hour historical logging using SQLite and GORM.

3. 📱 Gortuino App (Flutter Mobile)
A premium tactical UI designed in Dark Mode (#121212).

Real-time Dashboard: Status cards for all 6 sensors with interactive gauges for battery health.

Trend Analysis: Multi-series line charts (fl_chart) visualizing thermal behavior over the last 24 hours.

Safety UX: Action buttons with loading states, countdown timers, and mutual exclusion logic (disables conflicting valves during operation).

Session Management: Secure token storage and automatic 401 (Unauthorized) handling.

📊 Data Schema (MQTT JSON)
The nodes communicate using the following telemetry structure:

JSON
{
  "temp_exterior": 22.5,
  "temp_interior": 24.0,
  "temp_deposito": 45.2,
  "temp_ambiente2": 23.8,
  "voltaje_bat_1": 13.2,
  "voltaje_bat_2": 12.8,
  "timestamp": "2026-03-21T13:51:38Z"
}
🛠️ Tech Stack
Languages: Go (1.21+), Dart (Flutter), C++ (Arduino/ESP32).

Frameworks: Gin Gonic, GORM, Provider (State Mgmt).

Database: SQLite.

Protocols: MQTT (Paho), HTTP/REST, BLE.

Security: JWT, Bcrypt, TLS Support.

🚀 Quick Start
Hardware: Flash the ESP32 firmware. Upon boot, use any Serial Bluetooth App to provision WiFi/MQTT settings.

Server: Run the Go backend and use the /setup endpoint for the initial admin registration.

Mobile: Build the Flutter app, enter your server IP, and take control.

GortuinoAI: Intelligence flowing between your hardware and your hand.
